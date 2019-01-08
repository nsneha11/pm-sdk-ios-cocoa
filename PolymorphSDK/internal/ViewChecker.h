//
//  ViewChecker.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 22/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * The `ViewChecker` class is used to check if a given view is visible. It also is used to determine
 * percentage visibility of a view
 */
@interface ViewChecker : NSObject

BOOL ViewIsVisible(UIView *view);
BOOL ViewIntersectsParentWindowWithPercent(UIView *view, CGFloat percentVisible);

@end
