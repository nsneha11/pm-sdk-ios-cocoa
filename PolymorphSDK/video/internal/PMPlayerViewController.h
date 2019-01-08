//
//  PMPlayerViewController.h
//
//  Created by Arvind Bharadwaj on 12/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PMPlayerView.h"

@class AVPlayerItem;
@class PMAVPlayer;
@class PMPlayerViewController;

@protocol PMPlayerViewControllerDelegate <NSObject>

@optional
- (void)playerViewScreenTapped:(PMPlayerView *)view;
- (void)playerViewDidTrackClick:(PMPlayerView *)view;
- (void)willEnterFullscreen:(PMPlayerViewController *)viewController;
- (void)playerPlaybackWillStart:(PMPlayerViewController *)player;
- (void)playerPlaybackDidStart:(PMPlayerViewController *)player;
- (void)playerPlaybackDidFinish:(PMPlayerViewController *)player;
- (void)playerDidProgressToTime:(NSTimeInterval)playbackTime withTotalTime:(NSTimeInterval)totalTime;
- (void)playerViewController:(PMPlayerViewController *)playerViewController didStall:(PMAVPlayer *)player;
- (void)playerViewController:(PMPlayerViewController *)playerViewController didRecoverFromStall:(PMAVPlayer *)player;

- (UIViewController *)viewControllerForPresentingModalView;

@end

@interface PMPlayerViewController : UIViewController

@property (nonatomic, readonly) NSDictionary *nativeAssets;

@property (nonatomic, strong) PMPlayerView *playerView;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) PMAVPlayer *avPlayer;
@property (nonatomic, readonly) CGFloat videoAspectRatio;

#pragma mark - Configurations/States
@property (nonatomic) ANPlayerDisplayMode displayMode;
@property (nonatomic) BOOL muted;
@property (nonatomic) BOOL startedLoading;
@property (nonatomic) BOOL playing;
@property (nonatomic) BOOL paused;
@property (nonatomic) BOOL userPaused;
@property (nonatomic) BOOL isReadyToPlay;
@property (nonatomic) BOOL finishedPlaying;
@property (nonatomic) BOOL disposed;

@property (nonatomic, weak) id<PMPlayerViewControllerDelegate> delegate;

#pragma mark - Initializer
- (instancetype)initWithNativeAssets:(NSDictionary *)nativeAssets;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)playerViewScreenTapped:(PMPlayerView *)view;

- (void)loadAndPlayVideo;
- (void)seekToTime:(NSTimeInterval)time;
- (void)play;
- (void)pause;
- (void)resume;
- (void)dispose;

- (BOOL)shouldStartNewPlayer;
- (BOOL)shouldAutoPlayPlayer;
- (BOOL)shouldResumePlayer;
- (BOOL)shouldPausePlayer;

- (void)willEnterFullscreen;
- (void)willExitFullscreen;
@end
