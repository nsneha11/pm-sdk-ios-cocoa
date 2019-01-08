//
//  AdSourceQueue.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "AdSourceQueue.h"
#import <CoreGraphics/CoreGraphics.h>
#import "Logging.h"
#import "PMNativeAd+Internal.h"
#import "AdRequest+AdSource.h"
#import "AdErrors.h"
#import "PMAdResponse.h"
#import "Constants.h"

static NSUInteger const kCacheSizeLimit = 3;
static NSTimeInterval const kMaxBackoffTimeInterval = 300;
static CGFloat const kBaseBackoffTimeMultiplier = 1.5;

@interface AdSourceQueue ()

@property (nonatomic, strong) NSMutableArray *adQueue;
@property (nonatomic, assign) NSUInteger backoffCounter;
@property (nonatomic, copy) NSString *adUnitIdentifier;
@property (nonatomic, strong) PMAdRequestTargeting *targeting;
@property (nonatomic, assign) BOOL isAdLoading;
@property (nonatomic, weak) UIViewController *viewController;

@end

@implementation AdSourceQueue

#pragma mark - Object Lifecycle

- (instancetype)initWithAdUnitIdentifier:(NSString *)identifier andTargeting:(PMAdRequestTargeting *)targeting withViewController:(UIViewController *)viewController
{
    self = [super init];
    if (self) {
        _adUnitIdentifier = [identifier copy];
        _targeting = targeting;
        _adQueue = [[NSMutableArray alloc] init];
        _viewController = viewController;
    }
    return self;
}

#pragma mark - Public Methods

- (PMNativeAd *)dequeueAd
{
    PMNativeAd *nextAd = [self.adQueue firstObject];
    [self.adQueue removeObject:nextAd];
    [self loadAds];
    return nextAd;
}

- (PMNativeAd *)dequeueAdWithMaxAge:(NSTimeInterval)age
{
    PMNativeAd *nextAd = [self dequeueAd];
    
    while (nextAd && ![self isAdAgeValid:nextAd withMaxAge:age]) {
        nextAd = [self dequeueAd];
    }
    
    return nextAd;
}

- (void)addNativeAd:(PMNativeAd *)nativeAd
{
    [self.adQueue addObject:nativeAd];
}

- (NSUInteger)count
{
    return [self.adQueue count];
}

- (void)cancelRequests
{
    [self resetBackoff];
}

#pragma mark - Internal Logic

- (BOOL)isAdAgeValid:(PMNativeAd *)ad withMaxAge:(NSTimeInterval)maxAge
{
    NSTimeInterval adAge = [ad.creationDate timeIntervalSinceNow];
    
    return fabs(adAge) < maxAge;
}

#pragma mark - Ad Requests

- (void)resetBackoff
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    self.backoffCounter = 0;
}

- (void)loadAds
{
    if (self.backoffCounter == 0) {
        [self replenishCache];
    }
}

- (void)replenishCache
{
    if ([self count] >= kCacheSizeLimit || self.isAdLoading) {
        return;
    }
    
    self.isAdLoading = YES;
    AdRequest *adRequest = [AdRequest requestWithAdUnitIdentifier:self.adUnitIdentifier requestType:PM_REQUEST_TYPE_NATIVE];
    adRequest.viewController = self.viewController;
    adRequest.targeting = self.targeting;
    
    [adRequest startForAdSequence:self.currentSequence withCompletionHandler:^(AdRequest *request, PMAdResponse *response, NSError *error) {
        
        if ([response.adtype isEqualToString:@"native"] && !error) {
            self.backoffCounter = 0;
            
            [self addNativeAd:[response getPMNativeAdResponse]];
            self.currentSequence++;
            if ([self count] == 1) {
                [self.delegate adSourceQueueAdIsAvailable:self];
            }
        } else {
            if (![response.adtype isEqualToString:@"native"]) {
                LogWarn(@"AdUnit may have been misconfigured. Received non-native ad for a native ad request");
            }
            LogDebug(@"%@", error);
            //increment in this failure case to prevent retrying a request that wasn't bid on.
            //currently under discussion on whether we do this or not.
            if (error.code == AdErrorNoInventory) {
                self.currentSequence++;
            }
            
            NSTimeInterval backoffTime = [self backoffTime];
            self.backoffCounter++;
            if (backoffTime < kMaxBackoffTimeInterval) {
                [self performSelector:@selector(replenishCache) withObject:nil afterDelay:backoffTime];
                LogDebug(@"Scheduled the backoff to try again in %.1f seconds.", backoffTime);
            } else {
                LogDebug(@"Backoff has timed out", backoffTime);
                self.backoffCounter = 0;
            }
        }
        self.isAdLoading = NO;
        [self loadAds];
    }];
}

- (NSTimeInterval)backoffTime
{
    NSTimeInterval timeInterval = 0;
    if (self.backoffCounter > 0) {
        timeInterval = powf(kBaseBackoffTimeMultiplier, self.backoffCounter - 1);
    }
    return timeInterval;
}

@end
