//
//  UIView+PMAdditions.h
//
//  Created by Arvind Bharadwaj on 12/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (PMAdditions)

@property (nonatomic) CGFloat x;
@property (nonatomic) CGFloat y;
@property (nonatomic) CGFloat height;
@property (nonatomic) CGFloat width;

- (void)setX:(CGFloat)x;
- (void)setY:(CGFloat)y;
- (void)setWidth:(CGFloat)width;
- (void)setHeight:(CGFloat)height;

- (UIView *)snapshotView;

// convert any UIView to UIImage view. We can apply blur effect on UIImage.
- (UIImage *)snapshot:(BOOL)usePresentationLayer;
@end
