//
//  PMAdResponse.m
//
//  Created by Arvind Bharadwaj on 15/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//

#import "PMAdResponse.h"
#import "PMNativeAd.h"

@interface PMAdResponse()

@property (nonatomic, strong) PMNativeAd *nativeAd;
@property (nonatomic, strong) UIView *bannerView;
@property (nonatomic, strong) NSMutableDictionary *bannerCustomEventData;

@end


@implementation PMAdResponse

- (instancetype)initWithAdType:(NSString *)adtype
{
    self = [super init];
    if (self) {
        _adtype = adtype;
    }
    
    return self;
}

- (void)setPMNativeAdResponse:(PMNativeAd *)nativeAd
{
    self.nativeAd = nativeAd;
}

- (PMNativeAd *)getPMNativeAdResponse
{
    return self.nativeAd;
}

- (void)setPMBannerAdResponse:(UIView *)bannerAd
{
    self.bannerView = bannerAd;
}

- (UIView *)getPMBannerAdResponse
{
    return self.bannerView;
}

- (void)setCustomEventData:(NSMutableDictionary *)customEventData
{
    self.bannerCustomEventData = [[NSMutableDictionary alloc] initWithDictionary:customEventData];
}

- (NSMutableDictionary *)getCustomEventData
{
    return self.bannerCustomEventData;
}

@end
