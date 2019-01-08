//
//  UIColor+PMAdditions.h
//
//  Created by Arvind Bharadwaj on 12/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (PMAdditions)

+ (UIColor *)pm_colorFromHexString:(NSString *)hexString alpha:(CGFloat)alpha;

@end
