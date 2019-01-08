//
//  LastResortDelegate.m
//  PolymorphSDK
//
//  Created by Arvind Bharadwaj on 04/11/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "LastResortDelegate.h"

@implementation LastResortDelegate

+ (id)sharedDelegate
{
    static LastResortDelegate *lastResortDelegate;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        lastResortDelegate = [[self alloc] init];
    });
    return lastResortDelegate;
}


#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController
{
    [viewController dismissViewControllerAnimated:YES completion:nil];
}
#endif


@end
