//
//  URLResolver.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 06/10/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "URLResolver.h"
#import "InstanceProvider.h"
#import "Logging.h"

@interface URLResolver ()

@property (nonatomic, strong) NSURL *originalURL;
@property (nonatomic, strong) NSURL *currentURL;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, assign) NSStringEncoding responseEncoding;
@property (nonatomic, copy) URLResolverCompletionBlock completion;

- (URLActionInfo *)actionInfoFromURL:(NSURL *)URL error:(NSError **)error;
- (NSString *)storeItemIdentifierForURL:(NSURL *)URL;
//- (BOOL)URLShouldOpenInApplication:(NSURL *)URL;
//- (BOOL)URLIsHTTPOrHTTPS:(NSURL *)URL;
//- (BOOL)URLPointsToAMap:(NSURL *)URL;
- (NSStringEncoding)stringEncodingFromContentType:(NSString *)contentType;

@end


@implementation URLResolver

+ (instancetype)resolverWithURL:(NSURL *)URL completion:(URLResolverCompletionBlock)completion
{
    return [[URLResolver alloc] initWithURL:URL completion:completion];
}

- (instancetype)initWithURL:(NSURL *)URL completion:(URLResolverCompletionBlock)completion
{
    self = [super init];
    if (self) {
        _originalURL = [URL copy];
        _completion = [completion copy];
    }
    return self;
}

- (void)start
{
    [self.connection cancel];
    self.currentURL = self.originalURL;
    
    NSError *error = nil;
    URLActionInfo *info = [self actionInfoFromURL:self.originalURL error:&error];
    
    if (info) {
        [self safeInvokeAndNilCompletionBlock:info error:nil];
    } else if (error) {
        [self safeInvokeAndNilCompletionBlock:nil error:error];
    } else {
        NSURLRequest *request = [[InstanceProvider sharedProvider] buildConfiguredURLRequestWithURL:self.originalURL];
        self.responseData = [NSMutableData data];
        self.responseEncoding = NSUTF8StringEncoding;
        self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
    }
}

- (void)cancel
{
    [self.connection cancel];
    self.connection = nil;
    self.completion = nil;
}

- (void)safeInvokeAndNilCompletionBlock:(URLActionInfo *)info error:(NSError *)error
{
    if (self.completion != nil) {
        self.completion(info, error);
        self.completion = nil;
    }
}

#pragma mark - Handling Application/StoreKit URLs

/*
 * Parses the provided URL for actions to perform (opening StoreKit, opening Safari, etc.).
 * If the URL represents an action, this method will return an info object containing data that is
 * relevant to the suggested action.
 */
- (URLActionInfo *)actionInfoFromURL:(NSURL *)URL error:(NSError **)error;
{
    URLActionInfo *actionInfo = nil;
    
    if ([self storeItemIdentifierForURL:URL]) {
        
        actionInfo = [URLActionInfo infoWithURL:self.originalURL iTunesItemIdentifier:[self storeItemIdentifierForURL:URL] iTunesStoreFallbackURL:URL];
        
    } else if ([self safariURLForURL:URL]) {
        actionInfo = [URLActionInfo infoWithURL:self.originalURL safariDestinationURL:[NSURL URLWithString:[self safariURLForURL:URL]]];
    }
    
    return actionInfo;
}

#pragma mark Extracting StoreItem Identifiers

- (NSString *)storeItemIdentifierForURL:(NSURL *)URL
{
    NSString *itemIdentifier = nil;
    if ([URL.host hasSuffix:@"itunes.apple.com"]) {
        NSString *lastPathComponent = [[URL path] lastPathComponent];
        if ([lastPathComponent hasPrefix:@"id"]) {
            itemIdentifier = [lastPathComponent substringFromIndex:2];
        } else {
            itemIdentifier = [[self urlAsDictionary:URL] objectForKey:@"id"];
        }
    } else if ([URL.host hasSuffix:@"phobos.apple.com"]) {
        itemIdentifier = [[self urlAsDictionary:URL] objectForKey:@"id"];
    }
    
    NSCharacterSet *nonIntegers = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if (itemIdentifier && itemIdentifier.length > 0 && [itemIdentifier rangeOfCharacterFromSet:nonIntegers].location == NSNotFound) {
        return itemIdentifier;
    }
    
    return nil;
}

#pragma mark - URL parser
/* returns a dictionary of all query params of a given url */
- (NSDictionary *)urlAsDictionary:(NSURL *) url
{
    NSString *query = [url absoluteString];;
    NSMutableDictionary *queryDict = [NSMutableDictionary dictionary];
    NSArray *queryElements = [query componentsSeparatedByString:@"&"];
    for (NSString *element in queryElements) {
        NSArray *keyVal = [element componentsSeparatedByString:@"="];
        if (keyVal.count >= 2) {
            NSString *key = [keyVal objectAtIndex:0];
            NSString *value = [keyVal objectAtIndex:1];
            [queryDict setObject:[value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                          forKey:key];
        }
    }
    return queryDict;
}

#pragma mark - Identifying URLs to open in Safari

- (NSString *)safariURLForURL:(NSURL *)URL
{
    //for now, all urls that aren't the app store are going to be opened in safari
    
    return [URL absoluteString];
}

#pragma mark - Identifying NSStringEncoding from NSURLResponse Content-Type header

- (NSStringEncoding)stringEncodingFromContentType:(NSString *)contentType
{
    NSStringEncoding encoding = NSUTF8StringEncoding;
    
    if (![contentType length]) {
        LogWarn(@"Attempting to set string encoding from nil %@", @"Content-Type");
        return encoding;
    }
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?<=charset=)[^;]*" options:kNilOptions error:nil];
    
    NSTextCheckingResult *charsetResult = [regex firstMatchInString:contentType options:kNilOptions range:NSMakeRange(0, [contentType length])];
    if (charsetResult && charsetResult.range.location != NSNotFound) {
        NSString *charset = [contentType substringWithRange:[charsetResult range]];
        
        // ensure that charset is not deallocated early
        CFStringRef cfCharset = CFBridgingRetain(charset);
        CFStringEncoding cfEncoding = CFStringConvertIANACharSetNameToEncoding(cfCharset);
        CFBridgingRelease(cfCharset);
        
        if (cfEncoding == kCFStringEncodingInvalidId) {
            return encoding;
        }
        encoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
    }
    
    return encoding;
}

#pragma mark - <NSURLConnectionDataDelegate>

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.responseData appendData:data];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    // First, check to see if the redirect URL matches any of our suggested actions.
    NSError *error = nil;
    URLActionInfo *info = [self actionInfoFromURL:request.URL error:&error];
    
    if (info) {
        [connection cancel];
        [self safeInvokeAndNilCompletionBlock:info error:nil];
        return nil;
    } else {
        // The redirected URL didn't match any actions, so we should continue with loading the URL.
        self.currentURL = request.URL;
        return request;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    
    NSDictionary *headers = [httpResponse allHeaderFields];
    NSString *contentType = [headers objectForKey:@"Content-Type"];
    self.responseEncoding = [self stringEncodingFromContentType:contentType];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSString *responseString = [[NSString alloc] initWithData:self.responseData encoding:self.responseEncoding];
    URLActionInfo *info = [URLActionInfo infoWithURL:self.originalURL HTTPResponseString:responseString webViewBaseURL:self.currentURL];
    [self safeInvokeAndNilCompletionBlock:info error:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self safeInvokeAndNilCompletionBlock:nil error:error];
}

@end
