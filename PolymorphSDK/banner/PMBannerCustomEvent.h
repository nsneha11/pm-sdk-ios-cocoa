//
//  PMBannerCustomEvent.h
//
//  Created by Arvind Bharadwaj on 08/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "PMBannerCustomEventDelegate.h"

/**
 * The Polymorph iOS SDK mediates third party Ad Networks using custom events.
 *
 * `PMBannerCustomEvent` is a base class for custom events that support banners. By implementing
 * subclasses of `PMBannerCustomEvent` you can enable the Polymorph SDK to natively support a wide
 * variety of third-party ad networks.
 *
 * At runtime, the Polymorph SDK will find and instantiate an `PMBannerCustomEvent` subclass as needed and
 * invoke its `-requestAdWithSize:customEventInfo:` method.
 */

@interface PMBannerCustomEvent : NSObject

/** @name Requesting a Banner Ad */

/**
 * Called when the Polymorph SDK requires a new banner ad.
 *
 * When the Polymorph SDK receives a response indicating it should load a custom event, it will send
 * this message to your custom event class. Your implementation of this method can either load a
 * banner ad from a third-party ad network, or execute any application code. It must also notify the
 * `PMBannerCustomEventDelegate` of certain lifecycle events.
 *
 * @param size The current size of the parent `PMBannerView`.  You should use this information to create
 * and/or request a banner of the appropriate size.
 *
 * @param info A  dictionary containing additional custom data associated with a given custom event
 * request.
 */
- (void)requestAdWithSize:(CGSize)size customEventInfo:(NSDictionary *)info;

/** @name Callbacks */

/**
 * Called when a banner rotation should occur.
 *
 * If you call `-rotateToOrientation` on an `PMBannerView`, it will forward the message to its custom event.
 * You can implement this method for third-party ad networks that have special behavior when
 * orientation changes happen.
 *
 * @param newOrientation The `UIInterfaceOrientation` passed to the `PMBannerView`'s `rotateToOrientation` method.
 *
 */
- (void)rotateToOrientation:(UIInterfaceOrientation)newOrientation;

/**
 * Called when the banner is presented on screen.
 *
 * If you decide to [opt out of automatic impression tracking](enableAutomaticImpressionAndClickTracking), you should place your
 * manual calls to [-trackImpression]([PMBannerCustomEventDelegate trackImpression]) in this method to ensure correct metrics.
 */
- (void)didDisplayAd;

/** @name Impression and Click Tracking */

/**
 * Override to opt out of automatic impression and click tracking.
 *
 * By default, the PMBannerCustomEventDelegate will automatically record impressions and clicks in
 * response to the appropriate callbacks. You may override this behavior by implementing this method
 * to return `NO`.
 *
 * @warning **Important**: If you do this, you are responsible for calling the `[-trackImpression]([PMBannerCustomEventDelegate trackImpression])` and
 * `[-trackClick]([PMBannerCustomEventDelegate trackClick])` methods on the custom event delegate.
 *
 */
- (BOOL)enableAutomaticImpressionAndClickTracking;

/** @name Communicating with the Polymorph SDK */

/**
 * The `PMBannerCustomEventDelegate` to send messages to as events occur.
 *
 * The `delegate` object defines several methods that you should call in order to inform both Polymorph
 * and your `PMBannerView`'s delegate of the progress of your custom event.
 *
 */
@property (nonatomic, weak) id<PMBannerCustomEventDelegate> delegate;

@end
