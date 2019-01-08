//
//  NativeAd+Internal.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//
#import "PMNativeAd.h"

@interface PMNativeAd (Internal)

@property (nonatomic, readonly) NSDate *creationDate;
@property (nonatomic, strong) NSMutableSet *impressionTrackers;
@property (nonatomic, strong) NSMutableSet *viewabilityTrackers;
@property (nonatomic, strong) NSMutableSet *clickTrackers;

- (NSTimeInterval)requiredSecondsForImpression;
- (void)willAttachToView:(UIView *)view;
- (void)setVisible:(BOOL)visible;
//- (NSMutableSet *)impressionTrackers;
//- (NSArray *)clickTrackers;
//
//- (void)setClickTrackers:(NSArray *)clickTrackers;

@end
