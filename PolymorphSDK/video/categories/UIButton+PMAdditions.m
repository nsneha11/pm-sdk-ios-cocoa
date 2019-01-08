//
//  UIButton+PMAdditions.m
//
//  Created by Arvind Bharadwaj on 14/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "UIButton+PMAdditions.h"
#import <objc/runtime.h>

@implementation UIButton (PMAdditions)

- (UIEdgeInsets)pm_TouchAreaInsets
{
    return [objc_getAssociatedObject(self, @selector(pm_TouchAreaInsets)) UIEdgeInsetsValue];
}

- (void)setPm_TouchAreaInsets:(UIEdgeInsets)touchAreaInsets
{
    NSValue *value = [NSValue valueWithUIEdgeInsets:touchAreaInsets];
    objc_setAssociatedObject(self, @selector(pm_TouchAreaInsets), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    UIEdgeInsets touchAreaInsets = self.pm_TouchAreaInsets;
    CGRect bounds = self.bounds;
    bounds = CGRectMake(bounds.origin.x - touchAreaInsets.left,
                        bounds.origin.y - touchAreaInsets.top,
                        bounds.size.width + touchAreaInsets.left + touchAreaInsets.right,
                        bounds.size.height + touchAreaInsets.top + touchAreaInsets.bottom);
    return CGRectContainsPoint(bounds, point);
}

@end

