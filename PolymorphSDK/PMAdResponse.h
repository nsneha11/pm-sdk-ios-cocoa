//
//  PMAdResponse.h
//
//  Created by Arvind Bharadwaj on 15/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class PMNativeAd;

@interface PMAdResponse : NSObject

@property (nonatomic, strong) NSString *adtype;

- (instancetype)initWithAdType:(NSString *)adtype;
- (PMNativeAd *)getPMNativeAdResponse;
- (void)setPMNativeAdResponse:(PMNativeAd *)nativeAd;

- (void)setPMBannerAdResponse:(UIView *)bannerAd;
- (UIView *)getPMBannerAdResponse;

- (void)setCustomEventData:(NSMutableDictionary *)customEventData;
- (NSMutableDictionary *)getCustomEventData;

@end
