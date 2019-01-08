//
//  AdSource.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AdSourceDelegate.h"

@class PMAdRequestTargeting;

@interface AdSource : NSObject

@property (nonatomic, weak) id <AdSourceDelegate> delegate;

+ (instancetype)source;
- (void)loadAdsWithAdUnitIdentifier:(NSString *)identifier andTargeting:(PMAdRequestTargeting *)targeting withViewController:(UIViewController *)viewController;
- (void)deleteCacheForAdUnitIdentifier:(NSString *)identifier;
- (id)dequeueAdForAdUnitIdentifier:(NSString *)identifier;


@end
