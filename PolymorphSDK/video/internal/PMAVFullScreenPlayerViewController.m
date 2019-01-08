//
//  PMAVFullscreenPlayerViewController.m
//
//  Created by Arvind Bharadwaj on 15/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "PMAVFullScreenPlayerViewController.h"
#import "PMPlayerViewController.h"
#import "PMImageDownloader.h"
#import "UIView+PMAdditions.h"
#import "UIButton+PMAdditions.h"
#import "UIColor+PMAdditions.h"
#import "AdAssets.h"
#import "SDKConfigs.h"

static CGFloat const kCloseButtonRightAndTopMargin = 5.0f;
static CGFloat const kDefaultButtonTouchAreaInsets = 10.0f;

static NSString * const kTopGradientColor = @"#000000";
static NSString * const kBottomGradientColor= @"#000000";
static CGFloat const kTopGradientAlpha = 0.4f;
static CGFloat const kBottomGradientAlpha = 0.0f;
static CGFloat const kGradientHeight = 42;

//static CGFloat const kStallSpinnerSize = 35.0f;

@interface PMAVFullscreenPlayerViewController () <PMPlayerViewControllerDelegate,PMImageDownloaderDelegate>

// UI components
@property (nonatomic) UIButton *closeButton;
@property (nonatomic) UIView *playButtonView;
@property (nonatomic) UIActivityIndicatorView *playerNotReadySpinner;
@property (nonatomic) UIView *gradientView;
@property (nonatomic) CAGradientLayer *gradient;

@property (nonatomic) PMPlayerViewController *playerController;
@property (nonatomic) UIView *originalParentView;
@property (nonatomic) PMImageDownloader *imageDownloader;
@property (nonatomic) NSDictionary *nativeAssets;
@property (nonatomic) SDKConfigs *sdkConfigs;

@property (nonatomic, copy) PMAVFullscreenPlayerViewControllerDismissBlock dismissBlock;


@end

@implementation PMAVFullscreenPlayerViewController

- (instancetype)initWithVideoPlayer:(PMPlayerViewController *)playerController nativeAssets:(NSDictionary *)nativeAssets dismissBlock:(PMAVFullscreenPlayerViewControllerDismissBlock)dismissBlock
{
    if (self = [super init]) {
        _isPresented = YES;
        _playerController = playerController;
        _originalParentView = self.playerController.playerView.superview;
        _playerView = self.playerController.playerView;
        _playerController.delegate = self;
        _dismissBlock = [dismissBlock copy];
        _nativeAssets = nativeAssets;
        _sdkConfigs = [self.nativeAssets objectForKey:kNativeSDKConfigsKey];
        
        _imageDownloader = [[PMImageDownloader alloc] init];
        _imageDownloader.delegate = self;
        
        NSMutableArray <NSURL *> *imageURLs = [[NSMutableArray alloc] init];
        [imageURLs addObject:[NSURL URLWithString:self.sdkConfigs.closeButtonImageURL]];
        [imageURLs addObject:[NSURL URLWithString:self.sdkConfigs.playButtonImageURL]];
        [_imageDownloader downloadAndCacheImagesWithURLs:imageURLs];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.playerController willEnterFullscreen];
    
    self.view.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.playerView];
    
    [self createAndAddGradientView];
    
    
    if (!self.playerController.isReadyToPlay) {
        [self createPlayerNotReadySpinner];
    }
    
    if (self.playerController.userPaused) {
        [self addPlayButtonOverlay];
    }
}

- (void)dispose
{
    self.imageDownloader = nil;
    self.playerController = nil;
}

- (void)addPlayButtonOverlay
{
    UIView *playButtonView = [[UIView alloc] initWithFrame:self.view.bounds];
    playButtonView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.25];
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playButtonViewTapped)];
    [playButtonView addGestureRecognizer:tapGestureRecognizer];
    
    _playButtonView = playButtonView;
    
    [self.view addSubview:playButtonView];
    [self.view bringSubviewToFront:playButtonView];
    
    //get close button to front of play button
    [self.view bringSubviewToFront:self.closeButton];
}

- (void)removePlayButtonOverlay
{
    [[self.playButtonView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.playButtonView removeFromSuperview];
}


- (void)createAndAddCloseButton
{
    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    
    [self.closeButton setImage:[_imageDownloader getCachedImageForURL:[NSURL URLWithString:self.sdkConfigs.closeButtonImageURL]] forState:UIControlStateNormal];
    [self.closeButton addTarget:self action:@selector(closeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    self.closeButton.pm_TouchAreaInsets = UIEdgeInsetsMake(kDefaultButtonTouchAreaInsets, kDefaultButtonTouchAreaInsets, kDefaultButtonTouchAreaInsets, kDefaultButtonTouchAreaInsets);
    
    [self.closeButton sizeToFit];
    [self.view addSubview:self.closeButton];
}

- (void)createAndAddGradientView
{
    // Create the gradient
    self.gradientView = [UIView new];
    self.gradientView.userInteractionEnabled = NO;
    UIColor *topColor = [UIColor pm_colorFromHexString:kTopGradientColor alpha:kTopGradientAlpha];
    UIColor *bottomColor= [UIColor pm_colorFromHexString:kBottomGradientColor alpha:kBottomGradientAlpha];
    self.gradient = [CAGradientLayer layer];
    self.gradient.colors = [NSArray arrayWithObjects: (id)topColor.CGColor, (id)bottomColor.CGColor, nil];
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    self.gradient.frame = CGRectMake(0, 0, screenSize.width, kGradientHeight);
    
    //Add gradient to view
    [self.gradientView.layer insertSublayer:self.gradient atIndex:0];
    [self.view addSubview:self.gradientView];
}

- (void)createPlayerNotReadySpinner
{
    if (!self.playerNotReadySpinner) {
        self.playerNotReadySpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [self.view addSubview:self.playerNotReadySpinner];
        [self.playerNotReadySpinner startAnimating];
    }
}

- (void)removePlayerNotReadySpinner
{
    [self.playerNotReadySpinner stopAnimating];
    [self.playerNotReadySpinner removeFromSuperview];
    self.playerNotReadySpinner = nil;
}

#pragma mark - Layout UI components

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self layoutPlayerView];
    [self layoutCloseButton];
    [self layoutPlayerNotReadySpinner];
    [self layoutGradientView];
    [self layoutPlayButtonView];
}

- (void)layoutPlayerView
{
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    self.playerView.videoGravity = AVLayerVideoGravityResizeAspectFill;
    if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
        self.playerView.frame = CGRectMake(0, 0, screenSize.width, screenSize.height);
    } else {
        self.playerView.width = screenSize.width;
        self.playerView.height = self.playerView.width/self.playerController.videoAspectRatio;
        self.playerView.center = self.view.center;
        self.playerView.frame = CGRectIntegral(self.playerView.frame);
    }
}

- (void)layoutCloseButton
{
    CGFloat percent = 0.0f;
    if (self.view.frame.size.height > self.view.frame.size.width) {
        percent = 0.05f;
    } else {
        percent = 0.1f;
    }
    self.closeButton.width = percent *self.view.frame.size.height;
    self.closeButton.height = self.closeButton.width;
    CGRect frame = CGRectMake(self.view.frame.size.width - self.closeButton.width - kCloseButtonRightAndTopMargin, kCloseButtonRightAndTopMargin, self.closeButton.width, self.closeButton.height);
    self.closeButton.frame = frame;
}

- (void)layoutPlayerNotReadySpinner
{
    if (self.playerNotReadySpinner) {
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        self.playerNotReadySpinner.center = CGPointMake(screenSize.width/2.0f, screenSize.height/2.0f);
        self.playerNotReadySpinner.frame = CGRectIntegral(self.playerNotReadySpinner.frame);
    }
}

- (void)layoutGradientView
{
    if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
        self.gradientView.hidden = NO;
    } else {
        self.gradientView.hidden = YES;
    }
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    self.gradient.frame = CGRectMake(0, 0, screenSize.width, kGradientHeight);
    self.gradientView.frame = CGRectMake(0, 0, screenSize.width, kGradientHeight);
}

- (void)layoutPlayButtonView
{
    self.playButtonView.frame = self.view.bounds;
    
    UIImageView *playButtonImage = [[UIImageView alloc] initWithImage:[_imageDownloader getCachedImageForURL:[NSURL URLWithString:self.sdkConfigs.playButtonImageURL]]];
    
    CGFloat dimension = (self.playerController.playerView.frame.size.height>self.playerController.playerView.frame.size.width) ? self.playerController.playerView.frame.size.width : self.playerController.playerView.frame.size.height;
    CGFloat buttonSide = 0.3 * dimension;
    
    CGRect frame = CGRectMake(self.playButtonView.center.x - (buttonSide/2), self.playButtonView.center.y - (buttonSide/2), buttonSide, buttonSide);
    playButtonImage.frame = frame;
    
    [[self.playButtonView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.playButtonView addSubview:playButtonImage];
}
#pragma mark - button tap

- (void)closeButtonTapped
{
    self.isPresented = NO;
    [self dismissViewControllerAnimated:NO completion:^{
        if (self.dismissBlock) {
            self.dismissBlock(self.originalParentView);
        }
    }];
}

- (void)playButtonViewTapped
{
    //Ignore if video is over
    if (self.playerController.finishedPlaying) {
        return;
    }
    //Remove the play button view.
    [self removePlayButtonOverlay];
    
    //The play pause implementation is handled by PMPlayerViewController.
    [self.playerController playerViewScreenTapped:self.playerController.playerView];
}

#pragma mark - PMPlayerViewControllerDelegate

- (void)playerViewScreenTapped:(PMPlayerView *)view
{
    //add pause screen only if its user paused
    if (self.playerController.userPaused) {
        [self addPlayButtonOverlay];
    }
    
}

- (void)playerPlaybackDidStart:(PMPlayerViewController *)player
{
    [self removePlayerNotReadySpinner];
}

- (void)playerViewController:(PMPlayerViewController *)playerViewController willShowReplayView:(PMPlayerView *)view
{
    
}

- (void)playerViewController:(PMPlayerViewController *)playerViewController didStall:(PMAVPlayer *)player
{
//    if (self.stallSpinner) {
//        if (!self.stallSpinner.superview) {
//            [self.view addSubview:self.stallSpinner];
//        }
//        if (!self.stallSpinner.isAnimating) {
//            [self.stallSpinner startAnimating];
//        }
//    } else {
//        [self showStallSpinner];
//        [self.stallSpinner startAnimating];
//    }
}

- (void)playerViewController:(PMPlayerViewController *)playerViewController didRecoverFromStall:(PMAVPlayer *)player
{
//    [self hideStallSpinner];
}

- (void)playerDidProgressToTime:(NSTimeInterval)playbackTime withTotalTime:(NSTimeInterval)totalTime
{
    if ([self.delegate respondsToSelector:@selector(playerDidProgressToTime:totalTime:)]) {
        [self.delegate playerDidProgressToTime:playbackTime totalTime:totalTime];
    }
}

#pragma mark - Hidding status bar (iOS 7 and above)

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark - PMImageDownloaderDelegate
- (void)imagesDownloadedAndCached
{
    [self createAndAddCloseButton];
}
- (void)imagesDownloadFailed
{
    [self.sdkConfigs populateWithDefaultVideoAssets];
    [self createAndAddCloseButton];
}
@end
