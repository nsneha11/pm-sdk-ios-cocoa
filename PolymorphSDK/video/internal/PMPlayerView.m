//
//  PMPlayerView.m
//
//  Created by Arvind Bharadwaj on 12/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "PMPlayerView.h"
#import "PMAVPlayerView.h"
#import "Logging.h"
#import "UIColor+PMAdditions.h"

static NSString * const progressBarFillColor = @"#EA101C";
static NSString * const progressBarBackgroundFillColor = @"#C2BFB9";
static CGFloat const videoProgressBarHeight = 4.0f;

// gradient
static NSString * const topGradientColor = @"#000000";
static NSString * const bottomGradientColor = @"#000000";
static CGFloat const topGradientAlpha = 0.0f;
static CGFloat const bottomGradientAlpha = 0.4f;
static CGFloat const gradientViewHeight = 25.0f;

@interface PMPlayerView()

@property (nonatomic) PMAVPlayerView *avView;
@property (nonatomic) UIView *progressBarBackground;
@property (nonatomic) UIView *progressBar;
@property (nonatomic) UIView *gradientView;
@property (nonatomic) CAGradientLayer *gradient;

@property (nonatomic) UITapGestureRecognizer *tapGestureRecognizer;
@property (nonatomic, weak) id<PMPlayerViewDelegate> delegate;

@end

@implementation PMPlayerView

- (instancetype)initWithFrame:(CGRect)frame delegate:(id<PMPlayerViewDelegate>)delegate
{
    self = [super initWithFrame:frame];
    if (self) {
        _delegate = delegate;
        
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avPlayerTapped)];
        [self addGestureRecognizer:_tapGestureRecognizer];
    }
    return self;
}

- (void)dealloc
{
    [self.tapGestureRecognizer removeTarget:self action:@selector(avPlayerTapped)];
}

- (void)createPlayerView
{
    self.clipsToBounds = YES;
    if (!self.gradientView && self.displayMode == ANPlayerDisplayModeInline) {
        // Create the gradient
        self.gradientView = [UIView new];
        UIColor *topColor = [UIColor pm_colorFromHexString:topGradientColor alpha:topGradientAlpha];
        UIColor *bottomColor = [UIColor pm_colorFromHexString:bottomGradientColor alpha:bottomGradientAlpha];
        self.gradient = [CAGradientLayer layer];
        self.gradient.colors = [NSArray arrayWithObjects: (id)topColor.CGColor, (id)bottomColor.CGColor, nil];
        self.gradient.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), gradientViewHeight);
        
        //Add gradient to view
        [self.gradientView.layer insertSublayer:self.gradient atIndex:0];
        [self addSubview:self.gradientView];
    }
    
    if (!self.progressBar) {
        self.progressBar = [[UIView alloc] init];
        self.progressBarBackground = [[UIView alloc] init];
        [self addSubview:self.progressBarBackground];
        
        self.progressBarBackground.backgroundColor = [UIColor pm_colorFromHexString:progressBarBackgroundFillColor alpha:1.0f];
        self.progressBar.backgroundColor = [UIColor pm_colorFromHexString:progressBarFillColor alpha:1.0f];
        [self addSubview:self.progressBar];
    }
}

#pragma mark - set avPlayer

- (void)setAvPlayer:(PMAVPlayer *)player
{
    if (!player) {
        LogError(@"Cannot set avPlayer to nil");
        return;
    }
    if (_avPlayer == player) {
        return;
    }
    _avPlayer = player;
    [_avView removeFromSuperview];
    _avView = [[PMAVPlayerView alloc] initWithFrame:CGRectZero];
    _avView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.avView.player = self.avPlayer;
    self.avView.frame = (CGRect){CGPointZero, self.bounds.size};
    [self insertSubview:_avView atIndex:0];
}

- (void)setVideoGravity:(NSString *)videoGravity
{
    ((AVPlayerLayer *)_avView.layer).videoGravity = videoGravity;
}

// make the player view not clickable when initializing video failed.
- (void)handleVideoInitFailure
{
    [self removeGestureRecognizer:self.tapGestureRecognizer];
}

#pragma mark - Synchronize UI Elements

- (void)playbackTimeDidProgress
{
    [self layoutProgressBar];
}

- (void)playbackDidFinish
{
    //decide what to do to the view when playback finishes
}

- (void)setProgressBarVisible:(BOOL)visible
{
    self.progressBarBackground.hidden = !visible;
    self.progressBar.hidden = !visible;
}

#pragma mark - Touch event

- (void)avPlayerTapped
{
    if ([self.delegate respondsToSelector:@selector(playerViewScreenTapped:)]) {
        [self.delegate playerViewScreenTapped:self];
    }
    
    // Only trigger tap event in infeed mode
//    if (self.displayMode == ANPlayerDisplayModeInline) {
//        self.displayMode = ANPlayerDisplayModeFullscreen;
//        if ([self.delegate respondsToSelector:@selector(playerViewWillEnterFullscreen:)]) {
//            [self.delegate playerViewWillEnterFullscreen:self];
//        }
//        [self setNeedsLayout];
//        [self layoutIfNeeded];
//    }
}

#pragma mark - layout views

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self layoutProgressBar];
    [self layoutGradientview];
}

- (void)layoutProgressBar
{
    if (self.avPlayer && !isnan(self.avPlayer.currentItemDuration)) {
        CGFloat vcWidth = CGRectGetWidth(self.bounds);
        CGFloat currentProgress = self.avPlayer.currentPlaybackTime/self.avPlayer.currentItemDuration;
        if (currentProgress < 0) {
            currentProgress = 0;
            LogError(@"Progress shouldn't be < 0");
        }
        if (currentProgress > 1) {
            currentProgress = 1;
            LogError(@"Progress shouldn't be > 1");
        }
        
        self.progressBar.frame = CGRectMake(0, CGRectGetMaxY(self.avView.frame)- videoProgressBarHeight, vcWidth * currentProgress, videoProgressBarHeight);
        self.progressBarBackground.frame = CGRectMake(0, CGRectGetMaxY(self.avView.frame) - videoProgressBarHeight, vcWidth, videoProgressBarHeight);
    }
}

- (void)layoutGradientview
{
    if (self.displayMode == ANPlayerDisplayModeInline) {
        self.gradientView.hidden = NO;
        self.gradient.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), gradientViewHeight);
        self.gradientView.frame = CGRectMake(0, CGRectGetMaxY(self.avView.frame) - gradientViewHeight, CGRectGetWidth(self.bounds),  gradientViewHeight);
    } else {
        self.gradientView.hidden = YES;
    }
}

@end
