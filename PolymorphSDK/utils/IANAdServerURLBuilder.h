//
//  IANAdServerURLBuilder.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface IANAdServerURLBuilder : NSObject

+ (NSURL *)URLWithAdUnitID:(NSString *)adUnitID
                  keywords:(NSArray *)keywords
                   testing:(BOOL)testing;

+ (NSURL *)URLWithAdUnitID:(NSString *)adUnitID
                  keywords:(NSArray *)keywords
             desiredAssets:(NSArray *)assets
                  location:(CLLocation *)location
                   testing:(BOOL)testing;

+ (NSURL *)URLWithAdUnitID:(NSString *)adUnitID
                  keywords:(NSArray *)keywords
                   version:(NSString *)version
             desiredAssets:(NSArray *)assets
                  location:(CLLocation *)location
                   testing:(BOOL)testing;


@end
