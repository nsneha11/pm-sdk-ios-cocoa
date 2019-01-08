//
//  PMPrefetchAds.m
//  Sample App
//
//  Created by Arvind Bharadwaj on 31/07/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//

#import "PMPrefetchAds.h"

const int CACHE_SIZE = 1;


@interface PMPrefetchAds()

@end

@implementation PMPrefetchAds

static NSMutableArray *adCache;
static NSMutableArray *bannerAdCache;

+ (instancetype)getInstance
{
    static PMPrefetchAds *sharedProvider = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedProvider = [[[self class] alloc] init];
    });
    return sharedProvider;
}

- (instancetype)init
{
    self = [super init];
    adCache = [NSMutableArray arrayWithCapacity:CACHE_SIZE];
    bannerAdCache = [NSMutableArray arrayWithCapacity:CACHE_SIZE];
    
    return self;
}

- (PMNativeAd *)getAd {
    return [adCache lastObject];
}

- (void)setAd:(PMNativeAd *)nativeAd {
    if ([adCache count] > 0)
        [adCache replaceObjectAtIndex:0 withObject:nativeAd];
    else
        [adCache addObject:nativeAd];
}

- (void)clearCache {
    if ([adCache count] > 0)
        [adCache removeAllObjects];
    if ([bannerAdCache count] > 0)
        [bannerAdCache removeAllObjects];
}

- (void)getSize {
    [adCache count];
}

- (PMBannerView *)getBannerAd {
    return [bannerAdCache lastObject];
}

- (void)setBannerAd:(PMBannerView *)bannerAd {
    if ([bannerAdCache count] > 0)
        [bannerAdCache replaceObjectAtIndex:0 withObject:bannerAd];
    else
        [bannerAdCache addObject:bannerAd];
}

@end
