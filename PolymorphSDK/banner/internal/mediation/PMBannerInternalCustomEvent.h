//
//  PMBannerInternalCustomEvent.h
//  Sample App
//
//  Created by Arvind Bharadwaj on 16/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//

#import "PMBannerCustomEvent.h"
#import "PMAdWebViewAgent.h"
//#import "MPPrivateBannerCustomEventDelegate.h"

@interface PMBannerInternalCustomEvent : PMBannerCustomEvent <PMAdWebViewAgentDelegate>

//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wobjc-property-synthesis"
//@property (nonatomic, weak) id<MPPrivateBannerCustomEventDelegate> delegate;
//#pragma clang diagnostic pop

@end
