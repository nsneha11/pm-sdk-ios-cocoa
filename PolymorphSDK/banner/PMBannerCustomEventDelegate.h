//
//  PMBannerCustomEventDelegate.h
//
//  Created by Arvind Bharadwaj on 08/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@class PMBannerCustomEvent;

/**
 * Instances of your custom subclass of `PMBannerCustomEvent` will have an `PMBannerCustomEventDelegate` delegate.
 * You use this delegate to communicate events ad events back to the Polymorph SDK.
 */

@protocol PMBannerCustomEventDelegate <NSObject>

/**
 * The view controller instance to use when presenting modals.
 *
 * @return `viewControllerForPresentingModalView` returns the same view controller that you
 * specify when implementing the `PMBannerViewDelegate` protocol.
 */
- (UIViewController *)viewControllerForPresentingModalView;


/** @name Banner Ad Event Callbacks - Fetching Ads */

/**
 * Call this method immediately after an ad loads succesfully.
 *
 * @param event You should pass `self` to allow the Polymorph SDK to associate this event with the correct
 * instance of your custom event.
 *
 * @param ad The `UIView` representing the banner ad.  This view will be inserted into the `PMBannerView`
 * and presented to the user by the Polymorph SDK.
 *
 * @warning **Important**: Your custom event subclass **must** call this method when it successfully loads an ad.
 * Failure to do so will disrupt the mediation waterfall and cause future ad requests to stall.
 */
- (void)bannerCustomEvent:(PMBannerCustomEvent *)event didLoadAd:(UIView *)ad;

/**
 * Call this method immediately after an ad fails to load.
 *
 * @param event You should pass `self` to allow the Polymorph SDK to associate this event with the correct
 * instance of your custom event.
 *
 * @param error (*optional*) You may pass an error describing the failure.
 *
 * @warning **Important**: Your custom event subclass **must** call this method when it fails to load an ad.
 * Failure to do so will disrupt the mediation waterfall and cause future ad requests to stall.
 */
- (void)bannerCustomEvent:(PMBannerCustomEvent *)event didFailToLoadAdWithError:(NSError *)error;

/** @name Banner Ad Event Callbacks - User Interaction */

/**
 * Call this method when the banner ad will cause the user to leave the application.
 *
 * For example, the user may have tapped on a link to visit the App Store or Safari.
 *
 * @param event You should pass `self` to allow the Polymorph SDK to associate this event with the correct
 * instance of your custom event.
 *
 */
- (void)bannerCustomEventWillLeaveApplication:(PMBannerCustomEvent *)event;


@end
