//
//  PMMediaViewRenderer.m
//
//  Created by Arvind Bharadwaj on 15/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "PMMediaViewRenderer.h"
#import "PMPlayerViewController.h"
#import "PMWebViewPlayerViewController.h"
#import "PMAVFullscreenPlayerViewController.h"
#import "IANTimer.h"
#import "PMMediaPlayerManager.h"
#import "ViewChecker.h"
#import "PMAVFullscreenPlayerViewController.h"
#import "AdAssets.h"
#import "InstanceProvider.h"
#import "Logging.h"
#import "SDKConfigs.h"

static const CGFloat autoPlayTimerInterval = 0.25f;

@interface PMMediaViewRenderer() <PMPlayerViewControllerDelegate,PMAVFullscreenPlayerViewControllerDelegate,PMWebViewPlayerViewControllerDelegate>

@property (nonatomic, weak, readonly) NSDictionary *nativeAssets;
@property (nonatomic, weak, readonly) id<AdAdapter> adAdapter;
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, weak) PMPlayerViewController *avVideoController;
@property (nonatomic, weak) PMWebViewPlayerViewController *webViewVideoController;
@property (nonatomic, weak) UIViewController *videoViewController;
@property (nonatomic) PMAVFullscreenPlayerViewController *fullScreenController;
@property (nonatomic) IANTimer *autoPlayTimer;
@property (nonatomic) float percentVisibleForAutoPlay;

//Tracker
@property (nonatomic) NSMutableDictionary *percentageTrackers;
@property (nonatomic) NSSet *completionTrackers;
@property (nonatomic) NSSet *videoPlayTrackers;

@property (nonatomic) BOOL hasTrackedVideoImpression;
@property (nonatomic) BOOL hasTrackedVideoPlay;
@property (nonatomic) BOOL hasTrackedVideoPercentPlay;
@property (nonatomic) BOOL hasTrackedVideoCompletion;

@property (nonatomic, assign) NSTimeInterval firstVisibilityTimestamp;

@end

@implementation PMMediaViewRenderer

-(instancetype)initWithAdAdapter:(id<AdAdapter>)adAdapter
{
    self = [super init];
    if (self) {
        _adAdapter = adAdapter;
        _nativeAssets = [_adAdapter nativeAssets];
        SDKConfigs *configs = [_nativeAssets objectForKey:kNativeSDKConfigsKey];
        self.percentVisibleForAutoPlay = configs.percentVisibleForAutoplay;
        self.firstVisibilityTimestamp = -1;
       
        [self setUpVideoTracking];
    }
    return self;
}

- (void)dealloc
{
    [_autoPlayTimer invalidate];
    _autoPlayTimer = nil;
}

- (void)dispose
{
    self.fullScreenController = nil;
    // free the video memory if the instance returned is the current video controller instance
    if ([PMMediaPlayerManager sharedInstance].currentPlayerViewController == self.videoViewController) {
        [[PMMediaPlayerManager sharedInstance] disposePlayerViewController];
    }
}

-(void)setUpVideoView
{
    if (!self.videoViewController) {
    
        self.videoViewController = [[PMMediaPlayerManager sharedInstance] playerViewControllerWithAdAssets:_nativeAssets];
        
        if ([self.videoViewController isKindOfClass:[PMPlayerViewController class]]) {
            self.avVideoController = (PMPlayerViewController *)self.videoViewController;
            self.avVideoController.displayMode = ANPlayerDisplayModeInline;
            self.avVideoController.delegate = self;
        } else {
            self.webViewVideoController = (PMWebViewPlayerViewController *)self.videoViewController;
            self.webViewVideoController.delegate = self;
        }
        
    }
}

-(void)layoutVideoIntoView:(UIView *)mediaView withViewController:(UIViewController *)viewController
{
    [self setUpVideoView];
    
    self.viewController = viewController;
    
    self.videoViewController.view.frame = mediaView.bounds;
    self.videoViewController.view.contentMode = mediaView.contentMode;
    
    [mediaView addSubview:self.videoViewController.view];
    [mediaView bringSubviewToFront:self.videoViewController.view];
    
    if (!self.autoPlayTimer) {
        self.autoPlayTimer = [IANTimer timerWithTimeInterval:autoPlayTimerInterval target:self selector:@selector(tick:) repeats:YES];
        self.autoPlayTimer.runLoopMode = NSRunLoopCommonModes;
        [self.autoPlayTimer scheduleNow];
    }
    
}

- (void)tick:(IANTimer *)timer
{
    [self setVisible:ViewIsVisible(self.videoViewController.view) && ViewIntersectsParentWindowWithPercent(self.videoViewController.view, (CGFloat)0.1) && !self.hasTrackedVideoImpression];
    
    if (self.avVideoController) {
        BOOL loadVisible = ViewIntersectsParentWindowWithPercent(self.avVideoController.playerView, 1.0/100.0f);
        if (loadVisible) {
            // start new
            if ([self.avVideoController shouldStartNewPlayer]) {
                [self.avVideoController loadAndPlayVideo];
            }
        }
        
        // pause video
        BOOL pauseVisible = !ViewIntersectsParentWindowWithPercent(self.avVideoController.playerView, self.percentVisibleForAutoPlay/100.0f);
        if (pauseVisible) {
            if ([self.avVideoController shouldPausePlayer]) {
                [self.avVideoController pause];
            }
        } else {
            // resume play
            if ([self.avVideoController shouldResumePlayer]) {
                [self.avVideoController resume];
            }
        }
        
        //Autoplay Video
        BOOL autoPlayVisible = ViewIntersectsParentWindowWithPercent(self.avVideoController.playerView, self.percentVisibleForAutoPlay/100.0f);
        if (autoPlayVisible) {
            if ([self.avVideoController shouldAutoPlayPlayer]) {
                [self.avVideoController play];
            }
        }
    }
    
    if (self.webViewVideoController) {
        BOOL loadVisible = ViewIntersectsParentWindowWithPercent(self.webViewVideoController.view, 1.0/100.0f);
        if (loadVisible) {
            // start new
            if ([self.webViewVideoController shouldStartNewPlayer]) {
                [self.webViewVideoController play];
            }
        }
        
        // pause video
        BOOL pauseVisible = !ViewIntersectsParentWindowWithPercent(self.webViewVideoController.view, self.percentVisibleForAutoPlay/100.0f);
        if (pauseVisible) {
            if ([self.webViewVideoController shouldPausePlayer]) {
                [self.webViewVideoController pause];
            }
        } else{
            // resume play
            if ([self.webViewVideoController shouldResumePlayer]) {
                [self.webViewVideoController resume];
            }
        }
        
    }
}

#pragma mark - PMWebViewPlayerViewControllerDelegate
- (void)webViewPlayerDidPlay
{
    [self trackVideoDidStartPlay];
}

- (void)webViewPlayerDidProgressToTime:(NSTimeInterval)playbackTime withTotalTime:(NSTimeInterval)totalTime
{
    [self trackVideoPercentagePlayWithTime:playbackTime andTotalTime:totalTime];
}

- (void)webViewPlayerDidFinishPlayback
{
    [self trackVideoDidFinishPlay];
}

- (void)webViewPlayerDidTrackClick
{
    [self trackVideoClick];
}

#pragma mark - PMPlayerViewControllerDelegate

- (void)willEnterFullscreen:(PMPlayerViewController *)viewController
{
    [self enterFullscreen:_viewController];
}

- (void)playerDidProgressToTime:(NSTimeInterval)playbackTime withTotalTime:(NSTimeInterval)totalTime
{
    [self trackVideoPercentagePlayWithTime:playbackTime andTotalTime:totalTime];
}

- (void)playerPlaybackDidStart:(PMPlayerViewController *)player
{
    [self trackVideoDidStartPlay];
}

- (void)playerPlaybackDidFinish:(PMPlayerViewController *)player
{
    [self trackVideoDidFinishPlay];
}

- (void)playerViewDidTrackClick:(PMPlayerView *)view
{
    [self trackVideoClick];
}

#pragma mark - PMAVFullscreenPlayerViewControllerDelegate
- (void)playerDidProgressToTime:(NSTimeInterval)playbackTime totalTime:(NSTimeInterval)totalTime
{
    [self playerDidProgressToTime:playbackTime withTotalTime:totalTime];
}

#pragma mark - Internal
- (void)enterFullscreen:(UIViewController *)fromViewController
{
    self.fullScreenController = [[PMAVFullscreenPlayerViewController alloc]initWithVideoPlayer:self.avVideoController nativeAssets:self.nativeAssets dismissBlock:^(UIView *originalParentView) {
        self.avVideoController.view.frame = originalParentView.bounds;
        self.avVideoController.delegate = self;
        [self.avVideoController willExitFullscreen];
        
        [originalParentView addSubview:self.avVideoController.playerView];
        [self.fullScreenController dispose];
    }];
    
    self.fullScreenController.delegate = self;
    
    [fromViewController presentViewController:self.fullScreenController animated:NO completion:nil];
}

- (void)setUpVideoTracking
{
    self.percentageTrackers = [self.nativeAssets objectForKey:kNativeVideoPercentageTrackerKey];
    self.completionTrackers = [self.nativeAssets objectForKey:kNativeVideoCompletionTrackerKey];
    self.videoPlayTrackers = [self.nativeAssets objectForKey:kNativeVideoPlayTrackerKey];
    
}

- (void)setVisible:(BOOL)visible
{
    if (visible) {
        NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
        if (self.firstVisibilityTimestamp == -1) {
            self.firstVisibilityTimestamp = now;
            
        } else if (now - self.firstVisibilityTimestamp >= 1.0) {
            self.firstVisibilityTimestamp = -1;
            
            [self trackVideoImpression];
        }
    } else {
        self.firstVisibilityTimestamp = -1;
    }
}

#pragma mark - Video Tracking
- (void)trackVideoImpression
{
    BOOL isPlayerLoaded;
    if (self.avVideoController) {
        isPlayerLoaded = self.avVideoController.isReadyToPlay;
    } else {
        isPlayerLoaded = self.webViewVideoController.isReadyToPlay;
    }
    
    if (!isPlayerLoaded) {
        return;
    }
    self.hasTrackedVideoImpression = YES;
    NSSet *impressionTrackers = [self.nativeAssets objectForKey:kNativeVideoImpressionTrackerKey];
    
    LogDebug(@"Number of video impression trackers : %lu",[impressionTrackers count]);
    for (NSString *URLString in impressionTrackers) {
        NSURL *URL = [NSURL URLWithString:URLString];
        if (URL) {
            LogDebug(@"Firing video impression tracking url %@",[URL absoluteString]);
            [self trackMetricForURL:URL];
        }
    }
}

- (void)trackVideoDidStartPlay
{
    if (self.hasTrackedVideoPlay) {
        LogDebug(@"Video play already tracked.");
        return;
    }
    
    self.hasTrackedVideoPlay = YES;
    
    LogDebug(@"Number of video play trackers : %lu",[self.videoPlayTrackers count]);
    for (NSString *URLString in self.videoPlayTrackers) {
        NSURL *URL = [NSURL URLWithString:URLString];
        if (URL) {
            LogDebug(@"Firing video play tracking url %@",[URL absoluteString]);
            [self trackMetricForURL:URL];
        }
    }
}

- (void)trackVideoPercentagePlayWithTime:(NSTimeInterval)currentTime andTotalTime:(NSTimeInterval)totalTime
{
    //    NSLog(@"Time:%@ and total time:%@",[NSString stringWithFormat:@"%f", playbackTime],[NSString stringWithFormat:@"%f",totalTime]);
    double currentPercentTime = (currentTime/totalTime);
    
    NSString *keyToRemove = nil;
    for (NSString *key in self.percentageTrackers) {
        
        double trackingTime = [key doubleValue]/100;
        
        if (currentPercentTime >= trackingTime) {
            NSSet *percentTracker = [self.percentageTrackers objectForKey:key];
            keyToRemove = (NSString *)key;
            LogDebug(@"Number of video watched trackers for percent:%@ :%lu",key,[percentTracker count]);
            for (NSString *URLString in percentTracker) {
                NSURL *URL = [NSURL URLWithString:URLString];
                if (URL) {
                    LogDebug(@"Firing video watched tracker for percent:%@ and url: %@",key,[URL absoluteString]);
                    [self trackMetricForURL:URL];
                }
            }
        }
    }
    
    if (keyToRemove != nil) {
        [self.percentageTrackers removeObjectForKey:keyToRemove];
    }
}

- (void)trackVideoDidFinishPlay
{
    if (self.hasTrackedVideoCompletion) {
        LogDebug(@"Video completion already tracked.");
        return;
    }
    
    self.hasTrackedVideoCompletion = YES;
    
    LogDebug(@"Number of video completion trackers : %lu",[self.completionTrackers count]);
    for (NSString *URLString in self.completionTrackers) {
        NSURL *URL = [NSURL URLWithString:URLString];
        if (URL) {
            LogDebug(@"Firing completion tracking url %@",[URL absoluteString]);
            [self trackMetricForURL:URL];
        }
    }
}

- (void)trackVideoClick
{
    NSSet *videoClickTrackers = [self.nativeAssets objectForKey:kNativeVideoClickThroughTrackerKey];
    
    LogDebug(@"Number of video click trackers : %lu",[videoClickTrackers count]);
    for (NSString *URLString in videoClickTrackers) {
        NSURL *URL = [NSURL URLWithString:URLString];
        if (URL) {
            LogDebug(@"Firing video click tracking url %@",[URL absoluteString]);
            [self trackMetricForURL:URL];
        }
    }
}

- (void)trackMetricForURL:(NSURL *)URL
{
    NSMutableURLRequest *request = [[InstanceProvider sharedProvider] buildConfiguredURLRequestWithURL:URL];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    [NSURLConnection connectionWithRequest:request delegate:nil];
}
@end
