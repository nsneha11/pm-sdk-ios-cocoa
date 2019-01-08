//
//  PMNativeAdAdapter.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 30/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "AdAdapter.h"
#import "AdAdapterDelegate.h"

@interface PMNativeAdAdapter : NSObject <AdAdapter>

@property (nonatomic, weak) id<AdAdapterDelegate> delegate;
@property (nonatomic, strong) NSArray *impressionTrackers;
@property (nonatomic, strong) NSArray *viewabililityTrackers;
@property (nonatomic, strong) NSArray *clickTrackers;

- (instancetype)initWithAdProperties:(NSMutableDictionary *)assets;

@end
