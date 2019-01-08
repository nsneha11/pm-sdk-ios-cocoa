//
//  UIView+NativeAd.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 22/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PMNativeAd;

@interface UIView (NativeAd)

- (void)pm_setNativeAd:(PMNativeAd *)adObject;
- (void)pm_removeNativeAd;
- (PMNativeAd *)pm_nativeAd;

@end
