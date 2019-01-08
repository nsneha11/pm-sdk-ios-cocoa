//
//  NativeAd.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 22/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "PMNativeAd.h"
#import "AdAdapterDelegate.h"
#import "AdAdapter.h"
#import "AdDelegate.h"
#import "UIView+NativeAd.h"
#import "Constants.h"
#import "AdAssets.h"
#import "Logging.h"
#import "PMAdRendering.h"
#import "IANTimer.h"
#import "InstanceProvider.h"
#import "ViewChecker.h"
#import "NativeCache.h"
#import "ImageDownloadQueue.h"
#import "SDKConfigsSource.h"
#import "SDKConfigs.h"
#import "AdRequest.h"
#import "PMAdRequestTargeting.h"
#import "PMAdResponse.h"
#import <AVFoundation/AVFoundation.h>
#import "PMCommonAdDelegate.h"
#import "PMAdChoicesView.h"

#import "PMMediaViewRenderer.h"
#import "PMWebViewPlayerViewController.h"

static const CGFloat kAdsNativeTimerInterval = 0.25;
#define SingleNativeAdViewTag 67;
////////////////////////////////////////////////////////////////////////////////////////////////////

@interface PMNativeAd () <AdAdapterDelegate, PMCommonAdDelegate, PMAdChoicesViewDelegate>

@property (nonatomic, strong) NSDate *creationDate;

@property (nonatomic, strong) NSMutableSet *clickTrackers;
@property (nonatomic, strong) NSMutableSet *impressionTrackers;
@property (nonatomic, strong) NSMutableSet *viewabilityTrackers;

@property (nonatomic, readonly, strong) id<AdAdapter> adAdapter;
@property (nonatomic, assign) BOOL hasTrackedImpression;
@property (nonatomic, assign) BOOL hasTrackedViewability;
@property (nonatomic, assign) BOOL hasTrackedClick;
@property (nonatomic, assign) BOOL hasTrackedVideoClick;

@property (nonatomic, copy) NSString *adIdentifier;
@property (nonatomic, strong) UIView *associatedView;
@property (nonatomic, strong) IANTimer *associatedViewVisibilityImpressionTimer;
@property (nonatomic, strong) IANTimer *associatedViewVisibilityViewabilityTimer;
@property (nonatomic, assign) NSTimeInterval firstVisibilityTimestamp;
@property (nonatomic, assign) BOOL visible;

@property (nonatomic, strong) NSMutableSet *managedImageViews;
@property (nonatomic, strong) ImageDownloadQueue *imageDownloadQueue;

//for Single Native Ad
@property (nonatomic, weak) UIViewController *viewController;

@property (nonatomic, assign) BOOL pubWillHandleClick;

//adchoices view
@property (nonatomic, strong) PMAdChoicesView *pmAdChoicesView;

//For Media View
@property (nonatomic, strong) PMMediaViewRenderer *mediaViewRenderer;
//Only for 3p SDK networks
@property (nonatomic, strong) IANTimer *mediaViewVisibilityTimer;
@property (nonatomic, strong) UIView *mediaView;
@property (nonatomic, assign) BOOL isMediaViewVisible;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation PMNativeAd

- (instancetype)initWithAdAdapter:(id<AdAdapter>)adAdapter
{
    static int sequenceNumber = 0;
    
    self = [super init];
    if (self) {
        _adAdapter = adAdapter;
        //Remove view controller object that was present in assets to prevent retain cycle
        if ([self.adAdapter.nativeAssets objectForKey:@"viewController"] != nil) {
            [self.adAdapter.nativeAssets removeObjectForKey:@"viewController"];
        }
        
        if ([_adAdapter respondsToSelector:@selector(setDelegate:)]) {
            [_adAdapter setDelegate:self];
        }

        if ([[_adAdapter.nativeAssets objectForKey:kNativeAdChoicesKey] isKindOfClass:[PMAdChoicesView class]]) {
            self.pmAdChoicesView = [self.adAdapter.nativeAssets objectForKey:kNativeAdChoicesKey];
            self.pmAdChoicesView.delegate = self;
        }

        _adIdentifier = [[NSString stringWithFormat:@"%d", sequenceNumber++] copy];
        _firstVisibilityTimestamp = -1;
        _impressionTrackers = [[NSMutableSet alloc] init];
        _viewabilityTrackers = [[NSMutableSet alloc] init];
        _clickTrackers = [[NSMutableSet alloc] init];
        _imageDownloadQueue = [[ImageDownloadQueue alloc] init];
        _managedImageViews = [[NSMutableSet alloc] init];
        _creationDate = [NSDate date];

        //Only needed for media view visibility tracking
        if ([self willHandleMediaViewVisibility]) {
            NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
            [notificationCenter addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
            [notificationCenter addObserver:self selector:@selector(applicationDidEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        }
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_associatedView pm_removeNativeAd];
    [_associatedViewVisibilityImpressionTimer invalidate];
    [_associatedViewVisibilityViewabilityTimer invalidate];
    [_mediaViewVisibilityTimer invalidate];
    [self removeAssociatedObjectsFromManagedImageViews];
    if (_mediaViewRenderer != nil) {
        [_mediaViewRenderer dispose];
    }
}

- (void)removeAssociatedObjectsFromManagedImageViews
{
    for (UIImageView *imageView in _managedImageViews) {
        if ([imageView pm_nativeAd] == self) {
            [imageView pm_removeNativeAd];
        }
    }
}

#pragma mark - Public

- (NSNumber *)starRating
{
    NSNumber *starRatingNum = [self.nativeAssets objectForKey:kNativeStarRatingKey];
    
    if (![starRatingNum isKindOfClass:[NSNumber class]] || starRatingNum.floatValue < kMinStarRatingValue || starRatingNum.floatValue > kMaxStarRatingValue) {
        starRatingNum = nil;
    }
    
    return starRatingNum;
}

- (float)biddingEcpm
{
    if (![self.nativeAssets objectForKey:kNativeEcpmKey]) {
        return -1.0;
    }

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setMaximumFractionDigits:2];
    [formatter setMinimumFractionDigits:2];
    
    NSString *ecpmAsString = [formatter stringFromNumber:[self.nativeAssets objectForKey:kNativeEcpmKey]];

    NSNumber *ecpm = [formatter numberFromString:ecpmAsString];
    
    if (self.biddingInterval == 0.0) {
        return [ecpm floatValue];
    }
    
    //rounding off ecpm to the closest bidding interval
    int biddingEcpm = [ecpm floatValue]*100;
    int bidInterval = self.biddingInterval *100;
    
    int remainder = biddingEcpm % bidInterval;
    
    float div = (float)remainder/bidInterval;
    
    if (div >= 0.5) {
        biddingEcpm = biddingEcpm + (bidInterval - remainder);
    } else {
        biddingEcpm = biddingEcpm - remainder;
    }
    
    float res = (float)biddingEcpm/100.0;
    
    return res;
}

- (NSDictionary *)nativeAssets
{
    return self.adAdapter.nativeAssets;
}

- (NSURL *)defaultClickThroughURL
{
    return self.adAdapter.defaultClickThroughURL;
}

- (BOOL)isBackupClassRequired
{
    return self.adAdapter.isBackupClassRequired;
}

- (void)trackViewability
{
    if (self.hasTrackedViewability) {
        LogDebug(@"Viewable impression already tracked");
        return;
    }
    
    LogDebug(@"Tracking a viewable impression for %@.", self.adIdentifier);
    LogDebug(@"Number of viewable impression trackers : %lu",[self.viewabilityTrackers count]);
    self.hasTrackedViewability = YES;
    for (NSString *URLString in self.viewabilityTrackers) {
        NSURL *URL = [NSURL URLWithString:URLString];
        if (URL) {
            LogDebug(@"Firing viewable impression url %@ for %@",[URL absoluteString],self.adIdentifier);
            [self trackMetricForURL:URL];
        }
    }
}

- (void)trackImpression
{
    if (self.hasTrackedImpression) {
        LogDebug(@"Impression already tracked.");
        return;
    }

    LogDebug(@"Tracking an impression for %@.", self.adIdentifier);
    LogDebug(@"Number of impression trackers : %lu",[self.impressionTrackers count]);
    self.hasTrackedImpression = YES;

    for (NSString *URLString in self.impressionTrackers) {
        NSURL *URL = [NSURL URLWithString:URLString];
        if (URL) {
            LogDebug(@"Firing impression url %@ for %@",[URL absoluteString],self.adIdentifier);
            [self trackMetricForURL:URL];
        }
    }
    
    if ([self.adAdapter respondsToSelector:@selector(trackImpression)] && ![self isThirdPartyHandlingImpressions]) {
        [self.adAdapter trackImpression];
    }
    
    if ([self.internalDelegate respondsToSelector:@selector(anNativeAdDidRecordImpression)]) {
        [self.internalDelegate anNativeAdDidRecordImpression];
    }
}

- (void)trackClick
{
    if (self.hasTrackedClick) {
        LogDebug(@"Click already tracked.");
    } else {
    
        self.hasTrackedClick = YES;
    
        LogDebug(@"Tracking a click for %@.", self.adIdentifier);
        LogDebug(@"Number of click trackers : %lu",[self.clickTrackers count]);
        for (NSString *URLString in self.clickTrackers) {
            NSURL *URL = [NSURL URLWithString:URLString];
            if (URL) {
                LogDebug(@"Firing click url %@ for %@",[URL absoluteString],self.adIdentifier);
                [self trackMetricForURL:URL];
            }
        }
    
        if ([self.adAdapter respondsToSelector:@selector(trackClick)] && ![self isThirdPartyHandlingClicks]) {
            [self.adAdapter trackClick];
        }
    }
    
    if ([self.internalDelegate respondsToSelector:@selector(anNativeAdDidClick:)]) {
        self.pubWillHandleClick = [self.internalDelegate anNativeAdDidClick:self];
    }
    
    if ([self.adAdapter respondsToSelector:@selector(canOverrideClick)]) {
        if (![self.adAdapter canOverrideClick]) {
            self.pubWillHandleClick = NO;
        }
    }
}

- (void)trackMetricForURL:(NSURL *)URL
{
    NSMutableURLRequest *request = [[InstanceProvider sharedProvider] buildConfiguredURLRequestWithURL:URL];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    [NSURLConnection connectionWithRequest:request delegate:nil];
}

- (void)displayContentWithCompletion:(void (^)(BOOL, NSError *))completionBlock
{
    [self displayContentForURL:self.adAdapter.defaultClickThroughURL completion:completionBlock];
}

- (void)displayContentForURL:(NSURL *)URL completion:(void (^)(BOOL, NSError *))completionBlock
{
    [self showContentForURL:URL fromViewController:[self.internalDelegate viewControllerToPresentAdModalView] withCompletion:completionBlock];
}

- (void)prepareForDisplayInView:(UIView *)view
{
    // If the view already had a native ad, we need to detach the view from that ad.
    PMNativeAd *oldNativeAd = [view pm_nativeAd];
    [oldNativeAd detachFromAssociatedView];
    [view pm_setNativeAd:self];
    
    self.associatedView = view;
    
    // Add a tap recognizer on top of the view if the ad network isn't handling clicks on its own.
    if (!([_adAdapter respondsToSelector:@selector(enableThirdPartyClickTracking)] && [_adAdapter enableThirdPartyClickTracking])) {
        UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(adViewTapped)];
        [self.associatedView addGestureRecognizer:recognizer];
    }
    
    //Moving this out of the if check as for TableView and CollectionView the view protocol check
    //happens earlier. For Single Native Ad call, the view may or may not implement the `PMAdRendering` protocol.
    [self willAttachToView:view];
    if ([view conformsToProtocol:@protocol(PMAdRendering)]) {
        [(id<PMAdRendering>)view layoutAdAssets:self];
    }
    
    if (![self isThirdPartyHandlingImpressions]) {
        [self.associatedViewVisibilityImpressionTimer invalidate];
        self.associatedViewVisibilityImpressionTimer = [IANTimer timerWithTimeInterval:kAdsNativeTimerInterval target:self selector:@selector(impressionTick:) repeats:YES];
        self.associatedViewVisibilityImpressionTimer.runLoopMode = NSRunLoopCommonModes;
        
        [self.associatedViewVisibilityImpressionTimer scheduleNow];
        
    }
    
    //always track viewability irrespective of direct or third party ad
    [self.associatedViewVisibilityViewabilityTimer invalidate];
    self.associatedViewVisibilityViewabilityTimer = [IANTimer timerWithTimeInterval:kAdsNativeTimerInterval target:self selector:@selector(viewabilityTick:) repeats:YES];
    self.associatedViewVisibilityViewabilityTimer.runLoopMode = NSRunLoopCommonModes;
    [self.associatedViewVisibilityViewabilityTimer scheduleNow];

    if ([self willHandleMediaViewVisibility]) {
        self.mediaViewVisibilityTimer = [IANTimer timerWithTimeInterval:kAdsNativeTimerInterval target:self selector:@selector(mediaViewTick:) repeats:YES];
        self.mediaViewVisibilityTimer.runLoopMode = NSRunLoopCommonModes;
        
        [self.mediaViewVisibilityTimer scheduleNow];
    }
}

- (void)addImpressionTrackers:(NSArray *)trackers
{
    [self.impressionTrackers addObjectsFromArray:trackers];
}

- (void)viewabilityTick:(NSTimer *)timer
{
    if ([self hasTrackedViewability]) {
        [self.associatedViewVisibilityViewabilityTimer invalidate];
        self.associatedViewVisibilityViewabilityTimer = nil;
        return;
    }
    
    [self setVisible:ViewIsVisible(self.associatedView) && ViewIntersectsParentWindowWithPercent(self.associatedView, (CGFloat)0.5)];
}

- (void)impressionTick:(NSTimer *)timer {
    if ([self hasTrackedImpression]) {
        [self.associatedViewVisibilityImpressionTimer invalidate];
        self.associatedViewVisibilityImpressionTimer = nil;
        return;
    }

    if (ViewIsVisible(self.associatedView))
        [self trackImpression];
}

- (void)mediaViewTick:(NSTimer *)timer
{
    if (self.mediaView == nil)
        return;
    
    if (ViewIsVisible(self.mediaView) && ViewIntersectsParentWindowWithPercent(self.mediaView, [self normalizedMediaViewPercentForVisibility])) {
        
        if (self.isMediaViewVisible) {
            return;
        }
        self.isMediaViewVisible = YES;
        
        if ([self.adAdapter respondsToSelector:@selector(mediaDidComeIntoView)]) {
            [self.adAdapter mediaDidComeIntoView];
        }
        
    } else {
        if (!self.isMediaViewVisible) {
            return;
        }
        self.isMediaViewVisible = NO;
        if ([self.adAdapter respondsToSelector:@selector(mediaDidGoOutOfView)]) {
            [self.adAdapter mediaDidGoOutOfView];
        }
    }
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    if (ViewIsVisible(self.mediaView) && ViewIntersectsParentWindowWithPercent(self.mediaView, [self normalizedMediaViewPercentForVisibility])) {
        if ([self.adAdapter respondsToSelector:@selector(mediaDidGoOutOfView)]) {
            [self.adAdapter mediaDidGoOutOfView];
        }
    }
}

- (void)applicationDidEnterForeground:(NSNotification *)notification
{
    if (ViewIsVisible(self.mediaView) && ViewIntersectsParentWindowWithPercent(self.mediaView, [self normalizedMediaViewPercentForVisibility])) {
        if ([self.adAdapter respondsToSelector:@selector(mediaDidComeIntoView)]) {
            [self.adAdapter mediaDidComeIntoView];
        }
    }
}

#pragma mark - Rendering
- (void)loadMediaIntoView:(UIView *)view
{
    //Clear video ad view
    [[view subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [view layoutIfNeeded];
    view.backgroundColor = [UIColor blackColor];
    view.userInteractionEnabled = YES;
    
    if ([_adAdapter respondsToSelector:@selector(isMediaView)] && [_adAdapter isMediaView]) {
        
        if ([[_adAdapter nativeAssets] objectForKey:kNativeMediaViewKey] != nil) {
            
            //Indicates an ANNativeVideo ad (and not from 3p adapters)
            if ([[[_adAdapter nativeAssets] objectForKey:kNativeAdTypeKey] isEqualToString:@"video"]) {
                
                if (_mediaViewRenderer == nil) {
                    _mediaViewRenderer = [[_adAdapter nativeAssets] objectForKey:kNativeMediaViewKey];
                }
                if (_mediaViewRenderer != nil) {
                    [_mediaViewRenderer layoutVideoIntoView:view withViewController:[self.internalDelegate viewControllerToPresentAdModalView]];
                }
            } else {
                UIView *mediaView = [[_adAdapter nativeAssets] objectForKey:kNativeMediaViewKey];
                mediaView.frame = view.bounds;
                
                [view addSubview:mediaView];
                [view bringSubviewToFront:mediaView];
                mediaView.contentMode = view.contentMode;
                
                if ([self willHandleMediaViewVisibility]) {
                    self.mediaView = mediaView;
                }
            }
            return;
        }
    }

    UIImageView *imageView = [[UIImageView alloc] initWithFrame:view.bounds];
    imageView.contentMode = view.contentMode;
    
    [self loadImageIntoImageView:imageView];
    [view addSubview:imageView];
    [view bringSubviewToFront:imageView];
    
}

- (void)loadAdChoicesIconIntoView:(UIView *)view
{
    if (![self.nativeAssets objectForKey:kNativeAdChoicesKey] || ![[self.nativeAssets objectForKey:kNativeAdChoicesKey] isKindOfClass:[UIView class]]) {
        return;
    }
    view.userInteractionEnabled = YES;
    
    [[view subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    UIView *adChoicesView = [self.nativeAssets objectForKey: kNativeAdChoicesKey];
    [view addSubview:adChoicesView];
    adChoicesView.frame = view.bounds;

    if ([view superview]) {
        [[view superview] bringSubviewToFront:view];
    }
}

- (void)loadIconIntoImageView:(UIImageView *)imageView
{
    [[imageView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];

    if ([[self.nativeAssets objectForKey:kNativeIconImageKey] isKindOfClass:[UIView class]]) {
        UIView *iconImageView = [self.nativeAssets objectForKey:kNativeIconImageKey];
        iconImageView.frame = imageView.bounds;
        [imageView addSubview:iconImageView];
        return;
    } else if ([[self.nativeAssets objectForKey:kNativeIconImageKey] isKindOfClass:[UIImageView class]]) {
        UIImageView *imgView = [self.nativeAssets objectForKey:kNativeIconImageKey];
        imgView.frame = imageView.bounds;
        [imageView addSubview:imgView];
    }else if ([[self.nativeAssets objectForKey:kNativeIconImageKey] isKindOfClass:[UIImage class]]) {
        imageView.image = [self.nativeAssets objectForKey:kNativeIconImageKey];
        return;
    } else {
        NSURL *imageURL = [NSURL URLWithString:[self.nativeAssets objectForKey:kNativeIconImageKey]];
        [self loadImageForURL:imageURL intoImageView:imageView];
    }
}

- (void)loadImageIntoImageView:(UIImageView *)imageView
{
    if ([[self.nativeAssets objectForKey:kNativeMainImageKey] isKindOfClass:[UIImage class]]) {
        imageView.image = [self.nativeAssets objectForKey:kNativeMainImageKey];
        return;
    }
    NSURL *imageURL = [NSURL URLWithString:[self.nativeAssets objectForKey:kNativeMainImageKey]];
    [self loadImageForURL:imageURL intoImageView:imageView];
}

- (void)loadSponsoredTagIntoLabel:(UILabel *)label
{
    NSString *sponsoredByText = [self.nativeAssets objectForKey:kNativeSponsoredByTagKey];
    NSString *sponsoredByValue = [self.nativeAssets objectForKey:kNativeSponsoredKey];
    
    if (sponsoredByText == nil || [sponsoredByText length] == 0) {
        if (sponsoredByValue == nil || [sponsoredByValue length] == 0) {
            sponsoredByText = @"Sponsored";
        } else {
            sponsoredByText = @"Sponsored By";
        }
        
    }
    
    if (sponsoredByValue != nil)
        label.text = [sponsoredByText stringByAppendingString:[@" " stringByAppendingString: sponsoredByValue]];
    else
        label.text = sponsoredByText;
}

- (void)loadTextIntoLabel:(UILabel *)label
{
    label.text = [self.nativeAssets objectForKey:kNativeTextKey];
}

- (void)loadTitleIntoLabel:(UILabel *)label
{
    label.text = [self.nativeAssets objectForKey:kNativeTitleKey];
}

- (void)loadCallToActionTextIntoLabel:(UILabel *)label
{
    label.text = [self.nativeAssets objectForKey:kNativeCTATextKey];
}

- (void)loadCallToActionTextIntoButton:(UIButton *)button
{
    [button setTitle:[self.nativeAssets objectForKey:kNativeCTATextKey] forState:UIControlStateNormal];
    
    //disabling click on button so that `PMTableViewAdPlacer`s `didSelectRowAtIndexPath` message gets
    //called
    button.userInteractionEnabled = NO;
}

- (void)loadImageForURL:(NSURL *)imageURL intoImageView:(UIImageView *)imageView
{
    imageView.image = nil;
    [imageView pm_setNativeAd:self];
    [self.managedImageViews addObject:imageView];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        __block BOOL imageViewWasRecycled = NO;
        
        // Try to prevent unnecessary work if the imageview has already been recycled.
        // Note that this doesn't prevent 100% of the cases as the imageview can still be recycled after this passes.
        // We have an additional 100% accurate check in safeMainQueueSetImage to ensure that we don't overwrite.
        dispatch_sync(dispatch_get_main_queue(), ^{
            imageViewWasRecycled = ![self isCurrentAdForImageView:imageView];
        });
        
        if (imageViewWasRecycled) {
            LogDebug(@"Cell was recycled. Don't bother rendering the image.");
            return;
        }
        
        NSData *cachedImageData = [[NativeCache sharedCache] retrieveDataForKey:imageURL.absoluteString];
        UIImage *image = [UIImage imageWithData:cachedImageData];
        
        if (image) {
            // By default, the image data isn't decompressed until set on a UIImageView, on the main thread. This
            // can result in poor scrolling performance. To fix this, we force decompression in the background before
            // assignment to a UIImageView.
            UIGraphicsBeginImageContext(CGSizeMake(1, 1));
            [image drawAtPoint:CGPointZero];
            UIGraphicsEndImageContext();
            
            [self safeMainQueueSetImage:image intoImageView:imageView];
        } else if (imageURL) {
            LogDebug(@"Cache miss on %@. Re-downloading...", imageURL);
            
            __weak PMNativeAd *weakSelf = self;
            [self.imageDownloadQueue addDownloadImageURLs:@[imageURL]
                                          completionBlock:^(NSArray *errors) {
                                              PMNativeAd *strongSelf = weakSelf;
                                              if (strongSelf) {
                                                  if (errors.count == 0) {
                                                      UIImage *image = [UIImage imageWithData:[[NativeCache sharedCache] retrieveDataForKey:imageURL.absoluteString]];
                                                      
                                                      [strongSelf safeMainQueueSetImage:image intoImageView:imageView];
                                                  } else {
                                                      LogDebug(@"Failed to download %@ on cache miss. Giving up for now.", imageURL);
                                                  }
                                              } else {
                                                  LogInfo(@"NativeAd deallocated before loadImageForURL:intoImageView: download completion block was called");
                                              }
                                          }];
        }
    });
}

#pragma mark - Internal
- (BOOL)willHandleMediaViewVisibility
{
    if ([self.adAdapter respondsToSelector:@selector(isMediaView)] && [self.adAdapter isMediaView] && [self.adAdapter respondsToSelector:@selector(handleMediaViewVisibility)] && [self.adAdapter handleMediaViewVisibility]) {
        return YES;
    }
    return NO;
}

- (float)normalizedMediaViewPercentForVisibility
{
    if ([self.adAdapter respondsToSelector:@selector(mediaViewVisibilityPercent)]) {
        return self.adAdapter.mediaViewVisibilityPercent/100.0;
    }
    return kDefaultPercentVisibleForAutoplay/100.0;
}

- (BOOL)isCurrentAdForImageView:(UIImageView *)imageView
{
    PMNativeAd *ad = [imageView pm_nativeAd];
    return ad == self;
}

- (void)willAttachToView:(UIView *)view
{
    if ([self.adAdapter respondsToSelector:@selector(willAttachToView:)]) {
        [self.adAdapter willAttachToView:view];
    }
}

- (void)detachFromAssociatedView
{
    if ([self.adAdapter respondsToSelector:@selector(didDetachFromView:)]) {
        [self.adAdapter didDetachFromView:self.associatedView];
    }
    self.associatedView = nil;
}

- (void)safeMainQueueSetImage:(UIImage *)image intoImageView:(UIImageView *)imageView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self isCurrentAdForImageView:imageView]) {
            LogDebug(@"Cell was recycled. Don't bother setting the image.");
            return;
        }
        
        if (image) {
            imageView.image = image;
        }
    });
}

- (void)setVisible:(BOOL)visible
{
    if (visible) {
        NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
        if (self.firstVisibilityTimestamp == -1) {
            self.firstVisibilityTimestamp = now;
            
        } else if (now - self.firstVisibilityTimestamp >= kDefaultSecondsForViewableImpression) {
            self.firstVisibilityTimestamp = -1;
            [self trackViewability];
        }
    } else {
        self.firstVisibilityTimestamp = -1;
    }
}

- (BOOL)isThirdPartyHandlingImpressions
{
    return [self.adAdapter respondsToSelector:@selector(enableThirdPartyImpressionTracking)] && [self.adAdapter enableThirdPartyImpressionTracking];
}

- (BOOL)isThirdPartyHandlingClicks
{
    return [self.adAdapter respondsToSelector:@selector(enableThirdPartyClickTracking)] && [self.adAdapter enableThirdPartyClickTracking];
}

- (void)showContentForURL:(NSURL *)URL fromViewController:(UIViewController *)controller withCompletion:(void (^)(BOOL, NSError *))completionBlock
{
    BOOL displayedURL = NO;
    if (![self isThirdPartyHandlingClicks]) {
        [self trackClick];
        
        if ([self.adAdapter respondsToSelector:@selector(displayContentForURL:rootViewController:completion:)] && !self.pubWillHandleClick) {
            displayedURL = YES;
            if ([self.internalDelegate respondsToSelector:@selector(anNativeAdWillLeaveApplication)]) {
                [self.internalDelegate anNativeAdWillLeaveApplication];
            }
            [self.adAdapter displayContentForURL:URL rootViewController:controller completion:completionBlock];
        }
    }
    
    if (completionBlock && !displayedURL) {
        completionBlock(YES, nil);
    }
}

#pragma mark - UITapGestureRecognizer

- (void)adViewTapped
{
    [self displayContentWithCompletion:nil];
}

#pragma mark - For Single Native Ad Requests - start
- (instancetype)initWithAdUnitId:(NSString *)adUnitID
{
    self = [super init];
    
    if (self) {
        NSAssert(adUnitID !=nil,@"AdUnitID cannot be nil");
        
        _adUnitID = adUnitID;
//        _viewController = [self.internalDelegate viewControllerToPresentAdModalView];
//        self.internalDelegate = self;
        self.biddingInterval = kDefaultBiddingInterval;
    }
    return self;
}

- (void)loadAd
{
    [self loadAdWithTargeting:nil requestType:PM_REQUEST_TYPE_NATIVE];
}

- (void)loadAdWithTargeting:(PMAdRequestTargeting *)targeting requestType:(int)requestType{
    
    NSAssert(_adUnitID !=nil,@"AdUnitID has not been set. Set it in the initWithAdUnitId: method");
    
    AdRequest *request = [AdRequest requestWithAdUnitIdentifier:_adUnitID requestType:requestType];
    request.targeting = targeting;
    request.viewController = [self.internalDelegate viewControllerToPresentAdModalView];
    request.delegate = self;
    request.nativeAd = self;

    __typeof__(self) __weak weakSelf = self;
    
    [request startWithCompletionHandler:^(AdRequest *request, PMAdResponse *response, NSError *error) {
        __typeof__(self) strongSelf = weakSelf;

        if (!strongSelf) {
            return;
        }
        if (![response.adtype isEqualToString: @"native"]) {
            [self.delegate anNativeAd:[response getPMNativeAdResponse] didFailWithError:error];
            return;
        }
        PMNativeAd *nativeAd = [response getPMNativeAdResponse];

        if (error) {
            [self.delegate anNativeAd:nativeAd didFailWithError:error];
        } else {
            [self.delegate anNativeAdDidLoad:nativeAd];
        }
    }];
}

- (UIView *)renderNativeAdWithDefaultRenderingClass:(Class)renderingClass withBounds:(CGRect)bounds{
    
    NSAssert([renderingClass conformsToProtocol:@protocol(PMAdRendering)] && [renderingClass isSubclassOfClass:[UIView class]], @"RenderingClass must be a class that implements PMAdRendering and is a view.");
    
    //check if sdk configs has not returned with the rendering class
    if (_renderingClass == nil) {
        _renderingClass = renderingClass;
    }
    
    UIView *adView;
    
    //If the isBackupClassRequired property for a given response is true, then load the backup class as the
    //rendering class as opposed to the one picked up in the sdk configs call
    if (self.isBackupClassRequired) {
        NSString *backupClass = [backupClassPrefix stringByAppendingString:
                                 NSStringFromClass(_renderingClass)];
        Class backupRenderingClass = NSClassFromString(backupClass);
        
        if ([backupRenderingClass conformsToProtocol:@protocol(PMAdRendering)] && [backupRenderingClass isSubclassOfClass:[UIView class]]) {
            _renderingClass = backupRenderingClass;
        } else {
            LogWarn(@"The Backup Rendering class fetched does not conform to PMAdRendering protocol or isn't a subclass of UIView. Loading assets into the primary rendering class instead.");
        }
    }
    
    adView = [[_renderingClass alloc] init];
    if (!CGRectIsEmpty(bounds)) {
        adView.frame = bounds;
    }
    if ([_renderingClass respondsToSelector:@selector(nibForAd)]) {
        
        if([[NSBundle mainBundle] pathForResource:[_renderingClass nibForAd] ofType:@"nib"] != nil)
        {
            //file found
            UIView *subView = [[[NSBundle mainBundle] loadNibNamed:[_renderingClass nibForAd] owner:adView options:nil] lastObject];
            if (!CGRectIsEmpty(bounds)) {
                subView.frame = bounds;
            }
            [adView addSubview:subView];
            
        } else {
            LogError(@"Nib named %@ not found. Please check your integration.",[_renderingClass nibForAd]);
            return nil;
        }
    }
    
    adView.clipsToBounds = YES;
    
    [self prepareForDisplayInView:adView];
    
    return adView;
    
}

- (void)registerNativeAdForView:(UIView *)adView {
    
    NSAssert(adView !=nil, @"Cannot pass nil ad view");
    
    adView.clipsToBounds = YES;
    
    [self prepareForDisplayInView:adView];
    
}

#pragma mark - <PMCommonAdDelegate>
- (SDKConfigs *)getSDKConfigs
{
    return [self.internalDelegate getSDKConfigs];
}

#pragma mark - For Single Native Ad Requests - end

#pragma mark - AdAdapterDelegate

- (UIViewController *)viewControllerToPresentModalView
{
    return [self.internalDelegate viewControllerToPresentAdModalView];
}

- (void)nativeAdWillLogImpression:(id<AdAdapter>)adAdapter
{
    [self trackImpression];
}

- (void)nativeAdDidClick:(id<AdAdapter>)adAdapter
{
    [self trackClick];
}

- (void)nativeAdWillLeaveApplication:(id<AdAdapter>)adAdapter
{
    if ([self.internalDelegate respondsToSelector:@selector(anNativeAdWillLeaveApplication)]) {
        [self.internalDelegate anNativeAdWillLeaveApplication];
    }
}

#pragma mark - <PMAdChoicesViewDelegate>
- (void)adChoicesWillLeaveApplication
{
    if ([self.internalDelegate respondsToSelector:@selector(anNativeAdWillLeaveApplication)]) {
        [self.internalDelegate anNativeAdWillLeaveApplication];
    }
}

@end
