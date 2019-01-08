//
//  PMBannerAdManagerDelegate.h
//
//  Created by Arvind Bharadwaj on 08/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PMBannerView;
@class AdRequest;
@class SDKConfigs;
@protocol PMBannerViewDelegate;

@protocol PMBannerAdManagerDelegate <NSObject>

- (NSString *)adUnitId;
- (PMBannerView *)banner;
- (id<PMBannerViewDelegate>)bannerDelegate;
- (CGSize)containerSize;
@optional
- (UIViewController *)viewControllerForPresentingModalView;

- (void)invalidateContentView;

- (void)managerDidLoadAd:(UIView *)ad;
- (void)managerDidFailToLoadAdWithError:(NSError *)error;
//- (void)userActionWillBegin;
//- (void)userActionDidFinish;
- (void)userWillLeaveApplication;

- (SDKConfigs *)getSDKConfigs;
/* Needed for PM_REQUEST_TYPE_ALL in PMClass */
- (AdRequest *)getAdRequestObject;
- (UIView *)getBannerAdResponse;
- (NSMutableDictionary *)getBannerCustomEventData;

- (void) sendCustomEventData:(NSMutableDictionary *)customEventData;
@end
