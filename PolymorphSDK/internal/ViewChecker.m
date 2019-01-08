//
//  ViewChecker.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 22/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "ViewChecker.h"

@implementation ViewChecker

BOOL ViewIsVisible(UIView *view)
{
    // In order for a view to be visible, it:
    // 1) must not be hidden,
    // 2) must not have an ancestor that is hidden,
    // 3) must be within the frame of its parent window.
    //
    // Note: this function does not check whether any part of the view is obscured by another view.
    
    return (!view.hidden &&
            !ViewHasHiddenAncestor(view) &&
            ViewIntersectsParentWindow(view));
}

BOOL ViewHasHiddenAncestor(UIView *view)
{
    UIView *ancestor = view.superview;
    while (ancestor) {
        if (ancestor.hidden) return YES;
        ancestor = ancestor.superview;
    }
    return NO;
}

BOOL ViewIntersectsParentWindow(UIView *view)
{
    UIWindow *parentWindow = ViewGetParentWindow(view);
    
    if (parentWindow == nil) {
        return NO;
    }
    
    // We need to call convertRect:toView: on this view's superview rather than on this view itself.
    CGRect viewFrameInWindowCoordinates = [view.superview convertRect:view.frame toView:parentWindow];
    
    return CGRectIntersectsRect(viewFrameInWindowCoordinates, parentWindow.frame);
}

UIWindow *ViewGetParentWindow(UIView *view)
{
    UIView *ancestor = view.superview;
    while (ancestor) {
        if ([ancestor isKindOfClass:[UIWindow class]]) {
            return (UIWindow *)ancestor;
        }
        ancestor = ancestor.superview;
    }
    return nil;
}

BOOL ViewIntersectsParentWindowWithPercent(UIView *view, CGFloat percentVisible)
{
    UIWindow *parentWindow = ViewGetParentWindow(view);
    
    if (parentWindow == nil) {
        return NO;
    }
    
    // We need to call convertRect:toView: on this view's superview rather than on this view itself.
    CGRect viewFrameInWindowCoordinates = [view.superview convertRect:view.frame toView:parentWindow];
    CGRect intersection = CGRectIntersection(viewFrameInWindowCoordinates, parentWindow.frame);
    
    CGFloat intersectionArea = CGRectGetWidth(intersection) * CGRectGetHeight(intersection);
    CGFloat originalArea = CGRectGetWidth(view.bounds) * CGRectGetHeight(view.bounds);
    
    return intersectionArea >= (originalArea * percentVisible);
}

@end
