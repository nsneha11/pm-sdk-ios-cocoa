//
//  LastResortDelegate.h
//  PolymorphSDK
//
//  Created by Arvind Bharadwaj on 04/11/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@interface LastResortDelegate : NSObject

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
<SKStoreProductViewControllerDelegate>
#endif

+ (id)sharedDelegate;

@end
