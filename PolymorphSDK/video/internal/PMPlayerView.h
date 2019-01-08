//
//  PMPlayerView.h
//
//  Created by Arvind Bharadwaj on 12/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PMAVPlayer.h"

@class PMPlayerView;

typedef NS_ENUM(NSUInteger, ANPlayerDisplayMode) {
    ANPlayerDisplayModeInline = 0,
    ANPlayerDisplayModeFullscreen
};

@protocol PMPlayerViewDelegate <NSObject>

- (void)playerViewScreenTapped:(PMPlayerView *)view;

@end

@interface PMPlayerView : UIControl

@property (nonatomic) PMAVPlayer *avPlayer;
@property (nonatomic) ANPlayerDisplayMode displayMode;
@property (nonatomic, copy) NSString *videoGravity;

- (instancetype)initWithFrame:(CGRect)frame delegate:(id<PMPlayerViewDelegate>)delegate;

- (void)createPlayerView;
- (void)playbackTimeDidProgress;
- (void)playbackDidFinish;
- (void)setProgressBarVisible:(BOOL)visible;
- (void)handleVideoInitFailure;

@end
