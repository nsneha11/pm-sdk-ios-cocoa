//
//  PMMediaPlayerManager.m
//
//  Created by Arvind Bharadwaj on 15/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "PMMediaPlayerManager.h"
#import "PMPlayerViewController.h"
#import "PMWebViewPlayerViewController.h"
#import "AdAssets.h"

@interface PMMediaPlayerManager()

@property (nonatomic) NSDictionary *nativeAssets;

@end

@implementation PMMediaPlayerManager

+ (PMMediaPlayerManager *)sharedInstance
{
    static PMMediaPlayerManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PMMediaPlayerManager alloc] init];
    });
    return sharedInstance;
}

- (void)disposePlayerViewController
{
    if ([self.currentPlayerViewController isKindOfClass:[PMPlayerViewController class]]) {
        PMPlayerViewController *controller = (PMPlayerViewController *)self.currentPlayerViewController;
        [controller dispose];
        controller = nil;
    } else {
        PMWebViewPlayerViewController *controller = (PMWebViewPlayerViewController *)self.currentPlayerViewController;
        [controller dispose];
    }
    
    self.currentPlayerViewController = nil;
}

- (UIViewController *)playerViewControllerWithAdAssets:(NSDictionary *)nativeAssets
{
    self.nativeAssets = nativeAssets;
    // make sure only one instance of avPlayer at a time
    if (self.currentPlayerViewController) {
        [self disposePlayerViewController];
    }
    
    if ([self isAVPlayerAd]) {
        self.currentPlayerViewController = [[PMPlayerViewController alloc] initWithNativeAssets:nativeAssets];
    } else {
        //Load ANWebViewController instance
        self.currentPlayerViewController = [[PMWebViewPlayerViewController alloc] initWithNativeAssets:nativeAssets];
    }
    
    return self.currentPlayerViewController;
}

- (BOOL)isAVPlayerAd
{
    if ([[self.nativeAssets objectForKey:kNativeVideoEmbedTypeKey] caseInsensitiveCompare:@"native"] == NSOrderedSame) {
        return YES;
    }
    
    return NO;
}
@end
