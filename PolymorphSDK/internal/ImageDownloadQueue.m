//
//  ImageDownloadQueue.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "ImageDownloadQueue.h"
#import "Logging.h"
#import "AdErrors.h"
#import "NativeCache.h"

#define kMaxAllowedUIImageSize (1024 * 1024)

@interface ImageDownloadQueue ()

@property (atomic, strong) NSOperationQueue *imageDownloadQueue;
@property (atomic, assign) BOOL isCanceled;

@end

@implementation ImageDownloadQueue

- (id)init
{
    self = [super init];
    
    if (self != nil) {
        _imageDownloadQueue = [[NSOperationQueue alloc] init];
        [_imageDownloadQueue setMaxConcurrentOperationCount:1]; // serial queue
    }
    
    return self;
}

- (void)dealloc
{
    [_imageDownloadQueue cancelAllOperations];
}

- (void)addDownloadImageURLs:(NSArray *)imageURLs completionBlock:(ImageDownloadQueueCompletionBlock)completionBlock
{
    [self addDownloadImageURLs:imageURLs completionBlock:completionBlock useCachedImage:YES];
}

- (void)addDownloadImageURLs:(NSArray *)imageURLs completionBlock:(ImageDownloadQueueCompletionBlock)completionBlock useCachedImage:(BOOL)useCachedImage
{
    __block NSMutableArray *errors = nil;
    
    for (NSURL *imageURL in imageURLs) {
        [self.imageDownloadQueue addOperationWithBlock:^{
            @autoreleasepool {
                if (![[NativeCache sharedCache] cachedDataExistsForKey:imageURL.absoluteString] || !useCachedImage) {
                    LogDebug(@"Downloading %@", imageURL);
                    
                    NSURLResponse *response = nil;
                    NSError *error = nil;
                    NSData *data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:imageURL]
                                                         returningResponse:&response
                                                                     error:&error];
                    
                    BOOL validImageDownloaded = data != nil;
                    if (validImageDownloaded) {
                        UIImage *downloadedImage = [UIImage imageWithData:data];
                        BOOL validImageSize = downloadedImage.size.width * downloadedImage.size.height <= kMaxAllowedUIImageSize;
                        if (downloadedImage != nil && validImageSize) {
                            [[NativeCache sharedCache] storeData:data forKey:imageURL.absoluteString];
                        } else {
                            if (downloadedImage == nil) {
                                LogDebug(@"Error: invalid image data downloaded");
                            } else if (!validImageSize) {
                                LogDebug(@"Error: image data exceeds acceptable size limit of 1 MB (actual: %@)", NSStringFromCGSize(downloadedImage.size));
                            }
                            
                            validImageDownloaded = NO;
                        }
                    }
                    
                    if (!validImageDownloaded) {
                        if (error == nil) {
                            error = AdNSErrorForImageDownloadFailure();
                        }
                        
                        if (errors == nil) {
                            errors = [NSMutableArray array];
                        }
                        
                        [errors addObject:error];
                    }
                }
            }
        }];
    }
    
    // after all images have been downloaded, invoke callback on main thread
    [self.imageDownloadQueue addOperationWithBlock:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.isCanceled) {
                completionBlock(errors);
            }
        });
    }];
}

- (void)cancelAllDownloads
{
    self.isCanceled = YES;
    [self.imageDownloadQueue cancelAllOperations];
}

@end
