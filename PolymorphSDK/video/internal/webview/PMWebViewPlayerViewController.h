//
//  PMWebViewPlayerViewController.h
//
//  Created by Arvind Bharadwaj on 16/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PMWebViewPlayerViewControllerDelegate <NSObject>

@optional
- (void)webViewPlayerDidPlay;
- (void)webViewPlayerDidProgressToTime:(NSTimeInterval)playbackTime withTotalTime:(NSTimeInterval)totalTime;
- (void)webViewPlayerDidFinishPlayback;
- (void)webViewPlayerDidTrackClick;

@end

@interface PMWebViewPlayerViewController : UIViewController

#pragma mark - Configurations/States
@property (nonatomic) BOOL muted;
@property (nonatomic) BOOL startedLoading;
@property (nonatomic) BOOL playing;
@property (nonatomic) BOOL paused;
@property (nonatomic) BOOL isReadyToPlay;
@property (nonatomic) BOOL disposed;

- (instancetype)initWithNativeAssets:(NSDictionary *)nativeAssets;
@property (nonatomic) UIWebView *webView;

@property (nonatomic,weak) id<PMWebViewPlayerViewControllerDelegate> delegate;

- (void)play;
- (void)pause;
- (void)resume;
- (void)dispose;

- (BOOL)shouldStartNewPlayer;
- (BOOL)shouldResumePlayer;
- (BOOL)shouldPausePlayer;

@end
