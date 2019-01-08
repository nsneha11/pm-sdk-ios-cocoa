//
//  PMPlayerViewController.m
//
//  Created by Arvind Bharadwaj on 12/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "PMPlayerViewController.h"
#import "AdDestinationDisplayAgent.h"
#import "UIView+PMAdditions.h"
#import "Logging.h"
#import "InstanceProvider.h"
#import "UIButton+PMAdditions.h"
#import "PMImageDownloader.h"
#import "SDKConfigs.h"
#import "AdAssets.h"
#import "PMAVFullscreenPlayerViewController.h"

#define DefaultVideoAspectRatio 16.0f/9.0f

static NSString * const kTracksKey = @"tracks";
static NSString * const kPlayableKey = @"playable";

// playerItem keys
static NSString * const kStatusKey = @"status";
static NSString * const kCurrentItemKey = @"currentItem";
static NSString * const kLoadedTimeRangesKey = @"loadedTimeRanges";
static void *AudioControllerBufferingObservationContext = &AudioControllerBufferingObservationContext;

// UI specifications
static CGFloat const kMuteIconInlineModeBottomAndRightMargin = 5.0f;
static CGFloat const kMuteIconInlineModeTouchAreaInsets = 25.0f;

// force resume playback in 3 seconds. player might get stuck due to stalled item
static CGFloat const kDelayPlayInSeconds = 3.0f;

// We compare the buffered time to the length of the video to determine when it has been
// fully buffered. To account for rounding errors, allow a small error when making this
// calculation.
static const double kVideoFinishedBufferingAllowedError = 0.1;

@interface PMPlayerViewController () <PMAVPlayerDelegate, PMPlayerViewDelegate,AdDestinationDisplayAgentDelegate,PMImageDownloaderDelegate>

@property (nonatomic) NSURL *mediaURL;

@property (nonatomic) UIButton *muteButton;
@property (nonatomic) UIButton *expandButton;
@property (nonatomic) UIView *playButtonView;
@property (nonatomic) UIImageView *playButtonIcon;

@property (nonatomic) UIActivityIndicatorView *loadingIndicator;
@property (nonatomic) AdDestinationDisplayAgent *displayAgent;
@property (nonatomic) SDKConfigs *sdkConfigs;

@property (nonatomic) PMImageDownloader *imageDownloader;
@property (nonatomic) BOOL shouldAutoPlay;
@property (nonatomic) BOOL firstTimePlay;
@property (nonatomic) BOOL imagesDownloaded;
// KVO might be triggerd multipe times. This property is used to make sure the view will only be created once.
@property (nonatomic) BOOL alreadyInitialized;
@property (nonatomic) BOOL downloadFinishedEventFired;
@property (nonatomic) BOOL alreadyCreatedPlayerView;

@property (nonatomic) BOOL playerViewClickTracked;

@end

@implementation PMPlayerViewController

- (instancetype)initWithNativeAssets:(NSDictionary *)nativeAssets
{
    if (self = [super init]) {
        _nativeAssets = nativeAssets;
        _sdkConfigs = [nativeAssets objectForKey:kNativeSDKConfigsKey];
        if ([[self.nativeAssets objectForKey:kNativeVideoExperienceKey] isEqualToString:@"autoplay_inview"])
        {
            self.shouldAutoPlay = YES;
        }
        self.firstTimePlay = YES;
        _mediaURL = [self getVideoUrlFromNativeAssets:self.nativeAssets];
        
//        _mediaURL = [NSURL URLWithString:@"http://nordenmovil.com/urrea/InstalaciondelavaboURREAbaja.mp4"];
        
        [self setImagesToLoad];
        
        _playerView = [[PMPlayerView alloc] initWithFrame:CGRectZero delegate:self];
        self.displayMode = ANPlayerDisplayModeInline;
        
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(applicationDidEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        // default aspect ratio is 16:9
        _videoAspectRatio = DefaultVideoAspectRatio;
    }
    return self;
}

#pragma mark - Internal
- (void)setImagesToLoad
{
    _imageDownloader = [[PMImageDownloader alloc] init];
    _imageDownloader.delegate = self;
    
    NSMutableArray <NSURL *> *imageURLs = [[NSMutableArray alloc] init];
    [imageURLs addObject:[NSURL URLWithString:self.sdkConfigs.expandButtonImageURL]];
    [imageURLs addObject:[NSURL URLWithString:self.sdkConfigs.playButtonImageURL]];
    [imageURLs addObject:[NSURL URLWithString:self.sdkConfigs.closeButtonImageURL]];
    
    [_imageDownloader downloadAndCacheImagesWithURLs:imageURLs];
}

- (NSURL *)getVideoUrlFromNativeAssets:(NSDictionary *)nativeAssets
{
    NSSet *sources = [nativeAssets objectForKey:kNativeVideoSourcesKey];
    for (NSString *videoUrl in sources) {
        if ([videoUrl rangeOfString:@".mp4"].length > 0) {
            return [NSURL URLWithString:videoUrl];
        }
    }
    
    if ([sources count] > 0) {
        for (NSString *videoUrl in sources) {
            return [NSURL URLWithString:videoUrl];
        }

    }
    return nil;
}
#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.playerView];
    [self startLoadingIndicator];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    // Bring expand button (and play button if required) to front. This is necessary because the video view might be detached
    // and re-attached during fullscreen to in-feed transition

    if (!self.playing) {
        [self.view bringSubviewToFront:self.playButtonView];
    }
    [self.view bringSubviewToFront:self.expandButton];
    
    // Set playerView's frame so it will work for rotation
    self.playerView.frame = self.view.bounds;
    
    [self layoutPlayButtonOverlay];
    [self layoutExpandButton];
    [self layoutLoadingIndicator];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)layoutLoadingIndicator
{
    if (_loadingIndicator) {
        _loadingIndicator.x = (self.view.center.x) - (CGRectGetWidth(_loadingIndicator.bounds)/2);
        _loadingIndicator.y = (self.view.center.y) - (CGRectGetHeight(_loadingIndicator.bounds)/2);
    }
}

#pragma mark - dealloc or dispose the controller

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (self.avPlayer) {
        [self.avPlayer removeObserver:self forKeyPath:kStatusKey];
    }
    
    if (self.playerItem) {
        [self.playerItem removeObserver:self forKeyPath:kStatusKey];
        [self.playerItem removeObserver:self forKeyPath:kLoadedTimeRangesKey];
    }
    
    LogDebug(@"playerViewController deallocated");
}

- (void)dispose
{
    [self.view removeFromSuperview];
    [self.avPlayer dispose];
    self.avPlayer = nil;
    self.imageDownloader = nil;
    
    self.disposed = YES;
}

#pragma mark - load asset, set up AVplayer and avPlayer view
- (void)handleVideoInitError
{
    [self stopLoadingIndicator];
    [self.playerView handleVideoInitFailure];
    
    //Show main image if video fails to load
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    imageView.image = [_imageDownloader getCachedImageForURL:[NSURL URLWithString:[self.nativeAssets objectForKey:kNativeMainImageKey]]];
    
    [[self.view subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.view addSubview:imageView];
}

- (void)loadAndPlayVideo
{
    self.startedLoading = YES;
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:self.mediaURL options:nil];
    
    if (asset == nil) {
        LogError(@"failed to initialize video asset for URL %@", self.mediaURL);
        [self handleVideoInitError];
        
        return;
    }
    
    NSArray *requestedKeys = @[kTracksKey, kPlayableKey];
    [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.disposed) {
                [self prepareToPlayAsset:asset withKeys:requestedKeys];
            }
        });
    }];
}

- (void)setVideoAspectRatioWithAsset:(AVURLAsset *)asset
{
    if (asset && [asset tracksWithMediaType:AVMediaTypeVideo].count > 0) {
        AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo][0];
        CGSize naturalSize = CGSizeApplyAffineTransform(videoTrack.naturalSize, videoTrack.preferredTransform);
        naturalSize = CGSizeMake(fabs(naturalSize.width), fabs(naturalSize.height));
        
        // make sure the natural size is at least 1pt (not 0) check
        if (naturalSize.height > 0 && naturalSize.width > 0) {
            _videoAspectRatio = naturalSize.width / naturalSize.height;
        }
    }
}

- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    NSError *error = nil;
    
    if (!asset.playable) {
        LogError(@"asset is not playable");
        [self handleVideoInitError];
        
        return;
    }
    
    AVKeyValueStatus status = [asset statusOfValueForKey:kTracksKey error:&error];
    if (status == AVKeyValueStatusFailed) {
        LogError(@"AVKeyValueStatusFailed");
        [self handleVideoInitError];
        
        return;
    } else if (status == AVKeyValueStatusLoaded) {
        [self setVideoAspectRatioWithAsset:asset];
        
        self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
        self.avPlayer = [[PMAVPlayer alloc] initWithDelegate:self playerItem:self.playerItem];
        self.avPlayer.muted = YES;
        
        [self.playerView setAvPlayer:self.avPlayer];
    }
}

#pragma mark - video ready to play
- (void)initOnVideoReady
{
    [self startPlayer];
}

- (void)createView
{
    [self.playerView createPlayerView];
    //Expand button creation delayed to after its images have been downloaded
    
}

- (void)addPlayButtonOverlay
{
    UIView *playButtonView = [[UIView alloc] initWithFrame:self.view.bounds];
    playButtonView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    
    UIImageView *playButtonImage = [[UIImageView alloc] initWithImage:[_imageDownloader getCachedImageForURL:[NSURL URLWithString:self.sdkConfigs.playButtonImageURL]]];

    [self layoutPlayButtonOverlay];
    self.playButtonIcon = playButtonImage;
    [playButtonView addSubview:self.playButtonIcon];
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playButtonViewTapped)];
    [playButtonView addGestureRecognizer:tapGestureRecognizer];
    
    _playButtonView = playButtonView;
    
    [self.view addSubview:playButtonView];
    [self.view bringSubviewToFront:playButtonView];
    
    //get expand button to front of play button
    [self.view bringSubviewToFront:self.expandButton];
}

- (void)removePlayButtonOverlay
{
    [[self.playButtonView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.playButtonView removeFromSuperview];
}

- (void)layoutPlayButtonOverlay
{
    self.playButtonView.frame = self.view.bounds;
    CGFloat dimension = (self.view.frame.size.height>self.view.frame.size.width) ? self.view.frame.size.width : self.view.frame.size.height;
    CGFloat buttonSide = 0.3 * dimension;
    
    CGRect frame = CGRectMake(self.playButtonView.center.x - (buttonSide/2), self.playButtonView.center.y - (buttonSide/2), buttonSide, buttonSide);
    self.playButtonIcon.frame = frame;
}

- (void)createExpandButton
{
    if (!self.expandButton) {
        self.expandButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.expandButton setImage:[_imageDownloader getCachedImageForURL:[NSURL URLWithString:self.sdkConfigs.expandButtonImageURL]] forState:UIControlStateNormal];
        
        [self.expandButton addTarget:self action:@selector(expandButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        
        self.expandButton.pm_TouchAreaInsets = UIEdgeInsetsMake(kMuteIconInlineModeTouchAreaInsets, kMuteIconInlineModeTouchAreaInsets, kMuteIconInlineModeTouchAreaInsets,kMuteIconInlineModeTouchAreaInsets);
        [self.expandButton sizeToFit];
        
        [self layoutExpandButton];
        [self.view addSubview:self.expandButton];
    }
}

- (void)layoutExpandButton
{
    CGFloat dimension = (self.view.frame.size.height>self.view.frame.size.width) ? self.view.frame.size.width : self.view.frame.size.height;
    CGFloat imageSide = 0.2 * dimension;
    CGFloat viewHeight = self.view.frame.size.height;
    CGFloat viewWidth = self.view.frame.size.width;
    
    CGRect buttonFrame = CGRectMake(viewWidth-imageSide-kMuteIconInlineModeBottomAndRightMargin, viewHeight-imageSide-kMuteIconInlineModeBottomAndRightMargin, imageSide, imageSide);
    self.expandButton.frame = buttonFrame;
}

#pragma mark - displayAgent

- (AdDestinationDisplayAgent *)displayAgent
{
    if (!_displayAgent) {
        _displayAgent = [[InstanceProvider sharedProvider] buildAdDestinationDisplayAgentWithDelegate:self];
    }
    return _displayAgent;
}

#pragma mark - setter for player related objects

- (void)setPlayerItem:(AVPlayerItem *)playerItem
{
    if (_playerItem) {
        [_playerItem removeObserver:self forKeyPath:kStatusKey];
        [_playerItem removeObserver:self forKeyPath:kLoadedTimeRangesKey];
    }
    _playerItem = playerItem;
    if (!playerItem) {
        return;
    }
    
    [_playerItem addObserver:self forKeyPath:kStatusKey options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [_playerItem addObserver:self
                  forKeyPath:kLoadedTimeRangesKey
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:AudioControllerBufferingObservationContext];
}

- (void)setAvPlayer:(PMAVPlayer *)avPlayer
{
    if (_avPlayer) {
        [_avPlayer removeObserver:self forKeyPath:kStatusKey];
    }
    _avPlayer = avPlayer;
    if (_avPlayer) {
        NSKeyValueObservingOptions options = (NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew);
        [_avPlayer addObserver:self forKeyPath:kStatusKey options:options context:nil];
    }
}

- (void)setMuted:(BOOL)muted
{
    self.avPlayer.muted = muted;
}

#pragma mark - displayMode

- (ANPlayerDisplayMode)displayMode
{
    return self.playerView.displayMode;
}

- (void)setDisplayMode:(ANPlayerDisplayMode)displayMode
{
    self.playerView.displayMode = displayMode;
}

#pragma mark - activityIndicator
- (UIActivityIndicatorView *)loadingIndicator
{
    if (!_loadingIndicator) {
        _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _loadingIndicator.hidesWhenStopped = YES;
        _loadingIndicator.color = [UIColor whiteColor];
        [self.view addSubview:_loadingIndicator];
    }
    return _loadingIndicator;
}

- (void)startLoadingIndicator
{
    [self.loadingIndicator.superview bringSubviewToFront:_loadingIndicator];
    [self.loadingIndicator startAnimating];
}

- (void)stopLoadingIndicator
{
    if (_loadingIndicator && _loadingIndicator.isAnimating) {
        [_loadingIndicator stopAnimating];
    }
}

- (void)removeLoadingIndicator
{
    if (_loadingIndicator) {
        [_loadingIndicator stopAnimating];
        [_loadingIndicator removeFromSuperview];
        _loadingIndicator = nil;
    }
}

#pragma mark - Tap actions
- (void)playButtonViewTapped
{
    if (!self.isReadyToPlay || self.finishedPlaying) {
        return;
    }
    
    [self removePlayButtonOverlay];
    [self playerViewScreenTapped:nil];
}

- (void)expandButtonTapped
{
    
    self.displayMode = ANPlayerDisplayModeFullscreen;
            
    if ([self.delegate respondsToSelector:@selector(willEnterFullscreen:)]) {
        [self.delegate willEnterFullscreen:self];
    }
}

# pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self.avPlayer) {
        if (self.avPlayer.status == AVPlayerItemStatusFailed) {
            if (self.isReadyToPlay) {
            } else {
            }
            LogError(@"avPlayer status failed");
        }
    } else if (object == self.playerItem) {
        if (context == AudioControllerBufferingObservationContext) {
            NSArray *timeRangeArray = [self.playerItem loadedTimeRanges];
            if (timeRangeArray && timeRangeArray.count > 0) {
                CMTimeRange aTimeRange = [[timeRangeArray objectAtIndex:0] CMTimeRangeValue];
                double startTime = CMTimeGetSeconds(aTimeRange.start);
                double loadedDuration = CMTimeGetSeconds(aTimeRange.duration);
                double videoDuration = CMTimeGetSeconds(self.playerItem.duration);
                if ((startTime + loadedDuration + kVideoFinishedBufferingAllowedError) >= videoDuration && !self.downloadFinishedEventFired) {
                    self.downloadFinishedEventFired = YES;
                }
            }
        }
        if ([keyPath isEqualToString:kStatusKey]) {
            switch (self.playerItem.status) {
                case AVPlayerItemStatusReadyToPlay:
                    if (!self.alreadyInitialized) {
                        self.alreadyInitialized = YES;
                        [self initOnVideoReady];
                    }
                    break;
                case AVPlayerItemStatusFailed:
                {
                    LogError(@"avPlayerItem status failed");
                    break;
                }
                default:
                    break;
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - player controls
- (void)startPlayer
{
    self.isReadyToPlay = YES;
    
    [self stopLoadingIndicator];
    self.avPlayer.muted = NO;
    self.userPaused = YES;
    [self pause];
    
    if (self.imagesDownloaded) {
        [self createExpandButton];
    } else{
        [self.sdkConfigs populateWithDefaultVideoAssets];
        [self createExpandButton];
    }
}

//Play is called only for autoplay events
- (void)play
{
    self.paused = NO;
    self.playing = YES;
    self.userPaused = NO;
    self.avPlayer.muted = YES;
    [self.avPlayer play];
    //To remove play button icon image
    [self removePlayButtonOverlay];

    self.firstTimePlay = NO;
    
    if ([self.delegate respondsToSelector:@selector(playerPlaybackDidStart:)]) {
        [self.delegate playerPlaybackDidStart:self];
    }
}

- (void)pause
{
    self.paused = YES;
    self.playing = NO;
    [self.avPlayer pause];
    [self addPlayButtonOverlay];
}

- (void)resume
{
    [self removePlayButtonOverlay];
    self.paused = NO;
    self.playing = YES;
    [self.avPlayer play];
    
    if ([self.delegate respondsToSelector:@selector(playerPlaybackDidStart:)]) {
        [self.delegate playerPlaybackDidStart:self];
    }
}

- (void)seekToTime:(NSTimeInterval)time
{
    [self.avPlayer seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

#pragma mark - auto play helper method
- (BOOL)shouldStartNewPlayer
{
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (!self.startedLoading && !self.playing && !self.paused && state == UIApplicationStateActive) {
        return YES;
    }
    return NO;
}

- (BOOL)shouldAutoPlayPlayer
{
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (self.isReadyToPlay && self.shouldAutoPlay && !self.playing && self.firstTimePlay && state == UIApplicationStateActive) {
        return YES;
    }
    return NO;
    
}

- (BOOL)shouldResumePlayer
{
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (self.startedLoading && self.paused == YES && !self.userPaused && self.displayMode == ANPlayerDisplayModeInline && state == UIApplicationStateActive) {
        
        //Check if autoplay is disabled
        if (!self.shouldAutoPlay && self.playing) {
            self.userPaused = YES;
            [self addPlayButtonOverlay];
            return NO;
        }
        //Mute before resuming
        self.avPlayer.muted = YES;
        return YES;
    }
    return NO;
}

- (BOOL)shouldPausePlayer
{
    if (self.playing && self.displayMode == ANPlayerDisplayModeInline) {
        return YES;
    }
    return NO;
}

#pragma mark - enter fullscreen or exit fullscreen

- (void)willEnterFullscreen
{
    self.displayMode = ANPlayerDisplayModeFullscreen;
    //Video should be unmuted when user goes to full screen
    self.muted =  NO;
}

- (void)willExitFullscreen
{
    self.displayMode = ANPlayerDisplayModeInline;
    self.userPaused = YES;
    [self pause];
}

#pragma mark - PMAVPlayerDelegate

- (void)avPlayer:(PMAVPlayer *)player playbackTimeDidProgress:(NSTimeInterval)currentPlaybackTime
{
    // stop the loading indicator if it exists and is animating.
    [self stopLoadingIndicator];
    
    // When the KVO sends AVPlayerItemStatusReadyToPlay, there could still be a delay for the video really starts playing.
    // If we create the mute button and progress bar immediately after AVPlayerItemStatusReadyToPlay signal, we might
    // end up with showing them before the video is visible. To prevent that, we create mute button and progress bar here.
    // There will be 0.1s delay after the video starts playing, but it's a much better user experience.
    
    if (!self.alreadyCreatedPlayerView) {
        [self createView];
        self.alreadyCreatedPlayerView = YES;
    }
    
    [self.playerView playbackTimeDidProgress];
    
    if ([self.delegate respondsToSelector:@selector(playerDidProgressToTime:withTotalTime:)]) {
        [self.delegate playerDidProgressToTime:currentPlaybackTime withTotalTime:self.avPlayer.currentItemDuration];
    }
}

- (void)avPlayer:(PMAVPlayer *)player didError:(NSError *)error withMessage:(NSString *)message
{
    [self.avPlayer pause];
}

- (void)avPlayerDidFinishPlayback:(PMAVPlayer *)player
{
    self.finishedPlaying = YES;
    [self removeLoadingIndicator];
    [self.avPlayer pause];
    // update view
    [self.playerView playbackDidFinish];
    
    if ([self.delegate respondsToSelector:@selector(playerPlaybackDidFinish:)]) {
        [self.delegate playerPlaybackDidFinish:self];
    }
}

- (void)avPlayerDidRecoverFromStall:(PMAVPlayer *)player
{
    if (self.displayMode == ANPlayerDisplayModeInline) {
        [self removeLoadingIndicator];
    } else {
        if ([self.delegate respondsToSelector:@selector(playerViewController:didRecoverFromStall:)]) {
            [self.delegate playerViewController:self didRecoverFromStall:player];
        }
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resume) object:nil];
}

- (void)avPlayerDidStall:(PMAVPlayer *)player
{
    if (self.displayMode == ANPlayerDisplayModeInline) {
        [self startLoadingIndicator];
    } else {
        if ([self.delegate respondsToSelector:@selector(playerViewController:didStall:)]) {
            [self.delegate playerViewController:self didStall:self.avPlayer];
        }
    }
    
    // Try to resume the video play after 3 seconds. The perform selector request is cancelled when
    // didRecoverFromStall signal is received. This way, we won't queue up the requests.
    [self performSelector:@selector(resume) withObject:nil afterDelay:kDelayPlayInSeconds];
}

#pragma mark - PMPlayerViewDelegate

- (void)playerViewScreenTapped:(PMPlayerView *)view
{
    if (!self.isReadyToPlay) {
        return;
    }
    
    if (self.avPlayer.muted) {
        self.avPlayer.muted = NO;
        return;
    }
    
    //Click should be recognised only on an unmuted, playing video
    if (self.playing && !self.playerViewClickTracked) {
        self.playerViewClickTracked = YES;
        if ([self.delegate respondsToSelector:@selector(playerViewDidTrackClick:)]) {
            [self.delegate playerViewDidTrackClick:view];
        }
    }
    
    if (self.playing) {
        self.userPaused = YES;
        [self pause];
    } else {
        self.userPaused = NO;
        [self resume];
    }
    if ([self.delegate respondsToSelector:@selector(playerViewScreenTapped:)]) {
        [self.delegate playerViewScreenTapped:view];
    }
}

#pragma mark - PMImageDownloaderDelegate
- (void)imagesDownloadedAndCached
{
    self.imagesDownloaded = YES;
}
- (void)imagesDownloadFailed
{
    [self.sdkConfigs populateWithDefaultVideoAssets];
    self.imagesDownloaded = YES;
}
#pragma mark - Application state monitoring

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    if (self.avPlayer && self.avPlayer.rate > 0) {
        [self pause];
        [self removePlayButtonOverlay];
    }
}

- (void)applicationDidEnterForeground:(NSNotification *)notification
{
    if (self.avPlayer && self.isReadyToPlay && !self.finishedPlaying && !self.userPaused) {
        [self resume];
    }
}

#pragma mark - <AdDestinationDisplayAgent>

- (UIViewController *)viewControllerToPresentModalView
{
    return [self.delegate viewControllerForPresentingModalView];
}

- (void)displayAgentWillPresentModal
{
    [self pause];
}

- (void)displayAgentWillLeaveApplication
{
    [self pause];
}

- (void)displayAgentDidDismissModal
{
    [self resume];
}
@end
