//
//  PMClass.m
//
//  Created by Arvind Bharadwaj on 15/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PMClass.h"
#import "SDKConfigsSource.h"
#import "SDKConfigs.h"
#import "AdRequest.h"
#import "PMNativeAdDelegate.h"
#import "PMAdResponse.h"
#import "PMNativeAd.h"
#import "PMBannerView.h"
#import "AdDelegate.h"
#import "Logging.h"
#import "PMCommonAdDelegate.h"

@interface PMClass() <PMNativeAdDelegate, PMBannerViewDelegate, AdDelegate, PMCommonAdDelegate>

@property (nonatomic, strong) SDKConfigs *sdkConfigs;
@property CGSize bannerSize;
@property int requestType;

@property (nonatomic, strong) UIViewController *viewController;
@property (nonatomic, strong) PMNativeAd *nativeAd;
@property (nonatomic, strong) PMBannerView *bannerAd;
@property (nonatomic, strong) AdRequest *anyAdRequest;
@property (nonatomic, strong) UIView *anyAdBannerResponse;
@property (nonatomic, strong) NSMutableDictionary *bannerCustomEventData;

- (void)initPMBannerAd;
- (void)initPMNativeAd;
- (void)loadPMNativeAdWithTargeting:(PMAdRequestTargeting *)targeting;
- (void)loadPMBannerAdWithTargeting:(PMAdRequestTargeting *)targeting;
@end

@implementation PMClass

- (instancetype)initWithAdUnitID:(NSString *)adUnitId requestType:(PM_REQUEST_TYPE)requestType withBannerSize:(CGSize)size
{
    self = [super init];
    if (self) {
        NSAssert(adUnitId !=nil, @"AdUnitId cannot be nil");
        _adUnitID = adUnitId;
        _bannerSize = size;
        _requestType = requestType;
        
        SDKConfigsSource *configSource = [SDKConfigsSource sharedInstance];
        __typeof__(self) __weak weakSelf = self;
        [configSource loadConfigsWithAdUnitIdentifier:adUnitId completionHandler:^(SDKConfigs *configs, NSError *error) {
            __typeof__(self) strongSelf = weakSelf;
            
            if (!strongSelf) {
                return;
            }
            
            if (error) {
                if ([error code] == SDKConfigsSourceEmptyResponse) {
                }
            } else {
                strongSelf.sdkConfigs = configs;
            }
            
        }];
        
        switch (requestType) {
            case PM_REQUEST_TYPE_NATIVE:
                [self initPMNativeAd];
                break;
            case PM_REQUEST_TYPE_BANNER:
                [self initPMBannerAd];
                break;
            case PM_REQUEST_TYPE_ALL:
                [self initPMAnyAd];
                break;
            default:
                LogError(@"Ad Request Type not supported.");
        }
    }
    return self;
}

- (instancetype)initWithAdUnitID:(NSString *)adUnitId
{
    self = [super init];
    if (self) {
        NSAssert(adUnitId !=nil, @"AdUnitId cannot be nil");
        _adUnitID = adUnitId;
        _requestType = PM_REQUEST_TYPE_NATIVE;
        
        SDKConfigsSource *configSource = [SDKConfigsSource sharedInstance];
        __typeof__(self) __weak weakSelf = self;
        [configSource loadConfigsWithAdUnitIdentifier:adUnitId completionHandler:^(SDKConfigs *configs, NSError *error) {
            __typeof__(self) strongSelf = weakSelf;
            
            if (!strongSelf) {
                return;
            }
            
            if (error) {
                if ([error code] == SDKConfigsSourceEmptyResponse) {
                }
            } else {
                strongSelf.sdkConfigs = configs;
            }
            
        }];
        
        switch (_requestType) {
            case PM_REQUEST_TYPE_NATIVE:
                [self initPMNativeAd];
                break;
            case PM_REQUEST_TYPE_BANNER:
                [self initPMBannerAd];
                break;
            case PM_REQUEST_TYPE_ALL:
                [self initPMAnyAd];
                break;
            default:
                LogError(@"Ad Request Type not supported.");
        }
    }
    return self;
}

- (void)loadPMAd
{
    [self loadPMAdWithTargeting:nil];
}

- (void)loadPMAdWithTargeting:(PMAdRequestTargeting *)targeting
{
    switch (self.requestType) {
        case PM_REQUEST_TYPE_NATIVE:
            [self loadPMNativeAdWithTargeting:targeting];
            break;
        case PM_REQUEST_TYPE_BANNER:
            [self loadPMBannerAdWithTargeting:targeting];
            break;
        case PM_REQUEST_TYPE_ALL:
            [self loadPMAnyAdWithTargeting:targeting];
            break;
        default:
            LogWarn(@"Called load on an invalid request type");
            break;
    }
}

# pragma mark - Banner Methods
- (void)initPMBannerAd
{
    self.bannerAd = [[PMBannerView alloc] initWithAdUnitId:self.adUnitID withSize:self.bannerSize];
    self.bannerAd.delegate = self;
    
}

- (void)loadPMBannerAdWithTargeting:(PMAdRequestTargeting *)targeting
{
    NSAssert(_adUnitID !=nil,@"AdUnitID has not been set. Set it in the initWithAdUnitId: method");
    if (self.requestDelayedAd) {
        self.bannerAd.requestDelayedAd = YES;
    } else {
        self.bannerAd.requestDelayedAd = NO;
    }
    [self.bannerAd loadAdWithTargeting:targeting];
}

- (void)startAutomaticallyRefreshingContents
{
    if (self.requestType != PM_REQUEST_TYPE_BANNER) {
        LogWarn(@"'startAutomaticallyRefrshingContents' valid only for PM_REQUEST_TYPE_BANNER");
        return;
    }
    [self.bannerAd startAutomaticallyRefreshingContents];
}

- (void)stopAutomaticallyRefreshingContents
{
    if (self.requestType != PM_REQUEST_TYPE_BANNER) {
        LogWarn(@"'stopAutomaticallyRefrshingContents' valid only for PM_REQUEST_TYPE_BANNER");
        return;
    }
    [self.bannerAd stopAutomaticallyRefreshingContents];
}

- (void)forceRefreshAd
{
    if (self.requestType != PM_REQUEST_TYPE_BANNER) {
        LogWarn(@"'forceRefreshAd' valid only for PM_REQUEST_TYPE_BANNER");
        return;
    }
    if (self.requestDelayedAd) {
        self.bannerAd.requestDelayedAd = YES;
    } else {
        self.bannerAd.requestDelayedAd = NO;
    }
    [self.bannerAd forceRefreshAd];
}

#pragma mark - Native Methods
- (void)initPMNativeAd
{
    self.nativeAd = [[PMNativeAd alloc] initWithAdUnitId:self.adUnitID];
    self.nativeAd.delegate = self;
    self.nativeAd.internalDelegate = self;
}

- (void)loadPMNativeAdWithTargeting:(PMAdRequestTargeting *)targeting
{
    NSAssert(_adUnitID !=nil,@"AdUnitID has not been set. Set it in the initWithAdUnitId: method");
    
    [self.nativeAd loadAdWithTargeting:targeting requestType:PM_REQUEST_TYPE_NATIVE];
}

#pragma mark - ANY Ad Methods
- (void)initPMAnyAd
{
    [self initPMBannerAd];
    [self initPMNativeAd];
}

- (void)loadPMAnyAdWithTargeting:(PMAdRequestTargeting *)targeting
{
    NSAssert(_adUnitID !=nil,@"AdUnitID has not been set. Set it in the initWithAdUnitId: method");
    
    AdRequest *request = [AdRequest requestWithAdUnitIdentifier:_adUnitID requestType:PM_REQUEST_TYPE_ALL];
    request.targeting = targeting;
    request.viewController = [self.delegate pmViewControllerForPresentingModalView];
    request.delegate = self;
    request.nativeAd = self.nativeAd;
    
    if (self.requestDelayedAd) {
        request.requestDelayedAd = YES;
    } else {
        request.requestDelayedAd = NO;
    }

    __typeof__(self) __weak weakSelf = self;
    
    [request startWithCompletionHandler:^(AdRequest *request, PMAdResponse *response, NSError *error) {
        __typeof__(self) strongSelf = weakSelf;
        
        if (!strongSelf) {
            return;
        }
        
        PMNativeAd *nativeAd = [response getPMNativeAdResponse];

        if (error) {
            if ([response.adtype isEqualToString:@"banner"]) {
                [self.delegate pmBannerAdDidFailToLoad:nil withError:error];
            } else {
                [self.delegate pmNativeAd:nativeAd didFailWithError:error];
            }
        } else {
            if ([response.adtype isEqualToString:@"banner"]) {
                strongSelf.anyAdRequest = request;
                strongSelf.anyAdBannerResponse = [response getPMBannerAdResponse];
                strongSelf.bannerCustomEventData = [response getCustomEventData];
                //picks up request and response from above set properties
                [strongSelf loadPMBannerAdWithTargeting:request.targeting];
            } else {
                [self.delegate pmNativeAdDidLoad:nativeAd];
            }
        }
    }];
}
#pragma mark - <PMNativeAdDelegate>
- (void)anNativeAdDidLoad:(PMNativeAd *)nativeAd
{
    if ([self.delegate respondsToSelector:@selector(pmNativeAdDidLoad:)]) {
        [self.delegate pmNativeAdDidLoad:nativeAd];
    }
}

- (void)anNativeAd:(PMNativeAd *)nativeAd didFailWithError:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(pmNativeAd:didFailWithError:)]) {
        [self.delegate pmNativeAd:nativeAd didFailWithError:error];
    }
}

- (void)anNativeAdDidRecordImpression
{
    if ([self.delegate respondsToSelector:@selector(pmNativeAdDidRecordImpression)]) {
        [self.delegate pmNativeAdDidRecordImpression];
    }
}

- (BOOL)anNativeAdDidClick:(PMNativeAd *)nativeAd
{
    if ([self.delegate respondsToSelector:@selector(pmNativeAdDidClick:)]) {
        return [self.delegate pmNativeAdDidClick:nativeAd];
    }
    
    return NO;
}

- (void)anNativeAdWillLeaveApplication
{
    if ([self.delegate respondsToSelector:@selector(pmNativeAdWillLeaveApplication)]) {
        [self.delegate pmNativeAdWillLeaveApplication];
    }
}

#pragma mark - <PMBannerViewDelegate>
- (void)adViewDidLoadAd:(PMBannerView *)view
{
    if ([self.delegate respondsToSelector:@selector(pmBannerAdDidLoad:)]) {
        [self.delegate pmBannerAdDidLoad:view];
    }
}

- (void)adViewDidFailToLoadAd:(PMBannerView *)view error:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(pmBannerAdDidFailToLoad:withError:)]) {
        [self.delegate pmBannerAdDidFailToLoad:view withError:error];
    }
}

- (void)willLeaveApplicationFromAd:(PMBannerView *)view
{
    if ([self.delegate respondsToSelector:@selector(pmWillLeaveApplicationFromBannerAd:)]) {
        [self.delegate pmWillLeaveApplicationFromBannerAd:view];
    }
}

- (void)adViewDidRenderAd:(PMBannerView *)view
{
    if ([self.delegate respondsToSelector:@selector(pmBannerAdDidRender:)]) {
        [self.delegate pmBannerAdDidRender:view];
    }
}

- (AdRequest *)getAdRequestObject
{
    return self.anyAdRequest;
}

- (UIView *)getBannerAdResponse
{
    return self.anyAdBannerResponse;
}

- (NSMutableDictionary *)getBannerCustomEventData
{
    return self.bannerCustomEventData;
}

#pragma mark - <AdDelegate>
- (SDKConfigs *)getSDKConfigs
{
    return self.sdkConfigs;
}

- (UIViewController *)viewControllerToPresentAdModalView
{
    return [self.delegate pmViewControllerForPresentingModalView];
}

#pragma mark - <PMCommonAdDelegate>
- (CGSize)containerSize
{
    return self.bannerSize;
}
@end
