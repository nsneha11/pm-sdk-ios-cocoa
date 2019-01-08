//
//  AdServerPinger.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "AdServerPinger.h"
#import "InstanceProvider.h"
#import "AdConfigs.h"
#import "AdConfigsResponseParser.h"

const NSTimeInterval kRequestTimeoutTimeInterval = 10.0;
////////////////////////////////////////////////////////////////////////////////////////////////////

@interface AdServerPinger ()

@property (nonatomic, assign, readwrite) BOOL loading;
@property (nonatomic, copy) NSURL *URL;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, strong) NSDictionary *responseHeaders;

- (NSError *)errorForStatusCode:(NSInteger)statusCode;
- (NSURLRequest *)adRequestForURL:(NSURL *)URL;

@end

@implementation AdServerPinger : NSObject 

@synthesize delegate = _delegate;
@synthesize URL = _URL;
@synthesize connection = _connection;
@synthesize responseData = _responseData;
@synthesize responseHeaders = _responseHeaders;
@synthesize loading = _loading;

- (id)initWithDelegate:(id<AdServerPingerDelegate>)delegate
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
    }
    return self;
}

- (void)dealloc
{
    [self.connection cancel];
    
}

#pragma mark - Public

- (void)loadURL:(NSURL *)URL
{
    [self cancel];
    self.URL = URL;
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:[self adRequestForURL:URL] delegate:self  startImmediately:NO];
    [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [connection start];
    
    self.loading = YES;
}

- (void)cancel
{
    self.loading = NO;
    [self.connection cancel];
    self.connection = nil;
    self.responseData = nil;
    self.responseHeaders = nil;
}

#pragma mark - NSURLConnection delegate (NSURLConnectionDataDelegate in iOS 5.0+)

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([response respondsToSelector:@selector(statusCode)]) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        
        if (statusCode >= 400) {
            [connection cancel];
            self.loading = NO;
            [self.delegate pingerDidFailWithError:[self errorForStatusCode:statusCode]];
            return;
        }
    }
    
    self.responseData = [NSMutableData data];
    self.responseHeaders = [(NSHTTPURLResponse *)response allHeaderFields];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.loading = NO;
    [self.delegate pingerDidFailWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    AdConfigsResponseParser *parser = [[AdConfigsResponseParser alloc] init];
    
    self.loading = NO;
    
    NSError *error = nil;
    NSMutableOrderedSet *adConfigs = [parser adConfigsSetForData:self.responseData error:&error];
    
    if(error != nil && [adConfigs count] == 0) {
        [self.delegate pingerDidFailWithError:error];
        return;
    }
    
    //Added networks object for mediation request
    [self.delegate pingerDidReceiveAdConfiguration:adConfigs  withNetworksList:parser.networksObject];
}



#pragma mark - Internal

- (NSError *)errorForStatusCode:(NSInteger)statusCode
{
    NSString *errorMessage = [NSString stringWithFormat:
                              NSLocalizedString(@"AdsNative returned status code %d.",
                                                @"Status code error"),
                              statusCode];
    
    //if 400, then potentially it is because of an incorrect ad id
    if (statusCode == 400) {
        errorMessage = [NSString stringWithFormat:
                        NSLocalizedString(@"AdsNative returned status code %d. Please re-check the AdUnitId being set.",
                                          @"Status code error"),
                        statusCode];
    }
    
    NSDictionary *errorInfo = [NSDictionary dictionaryWithObject:errorMessage
                                                          forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"api.adsnative.com" code:statusCode userInfo:errorInfo];
}

- (NSURLRequest *)adRequestForURL:(NSURL *)URL
{
    NSMutableURLRequest *request = [[InstanceProvider sharedProvider] buildConfiguredURLRequestWithURL:URL];

    NSDictionary *retrievedDictionary = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"POST_DICT"];
    NSError *error;
    NSData *postdata = [NSJSONSerialization dataWithJSONObject:retrievedDictionary options:0 error:&error];
    NSLog(@"request body %@", retrievedDictionary);
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody: postdata];
    [request setHTTPMethod:@"POST"];

    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setTimeoutInterval:kRequestTimeoutTimeInterval];
    return request;
}

@end

