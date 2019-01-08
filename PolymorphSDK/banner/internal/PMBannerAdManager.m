//
//  PMBannerAdManager.m
//
//  Created by Arvind Bharadwaj on 08/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//

#import "PMBannerAdManager.h"
#import "PMBannerAdManagerDelegate.h"
#import "AdConfigs.h"
#import "IANTimer.h"
#import "Logging.h"
#import "PMAdRequestTargeting.h"
#import "AdRequest.h"
#import "PMAdResponse.h"
#import "InstanceProvider.h"
#import "Constants.h"
#import "PMCommonAdDelegate.h"
#import "SDKConfigs.h"
#import "Constants.h"

@interface PMBannerAdManager() <PMCommonAdDelegate>

@property (nonatomic, strong) UIView *requestingAdapterAdContentView;
@property (nonatomic, strong) AdConfigs *requestingConfiguration;
@property (nonatomic, strong) IANTimer *refreshTimer;
@property (nonatomic, strong) NSString *adUnitId;
@property (nonatomic, strong) PMAdRequestTargeting *targeting;
@property (nonatomic, strong) AdRequest *request;
@property (nonatomic, assign) BOOL adActionInProgress;
@property (nonatomic, assign) BOOL automaticallyRefreshesContents;
@property (nonatomic, assign) BOOL hasRequestedAtLeastOneAd;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) UIInterfaceOrientation currentOrientation;

- (void)applicationWillEnterForeground;
- (void)scheduleRefreshTimer;
- (void)refreshTimerDidFire;

@end

@implementation PMBannerAdManager

@synthesize delegate = _delegate;
@synthesize refreshTimer = _refreshTimer;
@synthesize adActionInProgress = _adActionInProgress;
@synthesize currentOrientation = _currentOrientation;
@synthesize targeting = _targeting;
@synthesize adUnitId = _adUnitId;
@synthesize request = _request;

- (id)initWithDelegate:(id<PMBannerAdManagerDelegate>)delegate adUnitId:(NSString *)adUnitId
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        self.adUnitId = adUnitId;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:[UIApplication sharedApplication]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:[UIApplication sharedApplication]];
        
        self.automaticallyRefreshesContents = YES;
        self.currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.refreshTimer invalidate];
}

- (void)loadAd
{
    [self loadAdWithTargeting:nil];
}

- (void)loadAdWithTargeting:(PMAdRequestTargeting *)targeting
{
    if (self.loading) {
        LogWarn(@"Banner view (%@) is already loading an ad. Wait for previous load to finish.", self.adUnitId);
        return;
    }
    self.targeting = targeting;
    
    NSAssert(_adUnitId !=nil,@"AdUnitId has not been set. Set it in the initWithAdUnitId: method");
    
    //Check if ad request object is already present (for PM_REQUEST_TYPE_ALL)
    if ([self.delegate respondsToSelector:@selector(getAdRequestObject)] && [self.delegate getAdRequestObject] != nil) {
        self.request = [self.delegate getAdRequestObject];
        self.request.delegate = self;
        
        if ([self.delegate respondsToSelector:@selector(sendCustomEventData:)])
            [self.delegate sendCustomEventData:[self.delegate getBannerCustomEventData]];

        UIView *bannerAd = [self.delegate getBannerAdResponse];
        if (bannerAd != nil) {
            [self.delegate managerDidLoadAd:bannerAd];
        }
        return;
        
    }
    self.request = [AdRequest requestWithAdUnitIdentifier:_adUnitId requestType:PM_REQUEST_TYPE_BANNER];
    self.request.targeting = targeting;
    self.request.viewController = [self.delegate viewControllerForPresentingModalView];
    self.request.delegate = self;
    if (self.requestDelayedAd) {
        self.request.requestDelayedAd = YES;
    } else {
        self.request.requestDelayedAd = NO;
    }
    
    __typeof__(self) __weak weakSelf = self;
    self.loading = true;
    
    [self.request startWithCompletionHandler:^(AdRequest *request, PMAdResponse *response, NSError *error) {
        __typeof__(self) strongSelf = weakSelf;
        
        if (!strongSelf) {
            return;
        }
        strongSelf.loading = false;
        if (strongSelf.automaticallyRefreshesContents) {
            [strongSelf scheduleRefreshTimer];
        }
        UIView *bannerAd = [response getPMBannerAdResponse];
        if ([self.delegate respondsToSelector:@selector(sendCustomEventData:)])
            [self.delegate sendCustomEventData:[response getCustomEventData]];

        if (error) {
            [self.delegate managerDidFailToLoadAdWithError:error];
        } else {
            [self.delegate managerDidLoadAd:bannerAd];
        }
    }];
}

- (void)forceRefreshAd
{
    [self loadAdWithTargeting:self.targeting];
}

- (void)applicationWillEnterForeground
{
    if (self.automaticallyRefreshesContents && self.hasRequestedAtLeastOneAd) {
        [self loadAdWithTargeting:self.targeting];
    }
}

- (void)applicationDidEnterBackground
{
    [self pauseRefreshTimer];
}

- (void)pauseRefreshTimer
{
    if ([self.refreshTimer isValid]) {
        [self.refreshTimer pause];
    }
}

- (void)stopAutomaticallyRefreshingContents
{
    self.automaticallyRefreshesContents = NO;
    
    [self pauseRefreshTimer];
}

- (void)startAutomaticallyRefreshingContents
{
    self.automaticallyRefreshesContents = YES;
    
    if ([self.refreshTimer isValid]) {
        [self.refreshTimer resume];
    } else if (self.refreshTimer) {
        [self scheduleRefreshTimer];
    }
}

- (void)rotateToOrientation:(UIInterfaceOrientation)orientation
{
    [self.request rotateToOrientation:orientation];
}
#pragma mark - Internal

- (void)scheduleRefreshTimer
{
    [self.refreshTimer invalidate];
    NSTimeInterval timeInterval = DEFAULT_PMBANNER_REFRESH_INTERVAL;
    
    SDKConfigs *sdkConfigs = [self.delegate getSDKConfigs];
    if (sdkConfigs != nil) {
        timeInterval = sdkConfigs.refreshInterval;
    } else {
        LogWarn(@"SDK configuration has not yet returned. Using default banner refresh interval");
    }
    
    if (timeInterval > 0) {
        self.refreshTimer = [IANTimer timerWithTimeInterval:timeInterval target:self selector:@selector(refreshTimerDidFire) repeats:NO];
        [self.refreshTimer scheduleNow];
        LogDebug(@"Scheduled the autorefresh timer to fire in %.1f seconds (%p).", timeInterval, self.refreshTimer);
    }
}

- (void)refreshTimerDidFire
{
    if (!self.loading && self.automaticallyRefreshesContents) {
        [self loadAdWithTargeting:self.targeting];
    }
}

#pragma mark - <PMCommonAdDelegate>
- (void)userWillLeaveApplication
{
    if ([self.delegate respondsToSelector:@selector(userWillLeaveApplication)]) {
        [self.delegate userWillLeaveApplication];
    }
}

- (CGSize)containerSize
{
    return [self.delegate containerSize];
}

- (void)isRenderedPMAd:(UIView *)ad
{
    [self.delegate managerDidLoadAd:ad];
}
@end
