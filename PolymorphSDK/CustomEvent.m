//
//  CustomEvent.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 24/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "CustomEvent.h"
#import "ImageDownloadQueue.h"

@interface CustomEvent ()

@property (nonatomic, strong) ImageDownloadQueue *imageDownloadQueue;

@end

@implementation CustomEvent

- (id)init
{
    self = [super init];
    if (self) {
        _imageDownloadQueue = [[ImageDownloadQueue alloc] init];
    }
    
    return self;
}

- (void)precacheImagesWithURLs:(NSArray *)imageURLs completionBlock:(void (^)(NSArray *errors))completionBlock
{
    if (imageURLs.count > 0) {
        [_imageDownloadQueue addDownloadImageURLs:imageURLs completionBlock:^(NSArray *errors) {
            if (completionBlock) {
                completionBlock(errors);
            }
        }];
    } else {
        if (completionBlock) {
            completionBlock(nil);
        }
    }
}

- (void)requestAdWithCustomEventInfo:(NSDictionary *)info
{
    /*override with custom network behavior*/
}

@end
