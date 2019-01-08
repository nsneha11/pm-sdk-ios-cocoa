//
//  PMAdChoicesView.m
//  Sample App
//
//  Created by Arvind Bharadwaj on 03/09/18.
//  Copyright © 2018 AdsNative. All rights reserved.
//

#import "PMAdChoicesView.h"
#import "ImageDownloadQueue.h"
#import "NativeCache.h"
#import "Logging.h"
#import "AdAssets.h"
#import "AdDestinationDisplayAgent.h"
#import "InstanceProvider.h"

@interface PMAdChoicesView() <AdDestinationDisplayAgentDelegate>

@property (nonatomic, strong) NSString *privacyLink;
@property (nonatomic, strong) NSString *privacyImageUrl;
@property (nonatomic, strong) ImageDownloadQueue *imageDownloadQueue;
@property (nonatomic, readonly, strong) AdDestinationDisplayAgent *destinationDisplayAgent;
@property (nonatomic, weak) UIViewController *rootViewController;

@end

@implementation PMAdChoicesView

- (instancetype)initWithPrivacyInfo:(NSDictionary *)info
{
    self = [super init];
    if (self) {
        _privacyLink = [info objectForKey:kNativePrivacyLink];
        _privacyImageUrl = [info objectForKey:kNativePrivacyImageUrl];
        _imageDownloadQueue = [[ImageDownloadQueue alloc] init];
        _destinationDisplayAgent = [[InstanceProvider sharedProvider] buildAdDestinationDisplayAgentWithDelegate:self];;
        _rootViewController = [info objectForKey:@"viewController"];

        UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pmAdChoicesViewTapped)];
        [self addGestureRecognizer:recognizer];

        if ([self hasPrivacyLink]) {
            [self loadImageForURL:[NSURL URLWithString:self.privacyImageUrl] intoImageView:self];
        }
        self.userInteractionEnabled = YES;
    }
    return self;
}

- (instancetype)getPMAdChoicesView
{
    if ([self hasPrivacyLink])
        return self;
    return nil;
}

- (void)dealloc
{
    [_destinationDisplayAgent cancel];
    [_destinationDisplayAgent setDelegate:nil];
}

- (BOOL)hasPrivacyLink
{
    if ([self.privacyLink isEqualToString:@""] || [self.privacyImageUrl isEqualToString:@""])
        return NO;
    return YES;
}

- (void)pmAdChoicesViewTapped
{
    if ([self.delegate respondsToSelector:@selector(adChoicesWillLeaveApplication)]) {
        [self.delegate adChoicesWillLeaveApplication];
    }
    [self.destinationDisplayAgent displayDestinationForURL:[NSURL URLWithString:self.privacyLink]];
}

- (void)loadImageForURL:(NSURL *)imageURL intoImageView:(UIImageView *)imageView
{
    imageView.image = nil;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
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

            __weak PMAdChoicesView *weakSelf = self;
            [self.imageDownloadQueue addDownloadImageURLs:@[imageURL]
                                          completionBlock:^(NSArray *errors) {
                                              PMAdChoicesView *strongSelf = weakSelf;
                                              if (strongSelf) {
                                                  if (errors.count == 0) {
                                                      UIImage *image = [UIImage imageWithData:[[NativeCache sharedCache] retrieveDataForKey:imageURL.absoluteString]];

                                                      [strongSelf safeMainQueueSetImage:image intoImageView:imageView];
                                                  } else {
                                                      LogDebug(@"Failed to download %@ on cache miss. Giving up for now.", imageURL);
                                                  }
                                              } else {
                                                  LogDebug(@"Ad deallocated before loadImageForURL:intoImageView: download completion block was called");
                                              }
                                          }];
        }
    });
}

- (void)safeMainQueueSetImage:(UIImage *)image intoImageView:(UIImageView *)imageView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (image) {
            imageView.image = image;
        }
    });
}

#pragma mark - <AdDestinationDisplayAgent>

- (UIViewController *)viewControllerToPresentModalView
{
    return self.rootViewController;
}

- (void)displayAgentWillPresentModal
{
}

- (void)displayAgentWillLeaveApplication
{
}

- (void)displayAgentDidDismissModal
{
    self.rootViewController = nil;
}
@end
