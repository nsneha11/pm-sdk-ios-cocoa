//
//  PMWebViewPlayerViewController.m
//
//  Created by Arvind Bharadwaj on 16/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "PMWebViewPlayerViewController.h"
#import "PMWebViewPlayer.h"

@interface PMWebViewPlayerViewController () <PMWebViewPlayerDelegate>

@property (nonatomic) NSDictionary *nativeAssets;
@property (nonatomic) ANWebViewPlayer *webPlayer;
@property (nonatomic) UIView *webPlayerView;
@property (nonatomic) UIView *clickTrackerOverlayView;

@property (nonatomic) BOOL webViewClickTracked;
@end

@implementation PMWebViewPlayerViewController

- (instancetype)initWithNativeAssets:(NSDictionary *)nativeAssets
{
    self = [super init];
    if (self) {
        _nativeAssets = nativeAssets;
        _webPlayer = [[ANWebViewPlayer alloc] initWithNativeAssets:nativeAssets];
        _webPlayer.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    _webPlayerView = [_webPlayer getPlayerView];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    _webPlayerView.frame = self.view.bounds;
    [self.view addSubview:_webPlayerView];
    [self.view bringSubviewToFront:_webPlayerView];
    
}

- (void)dispose
{
    [self.view removeFromSuperview];
    _webPlayerView = nil;
    [_webPlayer dispose];
    _webPlayer = nil;
    self.disposed = YES;
}

- (void)addWebViewClickTrackerOverlay
{
    //Add Subview Overlay for click through url
    self.clickTrackerOverlayView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.clickTrackerOverlayView.backgroundColor = [UIColor clearColor];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(webViewTapped)];
    [self.clickTrackerOverlayView addGestureRecognizer:tap];
    
    for (UIView *subView in [self.view subviews]) {
        //add subview to the first subview of this view controllers view
        [subView addSubview:self.clickTrackerOverlayView];
        [subView bringSubviewToFront:self.clickTrackerOverlayView];
        break;
    }
}

- (void)removeWebViewClickTrackerOverlay
{
    [self.clickTrackerOverlayView removeFromSuperview];
}

#pragma mark - player controls
- (void)play
{
    self.paused = NO;
    self.playing = YES;
    [self.webPlayer playVideo];
}

- (void)pause
{
    self.paused = YES;
    self.playing = NO;
    [self.webPlayer pauseVideo];
}

- (void)resume
{
    self.paused = NO;
    self.playing = YES;
    [self.webPlayer playVideo];
}

#pragma mark - auto play helper method
- (BOOL)shouldStartNewPlayer
{
//    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
//    if (self.isReadyToPlay && !self.playing && !self.paused && state == UIApplicationStateActive) {
//        return YES;
//    }
    
    //As autoplay is disabled always return NO
    return NO;
}

- (BOOL)shouldResumePlayer
{
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    //checking self.paused together with webPlayerState as paused lets us determine if user paused
    //the webview video or not
    if (self.paused == YES && state == UIApplicationStateActive && self.webPlayer.webPlayerState == kWebPlayerStatePaused) {
        return YES;
    }
    return NO;
}

- (BOOL)shouldPausePlayer
{
    if (self.webPlayer.webPlayerState == kWebPlayerStatePlaying) {
        return YES;
    }
    return NO;
}

#pragma mark - PMWebViewPlayerDelegate

- (void)webViewPlayerDidProgressToTime:(NSTimeInterval)playbackTime withTotalTime:(NSTimeInterval)totalTime
{
    if ([self.delegate respondsToSelector:@selector(webViewPlayerDidProgressToTime:withTotalTime:)]) {
        [self.delegate webViewPlayerDidProgressToTime:playbackTime withTotalTime:totalTime];
    }
}

- (void)webViewPlayerReadyToPlay
{
    self.isReadyToPlay = YES;
}

- (void)webViewPlayerDidPlay
{
    if ([self.delegate respondsToSelector:@selector(webViewPlayerDidPlay)]) {
        [self.delegate webViewPlayerDidPlay];
    }
    if (!self.webViewClickTracked) {
        self.webViewClickTracked = YES;
        [self addWebViewClickTrackerOverlay];
    }
}

/* 
 * This method will be called only once as the view that calls this on method on tap gets 
 * removed inside this.
 */
- (void)webViewTapped
{
    [self removeWebViewClickTrackerOverlay];
    if ([self.delegate respondsToSelector:@selector(webViewPlayerDidTrackClick)]) {
        [self.delegate webViewPlayerDidTrackClick];
    }
}

- (void)webViewPlayerDidFinishPlayback
{
    if ([self.delegate respondsToSelector:@selector(webViewPlayerDidFinishPlayback)]) {
        [self.delegate webViewPlayerDidFinishPlayback];
    }
}

#pragma mark - Application state monitoring

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    if (self.webPlayer) {
        [self pause];
    }
}

- (void)applicationDidEnterForeground:(NSNotification *)notification
{
    if (self.webPlayer && self.isReadyToPlay) {
        [self resume];
    }
}

@end
