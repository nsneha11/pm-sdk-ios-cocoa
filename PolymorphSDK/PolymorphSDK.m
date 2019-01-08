//
//  PolymorphSDK.m
//  PolymorphSDK
//
//  Created by Arvind Bharadwaj on 09/11/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "PolymorphSDK.h"
#import "GeoLocationProvider.h"

@implementation PolymorphSDK

+ (PolymorphSDK *)sharedInstance
{
    static PolymorphSDK *sharedInstance = nil;
    static dispatch_once_t initOnceToken;
    dispatch_once(&initOnceToken, ^{
        sharedInstance = [[PolymorphSDK alloc] init];
    });
    return sharedInstance;
}


- (void)setEnableLocationUpdates:(BOOL)enableLocationUpdates
{
    _enableLocationUpdates = enableLocationUpdates;
    [[[InstanceProvider sharedProvider] sharedGeoLocationProvider] setEnableLocationUpdates:enableLocationUpdates];
}
@end
