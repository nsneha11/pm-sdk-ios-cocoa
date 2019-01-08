//
//  PMBannerAdManager.h
//
//  Created by Arvind Bharadwaj on 08/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class PMAdRequestTargeting;
@class SDKConfigs;

@protocol PMBannerAdManagerDelegate;

@interface PMBannerAdManager : NSObject 

@property (nonatomic, weak) id<PMBannerAdManagerDelegate> delegate;

- (id)initWithDelegate:(id<PMBannerAdManagerDelegate>)delegate adUnitId:(NSString *)adUnitId;

- (void)loadAd;
- (void)loadAdWithTargeting:(PMAdRequestTargeting *)targeting;
- (void)forceRefreshAd;
- (void)stopAutomaticallyRefreshingContents;
- (void)startAutomaticallyRefreshingContents;
- (void)rotateToOrientation:(UIInterfaceOrientation)orientation;

/**
 * This is set when you want PM banner ads to not be rendered into webview immediately. This is
 * done in case you don't want impressions to be tracked immediately upon successful ad response.
 * If this is set, PMBannerViews' `renderDelayedAd` needs to be called to render the ad into view.
 */
@property (nonatomic, assign) BOOL requestDelayedAd;

@end
