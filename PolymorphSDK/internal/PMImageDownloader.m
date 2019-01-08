//
//  PMImageDownloader.m
//
//  Created by Arvind Bharadwaj on 15/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "PMImageDownloader.h"
#import "NativeCache.h"
#import "Logging.h"
#import "ImageDownloadQueue.h"

@interface PMImageDownloader()

@property (nonatomic) ImageDownloadQueue *imageDownloadQueue;
@property (assign) int count;
@property (assign) int totalCount;
@property (assign) BOOL imagesDownloadFailed;
@property (assign) BOOL downloadFailedFirstResponseDelegate;
@end

@implementation PMImageDownloader

- (instancetype)init
{
    self = [super init];
    if (self) {
        _imageDownloadQueue = [[ImageDownloadQueue alloc]init];
        _count = 0;
        _totalCount = 0;
    }
    return self;
}

- (void)downloadAndCacheImagesWithURLs:(NSArray <NSURL *> *)imageURLs
{
    _totalCount = (int)imageURLs.count;
    
    for (NSURL *imageURL in imageURLs){
        [self loadImageForURL:imageURL];
    }
    
}

- (void)loadImageForURL:(NSURL *)imageURL
{
    
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
            
            [self safeMainQueueSetImage:image];
        } else if (imageURL) {
            LogDebug(@"Cache miss on %@. Re-downloading...", imageURL);
            
            __weak PMImageDownloader *weakSelf = self;
            [self.imageDownloadQueue addDownloadImageURLs:@[imageURL]
                                          completionBlock:^(NSArray *errors) {
                                              PMImageDownloader *strongSelf = weakSelf;
                                              if (strongSelf) {
                                                  if (errors.count == 0) {
                                                      UIImage *image = [UIImage imageWithData:[[NativeCache sharedCache] retrieveDataForKey:imageURL.absoluteString]];
                                                      
                                                      [strongSelf safeMainQueueSetImage:image];
                                                  } else {
                                                      LogDebug(@"Failed to download %@ on cache miss.", imageURL);
                                                      strongSelf.imagesDownloadFailed = YES;
                                                      [strongSelf safeMainQueueSetImage:nil];
                                                  }
                                              } else {
                                                  LogInfo(@"NativeAd deallocated before download completion");
                                                  strongSelf.imagesDownloadFailed = YES;
                                                  [strongSelf safeMainQueueSetImage:nil];
                                              }
                                          }];
        }
    });
}

- (void)safeMainQueueSetImage:(UIImage *)image
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (image) {
            //increment count
            _count = _count + 1;
            if (_count == _totalCount) {
                if ([self.delegate respondsToSelector:@selector(imagesDownloadedAndCached)]) {
                    [self.delegate imagesDownloadedAndCached];
                }
            }
        }
        
        if (self.imagesDownloadFailed && !self.downloadFailedFirstResponseDelegate) {
            self.downloadFailedFirstResponseDelegate = YES;
            if ([self.delegate respondsToSelector:@selector(imagesDownloadFailed)]) {
                [self.delegate imagesDownloadFailed];
            }
        }
    });
}

- (UIImage *)getCachedImageForURL:(NSURL *)imageURL
{
    NSData *cachedImageData = [[NativeCache sharedCache] retrieveDataForKey:imageURL.absoluteString];
    UIImage *image = [UIImage imageWithData:cachedImageData];
    
    if (image) {
        return image;
    } 
    return nil;
}
@end
