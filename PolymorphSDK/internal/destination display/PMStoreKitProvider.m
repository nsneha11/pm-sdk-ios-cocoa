//
//  PMStoreKitProvider.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 06/10/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "PMStoreKitProvider.h"
#import "Constants.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= AN_IOS_6_0
/*
 * On iOS 7 SKStoreProductViewController can cause a crash if the application does not list Portrait as a supported
 * interface orientation. Specifically, SKStoreProductViewController's shouldAutorotate returns YES, even though
 * the SKStoreProductViewController's supported interface orientations does not intersect with the application's list.
 *
 * To fix, we disallow autorotation so the SKStoreProductViewController will use its supported orientation on iOS 7 devices.
 */
@interface ANiOS7SafeStoreProductViewController : SKStoreProductViewController

@end

@implementation ANiOS7SafeStoreProductViewController

- (BOOL)shouldAutorotate
{
    return NO;
}

@end
#endif

@implementation PMStoreKitProvider

+ (BOOL)deviceHasStoreKit
{
    return !!NSClassFromString(@"SKStoreProductViewController");
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= AN_IOS_6_0
+ (SKStoreProductViewController *)buildController
{
    // use our safe subclass on iOS 7
    if ([[UIDevice currentDevice].systemVersion compare:@"7.0"] != NSOrderedAscending) {
        return [[ANiOS7SafeStoreProductViewController alloc] init];
    } else {
        return [[SKStoreProductViewController alloc] init];
    }
}
#endif

@end
