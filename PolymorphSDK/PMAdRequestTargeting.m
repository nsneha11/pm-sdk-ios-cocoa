//
//  PMAdRequestTargeting.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "PMAdRequestTargeting.h"
#import "AdAssets.h"

@implementation PMAdRequestTargeting

+ (PMAdRequestTargeting *)targeting
{
    return [[PMAdRequestTargeting alloc] init];
}

//- (void)setDesiredAssets:(NSSet *)desiredAssets
//{
//    if (_desiredAssets != desiredAssets) {
//        
//        NSMutableSet *allowedAdAssets = [NSMutableSet setWithObjects:kNativeTitleKey,
//                                         kNativeTextKey,
//                                         kNativeIconImageKey,
//                                         kNativeMainImageKey,
//                                         kNativeCTATextKey,
//                                         kNativeStarRatingKey,
//                                         nil];
//        [allowedAdAssets intersectSet:desiredAssets];
//        _desiredAssets = allowedAdAssets;
//    }
//}


@end
