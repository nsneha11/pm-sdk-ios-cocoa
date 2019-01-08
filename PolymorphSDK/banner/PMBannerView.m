//
//  PMBannerView.m
//
//  Created by Arvind Bharadwaj on 07/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//
#import "PMBannerView.h"
#import <UIKit/UIKit.h>
#import "SDKConfigsSource.h"
#import "SDKConfigs.h"
#import "AdDelegate.h"
#import "AdRequest.h"

#import "PMBannerAdManager.h"
#import "InstanceProvider.h"
#import "PMBannerAdManagerDelegate.h"
#import "Logging.h"
#import "PMAdRequestTargeting.h"
#import "AdAssets.h"
#import "PMWebView.h"

#define kClickTrackerURLsKey        @"clicks"


@interface PMBannerView () <PMBannerAdManagerDelegate>

@property (nonatomic, strong) PMBannerAdManager *adManager;
@property (nonatomic, weak) UIView *adContentView;
@property (nonatomic, assign) CGSize originalSize;
@property (nonatomic, strong) PMAdRequestTargeting *targeting;
@property (nonatomic, strong) NSDictionary *bannerCustomEventData;
@property (nonatomic, assign) BOOL hasTrackedClick;

@end

@implementation PMBannerView

@synthesize adManager = _adManager;
@synthesize adUnitId = _adUnitId;
@synthesize delegate = _delegate;
@synthesize originalSize = _originalSize;
@synthesize adContentView = _adContentView;
@synthesize targeting = _targeting;

#pragma mark -
#pragma mark Lifecycle

- (id)initWithAdUnitId:(NSString *)adUnitId withSize:(CGSize)size
{
    CGRect f = (CGRect){{0, 0}, size};
    if (self = [super initWithFrame:f])
    {
        NSAssert(adUnitId !=nil,@"AdUnitID has not been set. Set it in the initWithAdUnitId: method");
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = YES;
        self.originalSize = size;
        self.adUnitId = adUnitId;
        self.adManager = [[PMBannerAdManager alloc] initWithDelegate:self adUnitId:_adUnitId];
        self.biddingInterval = kDefaultBiddingInterval;
        self.isUnRenderedPMAd = NO;
    }
    return self;
}

- (void)dealloc
{
    self.adManager.delegate = nil;
}

- (float)biddingEcpm
{
    if (self.bannerCustomEventData != nil && ![self.bannerCustomEventData objectForKey:kNativeEcpmKey]) {
        return -1.0;
    }
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setMaximumFractionDigits:2];
    [formatter setMinimumFractionDigits:2];
    
    NSString *ecpmAsString = [formatter stringFromNumber:[self.bannerCustomEventData objectForKey:kNativeEcpmKey]];
    
    NSNumber *ecpm = [formatter numberFromString:ecpmAsString];
    
    SDKConfigs *configs = [self getSDKConfigs];
    if (configs != NULL)
        self.biddingInterval = configs.biddingInterval;

    if (self.biddingInterval == 0.0) {
        return [ecpm floatValue];
    }
    
    //rounding off ecpm to the closest bidding interval
    int biddingEcpm = [ecpm floatValue]*100;
    int bidInterval = self.biddingInterval *100;
    
    int remainder = biddingEcpm % bidInterval;
    
    float div = (float)remainder/bidInterval;
    
    if (div >= 0.5) {
        biddingEcpm = biddingEcpm + (bidInterval - remainder);
    } else {
        biddingEcpm = biddingEcpm - remainder;
    }
    
    float res = (float)biddingEcpm/100.0;
    
    return res;
}


- (void)trackClick
{
    if (self.hasTrackedClick) {
        LogDebug(@"Click already tracked.");
    } else {
        NSArray *clickTrackers = [self.bannerCustomEventData objectForKey:kClickTrackerURLsKey];
        if (![clickTrackers isKindOfClass:[NSArray class]] || [clickTrackers count] < 1) {
            LogWarn(@"Could not find any click trackers. Clicks NOT being tracked.");
            return;
        } else {
            self.hasTrackedClick = YES;
            LogDebug(@"Tracking a click for %@.", self.adUnitId);
            LogDebug(@"Number of click trackers : %lu",[clickTrackers count]);
            for (NSString *URLString in clickTrackers) {
                NSURL *URL = [NSURL URLWithString:URLString];
                if (URL) {
                    LogDebug(@"Firing click url %@ for %@",[URL absoluteString],self.adUnitId);
                    [self trackMetricForURL:URL];
                }
            }
        }
    }
}

- (void)trackMetricForURL:(NSURL *)URL
{
    NSMutableURLRequest *request = [[InstanceProvider sharedProvider] buildConfiguredURLRequestWithURL:URL];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    [NSURLConnection connectionWithRequest:request delegate:nil];
}

#pragma mark -

- (void)setAdContentView:(UIView *)view
{
    [self.adContentView removeFromSuperview];
    _adContentView = view;
    [self addSubview:view];
}

- (CGSize)adContentViewSize
{
    return self.adContentView.bounds.size;
}

- (void)rotateToOrientation:(UIInterfaceOrientation)newOrientation
{
    [self.adManager rotateToOrientation:newOrientation];
}

- (void)loadAd
{
    [self loadAdWithTargeting:nil];
}

- (void)loadAdWithTargeting:(PMAdRequestTargeting *)targeting
{
    self.hasTrackedClick = NO;
    self.targeting = targeting;
    if (self.requestDelayedAd) {
        self.adManager.requestDelayedAd = YES;
    } else {
        self.adManager.requestDelayedAd = NO;
    }
    [self.adManager loadAdWithTargeting:targeting];
}

- (void)renderDelayedAd
{
    if ([self.adContentView isKindOfClass:[PMWebView class]]) {
        PMWebView *view = (PMWebView *)self.adContentView;
        if (view.isDelayedRequest) {
            [view loadDelayedRequest];
        } else {
            LogWarn(@"Calling `renderDelayedAd` on already rendered PM Banner Ad. Ignoring..");
        }
    } else {
        LogWarn(@"Calling `renderDelayedAd` for non-polymorph banner ads. Ignoring..");
    }
}

- (void)refreshAd
{
    [self loadAdWithTargeting:self.targeting];
}

- (void)forceRefreshAd
{
    self.hasTrackedClick = NO;
    if (self.requestDelayedAd) {
        self.adManager.requestDelayedAd = YES;
    } else {
        self.adManager.requestDelayedAd = NO;
    }

    [self.adManager forceRefreshAd];
}

- (void)stopAutomaticallyRefreshingContents
{
    [self.adManager stopAutomaticallyRefreshingContents];
}

- (void)startAutomaticallyRefreshingContents
{
    [self.adManager startAutomaticallyRefreshingContents];
}

#pragma mark - <PMBannerAdManagerDelegate>

- (PMBannerView *)banner
{
    return self;
}

- (id<PMBannerViewDelegate>)bannerDelegate
{
    return self.delegate;
}

- (CGSize)containerSize
{
    return self.originalSize;
}

- (UIViewController *)viewControllerForPresentingModalView
{
    return [self.delegate viewControllerToPresentAdModalView];
}

- (SDKConfigs *)getSDKConfigs
{
    return [self.delegate getSDKConfigs];
}

- (void)invalidateContentView
{
    [self setAdContentView:nil];
}

- (void)managerDidFailToLoadAdWithError:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(adViewDidFailToLoadAd:error:)]) {
        [self.delegate adViewDidFailToLoadAd:self error:error];
    }
}

- (void)managerDidLoadAd:(UIView *)ad
{
    [self setAdContentView:ad];
    if ([ad isKindOfClass:[PMWebView class]]) {
        PMWebView *view = (PMWebView *)ad;
        if (view.isDelayedRequest && view.isViewLoaded) {
            self.isUnRenderedPMAd = NO;
            if ([self.delegate respondsToSelector:@selector(adViewDidRenderAd:)]) {
                [self.delegate adViewDidRenderAd:self];
            }
            return;
        } else if (view.isDelayedRequest) {
            self.isUnRenderedPMAd = YES;
        }
    }

    if ([self.delegate respondsToSelector:@selector(adViewDidLoadAd:)]) {
        [self.delegate adViewDidLoadAd:self];
    }
}

- (void)sendCustomEventData:(NSMutableDictionary *)customEventData
{
    self.bannerCustomEventData = [[NSDictionary alloc] initWithDictionary:customEventData];
}
//- (void)userActionWillBegin
//{
//    if ([self.delegate respondsToSelector:@selector(willPresentModalViewForAd:)]) {
//        [self.delegate willPresentModalViewForAd:self];
//    }
//}
//
//- (void)userActionDidFinish
//{
//    if ([self.delegate respondsToSelector:@selector(didDismissModalViewForAd:)]) {
//        [self.delegate didDismissModalViewForAd:self];
//    }
//}

- (void)userWillLeaveApplication
{
    [self trackClick];
    if ([self.delegate respondsToSelector:@selector(willLeaveApplicationFromAd:)]) {
        [self.delegate willLeaveApplicationFromAd:self];
    }
}

- (AdRequest *)getAdRequestObject
{
    if ([self.delegate respondsToSelector:@selector(getAdRequestObject)]) {
        return [self.delegate getAdRequestObject];
    }
    return nil;
}

- (UIView *)getBannerAdResponse
{
    if ([self.delegate respondsToSelector:@selector(getBannerAdResponse)]) {
        return [self.delegate getBannerAdResponse];
    }
    return nil;
}

- (NSMutableDictionary *)getBannerCustomEventData
{
    if ([self.delegate respondsToSelector:@selector(getBannerCustomEventData)]) {
        return [self.delegate getBannerCustomEventData];
    }
    return nil;
}
@end
