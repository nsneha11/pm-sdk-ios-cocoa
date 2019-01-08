//
//  UIView+NativeAd.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 22/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "UIView+NativeAd.h"
#import <objc/runtime.h>

static char NativeAdKey;

@implementation UIView (NativeAd)

- (void)pm_removeNativeAd
{
    [self pm_setNativeAd:nil];
}

- (void)pm_setNativeAd:(PMNativeAd *)adObject
{
    objc_setAssociatedObject(self, &NativeAdKey, adObject, OBJC_ASSOCIATION_ASSIGN);
}

- (PMNativeAd *)pm_nativeAd
{
    return (PMNativeAd *)objc_getAssociatedObject(self, &NativeAdKey);
}
@end
