//
//  PMImageDownloader.h
//
//  Created by Arvind Bharadwaj on 15/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PMImageDownloaderDelegate <NSObject>

@optional
-(void)imagesDownloadedAndCached;
-(void)imagesDownloadFailed;
@end


@interface PMImageDownloader : NSObject

- (void)loadImageForURL:(NSURL *)imageURL;

- (void)downloadAndCacheImagesWithURLs:(NSArray <NSURL *> *)imageURLs;
- (UIImage *)getCachedImageForURL:(NSURL *)imageURL;

@property (nonatomic) id<PMImageDownloaderDelegate> delegate;

@end
