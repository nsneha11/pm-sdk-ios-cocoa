//
//  NativeAdData.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 22/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PMNativeAd;

@interface NativeAdData : NSObject

@property (nonatomic, copy) NSString *adUnitID;
@property (nonatomic, strong) PMNativeAd *ad;
@property (nonatomic, assign) Class renderingClass;

@end
