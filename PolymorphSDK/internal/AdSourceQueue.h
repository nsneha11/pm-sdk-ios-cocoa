//
//  AdSourceQueue.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class PMAdRequestTargeting;
@class PMNativeAd;

@protocol AdSourceQueueDelegate;

@interface AdSourceQueue : NSObject

@property (nonatomic, weak) id <AdSourceQueueDelegate> delegate;
@property (nonatomic, assign) NSUInteger currentSequence;

- (instancetype)initWithAdUnitIdentifier:(NSString *)identifier andTargeting:(PMAdRequestTargeting *)targeting withViewController:(UIViewController *)viewController;
- (PMNativeAd *)dequeueAdWithMaxAge:(NSTimeInterval)age;
- (NSUInteger)count;
- (void)loadAds;
- (void)cancelRequests;

@end

@protocol AdSourceQueueDelegate <NSObject>

- (void)adSourceQueueAdIsAvailable:(AdSourceQueue *)source;

@end
