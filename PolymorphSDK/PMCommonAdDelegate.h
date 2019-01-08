//
//  PMCommonAdDelegate.h
//
//  Created by Arvind Bharadwaj on 20/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class SDKConfigs;

@protocol PMCommonAdDelegate <NSObject>
@optional

//used by banner
- (void)userWillLeaveApplication;
- (void)rotateToOrientation:(UIInterfaceOrientation)orientation;
- (CGSize)containerSize;
- (void)isRenderedPMAd:(UIView *)ad;

//used by native and banner ad
- (SDKConfigs *)getSDKConfigs;
@end
