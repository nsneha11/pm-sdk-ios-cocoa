//
//  AdRequest.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Constants.h"

@class PMNativeAd;
@class AdRequest;
@class PMAdRequestTargeting;
@class PMAdResponse;
@protocol PMCommonAdDelegate;

typedef void(^AdRequestHandler)(AdRequest *request,
                                        PMAdResponse *response,
                                        NSError *error);

////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The `AdRequest` class is used to manage individual requests to the AdsNative ad server for
 * ads.
 *
 * @warning **Note:** This class is meant for one-off requests for which you intend to manually
 * process the ad response. If you wish to use only native ads and are using `PMTableViewAdPlacer` or
 * `PMCollectionViewAdPlacer` to display ads, there should be no need for you to use this class.
 */

@interface AdRequest : NSObject

/**
 * The view controller to be passed to every adapter for third party ad loads
 * This MUST be set immediately after creating an AdRequest instance, otherwise nil view controller will
 * be sent to adapters. 
 * At the adapter level, this key is removed as soon as the native ad object is created.
 */
@property (nonatomic, strong) UIViewController *viewController;

/** @name Targeting Information */

/**
 * An object representing targeting parameters that can be passed to the AdsNative ad server to
 * serve more relevant advertising.
 */
@property (nonatomic, strong) PMAdRequestTargeting *targeting;

/** @name Initializing and Starting an Ad Request */

/**
 * Initializes a request object.
 *
 * @param identifier The ad unit identifier for this request. An ad unit is a defined placement in
 * your application set aside for advertising. Ad unit IDs are created on the AdsNative website.
 *
 * @param requestType The type of ad request (native, banner, or all)
 * @return An `AdRequest` object.
 */
+ (AdRequest *)requestWithAdUnitIdentifier:(NSString *)identifier requestType:(PM_REQUEST_TYPE)requestType;

/**
 * Executes a request to the AdsNative ad server.
 *
 * @param handler A block to execute when the request finishes. The block includes as parameters the
 * request itself and either a valid Ad or an NSError object indicating failure.
 */
- (void)startWithCompletionHandler:(AdRequestHandler)handler;

@property (nonatomic, weak) id<PMCommonAdDelegate> delegate;
- (void)rotateToOrientation:(UIInterfaceOrientation)orientation;

/*
 * Set the native ad object making the request. 
 * This is so that the delegate callbacks can be reassigned to the new native obj returned.
 */
@property (nonatomic, strong) PMNativeAd *nativeAd;

/**
 * This is set when you want PM banner ads to not be rendered into webview immediately. This is
 * done in case you don't want impressions to be tracked immediately upon successful ad response.
 * If this is set, PMBannerViews' `renderDelayedAd` needs to be called to render the ad into view.
 */
@property (nonatomic, assign) BOOL requestDelayedAd;

@end
