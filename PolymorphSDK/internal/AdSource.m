//
//  AdSource.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "AdSource.h"
#import "AdSourceQueue.h"
#import "PMNativeAd.h"

static NSTimeInterval const kCacheTimeoutInterval = 2700; //45 minutes

@interface AdSource () <AdSourceQueueDelegate>

@property (nonatomic, strong) NSMutableDictionary *adQueueDictionary;

@end

@implementation AdSource

#pragma mark - Object Lifecycle

+ (instancetype)source
{
    return [[AdSource alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _adQueueDictionary = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (void)dealloc
{
    for (NSString *queueKey in [_adQueueDictionary allKeys]) {
        [self deleteCacheForAdUnitIdentifier:queueKey];
    }
}

#pragma mark - Ad Source Interface

- (void)loadAdsWithAdUnitIdentifier:(NSString *)identifier andTargeting:(PMAdRequestTargeting *)targeting withViewController:(UIViewController *)viewController
{
    [self deleteCacheForAdUnitIdentifier:identifier];
    
    AdSourceQueue *adQueue = [[AdSourceQueue alloc] initWithAdUnitIdentifier:identifier andTargeting:targeting withViewController:viewController];
    adQueue.delegate = self;
    [self.adQueueDictionary setObject:adQueue forKey:identifier];
    
    [adQueue loadAds];
}

- (id)dequeueAdForAdUnitIdentifier:(NSString *)identifier
{
    AdSourceQueue *adQueue = [self.adQueueDictionary objectForKey:identifier];
    PMNativeAd *nextAd = [adQueue dequeueAdWithMaxAge:kCacheTimeoutInterval];
    return nextAd;
}

- (void)deleteCacheForAdUnitIdentifier:(NSString *)identifier
{
    AdSourceQueue *sourceQueue = [self.adQueueDictionary objectForKey:identifier];
    sourceQueue.delegate = nil;
    [sourceQueue cancelRequests];
    
    [self.adQueueDictionary removeObjectForKey:identifier];
}

#pragma mark - AdSourceQueueDelegate

- (void)adSourceQueueAdIsAvailable:(AdSourceQueue *)source
{
    [self.delegate adSourceDidFinishRequest:self];
}


@end
