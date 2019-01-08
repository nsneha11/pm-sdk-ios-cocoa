//
//  SDKConfigsSource.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 28/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "SDKConfigsSource.h"
#import <CoreGraphics/CoreGraphics.h>
#import "SDKConfigs.h"
#import "APIEndPoints.h"
#import "Logging.h"
#import "NSJSONSerialization+Additions.h"
#import "SDKConfigResponseParser.h"
#import "PMAdPositions.h"

static NSString * const kPositioningSourceErrorDomain = @"com.adsnative.iossdk.configssource";
static const NSTimeInterval kMaximumRetryInterval = 60.0;
static const NSTimeInterval kMinimumRetryInterval = 1.0;
static const CGFloat kRetryIntervalBackoffMultiplier = 2.0;

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface SDKConfigsSource () <NSURLConnectionDataDelegate>

@property (nonatomic, assign) BOOL loading;
@property (nonatomic, copy) NSString *adUnitIdentifier;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, copy) void (^completionHandler)(SDKConfigs *configs, NSError *error);
@property (nonatomic, assign) NSTimeInterval maximumRetryInterval;
@property (nonatomic, assign) NSTimeInterval minimumRetryInterval;
@property (nonatomic, assign) NSTimeInterval retryInterval;
@property (nonatomic, assign) NSUInteger retryCount;
@property (nonatomic, strong) NSMutableDictionary *sdkConfigMap;

- (NSURL *)serverURLWithAdUnitIdentifier:(NSString *)identifier;

@end

@implementation SDKConfigsSource

+ (SDKConfigsSource *)sharedInstance
{
    static SDKConfigsSource *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SDKConfigsSource alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    if (self) {
        self.maximumRetryInterval = kMaximumRetryInterval;
        self.minimumRetryInterval = kMinimumRetryInterval;
        self.retryInterval = self.minimumRetryInterval;
        self.sdkConfigMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_connection cancel];
}

- (void)addSDKConfigs:(SDKConfigs *)sdkConfigs withAdUnitId:(NSString *)adUnitId
{
    LogDebug(@"Mapping SDK Configs for ad unit id:%@",adUnitId);
    [self.sdkConfigMap setObject:sdkConfigs forKey:adUnitId];
}

#pragma mark - Public
- (SDKConfigs *)getSDKConfigsForAdUnitId:(NSString *)adUnitId
{
    LogDebug(@"Retrieving SDK Configs for ad unit id:%@",adUnitId);
    if ([self.sdkConfigMap objectForKey:adUnitId] != nil) {
        SDKConfigs *sdkConfigs = (SDKConfigs *)[self.sdkConfigMap objectForKey:adUnitId];
        return sdkConfigs;
    }
    return nil;
}

- (void)loadConfigsWithAdUnitIdentifier:(NSString *)identifier completionHandler:(void (^)(SDKConfigs *configs, NSError *error))completionHandler
{
    NSAssert(completionHandler != nil, @"A completion handler is required to load configs.");
    
    if (![identifier length]) {
        NSError *invalidIDError = [NSError errorWithDomain:kPositioningSourceErrorDomain code:SDKConfigsSourceInvalidAdUnitIdentifier userInfo:nil];
        completionHandler(nil, invalidIDError);
        return;
    }
    
    SDKConfigs *configs = [self getSDKConfigsForAdUnitId:identifier];
    if (configs != nil) {
        LogDebug(@"Found existing configs for ad unit. Retrieving from cache.");
        completionHandler(configs, nil);
        completionHandler = nil;
        return;
    }
    
    self.adUnitIdentifier = identifier;
    self.completionHandler = completionHandler;
    self.retryCount = 0;
    self.retryInterval = self.minimumRetryInterval;
    
    LogDebug(@"Requesting sdk configs for native ad unit :%@.", identifier);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[self serverURLWithAdUnitIdentifier:identifier]];
    [self.connection cancel];
    [self.data setLength:0];
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
}

- (void)cancel
{
    // Cancel any connection currently in flight.
    [self.connection cancel];
    
    // Cancel any queued retry requests.
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark - Internal

- (NSURL *)serverURLWithAdUnitIdentifier:(NSString *)identifier
{
    NSString *URLString = [NSString stringWithFormat:@"%@?zid=%@",
                           [APIEndPoints baseURLStringWithPath:ADSNATIVE_API_PATH_NATIVE_CONFIGS fetchConfigs:YES testing:NO],
                           identifier];
    LogDebug(@"Requesting Ad Configs with URL:%@",URLString);
    
    return [NSURL URLWithString:URLString];
}

- (void)retryLoadingPositions
{
    self.retryCount++;
    
    LogInfo(@"Retrying positions (retry attempt #%lu).", (unsigned long)self.retryCount);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[self serverURLWithAdUnitIdentifier:self.adUnitIdentifier]];
    [self.connection cancel];
    [self.data setLength:0];
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
}

#pragma mark - <NSURLConnectionDataDelegate>

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([response respondsToSelector:@selector(statusCode)]) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        
        if (statusCode == 400) {
            
//            NSError *error = [NSError errorWithDomain:@"api.adsnative.com" code:statusCode userInfo:nil];
//            
//            LogInfo(@"DATAA");
//            if (self.retryInterval >= self.maximumRetryInterval) {
//                self.completionHandler(nil, error);
//                self.completionHandler = nil;
//            } else {
//                [self performSelector:@selector(retryLoadingPositions) withObject:nil afterDelay:self.retryInterval];
//                self.retryInterval = MIN(self.retryInterval * kRetryIntervalBackoffMultiplier, self.maximumRetryInterval);
//            }
            
            return;
        }
    }
    
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    /*
     * Corner case where if publisher makes multiple ad initialization requests, two simulatenous config
     * calls may happen where one has reached `connectionDidFinishLoading` (effectively making `[self.connection cancel]`
     * useless), and the other just made a fresh config call. In this case, the completionHandler for the new ad
     * request would be nil after the first request processes it, thus leading to `EXEC_BAD_ACCESS` for the second config call
     *
     * To prevent this, we have a nil check on the completionHandler instance
     */
    if (self.completionHandler == nil) {
        return;
    }
    
    if (self.retryInterval >= self.maximumRetryInterval) {
        self.completionHandler(nil, error);
        self.completionHandler = nil;
    } else {
        [self performSelector:@selector(retryLoadingPositions) withObject:nil afterDelay:self.retryInterval];
        self.retryInterval = MIN(self.retryInterval * kRetryIntervalBackoffMultiplier, self.maximumRetryInterval);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (!self.data) {
        self.data = [NSMutableData data];
    }
    
    [self.data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    /*
     * Corner case where if publisher makes multiple ad initialization requests, two simulatenous config
     * calls may happen where one has reached `connectionDidFinishLoading` (effectively making `[self.connection cancel]` 
     * useless), and the other just made a fresh config call. In this case, the completionHandler for the new ad
     * request would be nil after the first request processes it, thus leading to `EXEC_BAD_ACCESS` for the second config call
     *
     * To prevent this, we have a nil check on the completionHandler instance
     */
    if (self.completionHandler == nil) {
        return;
    }
    
    NSError *deserializationError = nil;
    SDKConfigs *configs = [[SDKConfigResponseParser deserializer] sdkConfigsForData:self.data error:&deserializationError];
    
    if (deserializationError) {
        LogDebug(@"SDKConfig deserialization failed with error: %@", deserializationError);
        NSError *underlyingError = [[deserializationError userInfo] objectForKey:NSUnderlyingErrorKey];
        
        if ([underlyingError code] == SDKConfigResponseDataIsEmpty) {
            // Empty response data means the developer hasn't assigned any configs for the ad
            // unit. No point in retrying the request.
            self.completionHandler(nil, [NSError errorWithDomain:kPositioningSourceErrorDomain code:SDKConfigsSourceEmptyResponse userInfo:nil]);
            
            self.completionHandler = nil;
        } else if (self.retryInterval >= self.maximumRetryInterval) {
            self.completionHandler(nil, deserializationError);
            self.completionHandler = nil;
        } else {
            [self performSelector:@selector(retryLoadingPositions) withObject:nil afterDelay:self.retryInterval];
            self.retryInterval = MIN(self.retryInterval * kRetryIntervalBackoffMultiplier, self.maximumRetryInterval);
        }
        return;
    }
    [self addSDKConfigs:configs withAdUnitId:self.adUnitIdentifier];
    self.completionHandler(configs, nil);
    self.completionHandler = nil;
}


@end
