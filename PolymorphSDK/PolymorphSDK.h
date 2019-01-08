//
//  PolymorphSDK.h
//  PolymorphSDK
//
//  Created by Arvind Bharadwaj on 29/10/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
//! Project version number for PolymorphSDK.
FOUNDATION_EXPORT double PolymorphSDKVersionNumber;

//! Project version string for PolymorphSDK.
FOUNDATION_EXPORT const unsigned char PolymorphSDKVersionString[];

#import <PolymorphSDK/PMAdPositions.h>
#import <PolymorphSDK/PMClientAdPositions.h>
#import <PolymorphSDK/PMServerAdPositions.h>
#import <PolymorphSDK/PMAdRendering.h>
#import <PolymorphSDK/PMAdRequestTargeting.h>
#import <PolymorphSDK/PMNativeAd.h>
#import <PolymorphSDK/PMNativeAdDelegate.h>
#import <PolymorphSDK/PMNativeAdTrackerDelegate.h>
#import <PolymorphSDK/AdAdapter.h>
#import <PolymorphSDK/Logging.h>
#import <PolymorphSDK/AdAdapterDelegate.h>
#import <PolymorphSDK/PMCollectionViewAdPlacerDelegate.h>
#import <PolymorphSDK/PMTableViewAdPlacerDelegate.h>
#import <PolymorphSDK/CustomEvent.h>
#import <PolymorphSDK/CustomEventDelegate.h>
#import <PolymorphSDK/SDKConfigs.h>
#import <PolymorphSDK/AdErrors.h>
#import <PolymorphSDK/AdAssets.h>
#import <PolymorphSDK/URLResolver.h>
#import <PolymorphSDK/URLActionInfo.h>
#import <PolymorphSDK/PMAVFullScreenPlayerViewController.h>
#import <PolymorphSDK/AdDestinationDisplayAgent.h>
#import <PolymorphSDK/InstanceProvider.h>
#import <PolymorphSDK/Constants.h>
#import <PolymorphSDK/PMCollectionViewAdPlacer.h>
#import <PolymorphSDK/PMTableViewAdPlacer.h>
#import <PolymorphSDK/PMPrefetchAds.h>
#import <PolymorphSDK/PMClass.h>
#import <PolymorphSDK/PMBannerView.h>

@interface PolymorphSDK : NSObject

/**
 * Returns the PolymorphSDK singleton object.
 *
 * @return The AdsNative singleton object.
 */
+ (PolymorphSDK *)sharedInstance;

/**
 * A Boolean value indicating whether the AdsNative SDK should automatically fetch location to
 * derive targeting information for location-based ads.
 *
 * The SDK will periodically listen for location updates when set to YES. This will happen only if
 * the location services are enabled and the user has authorized the same.
 *
 * Default is set to YES.
 *
 * @param enableLocationUpdates A Boolean value indicating whether the SDK should listen for location updates.
 */
@property (nonatomic, assign) BOOL enableLocationUpdates;

@end
