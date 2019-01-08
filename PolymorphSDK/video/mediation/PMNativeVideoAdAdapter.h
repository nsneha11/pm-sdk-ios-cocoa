//
//  PMNativeVideoAdAdapter.h
//
//  Created by Arvind Bharadwaj on 26/11/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "AdAdapter.h"
#import "AdAdapterDelegate.h"

@interface PMNativeVideoAdAdapter : NSObject <AdAdapter>

@property (nonatomic, weak) id<AdAdapterDelegate> delegate;
@property (nonatomic, strong) NSArray *impressionTrackers;
@property (nonatomic, strong) NSArray *viewabililityTrackers;
@property (nonatomic, strong) NSArray *clickTrackers;

- (instancetype)initWithAdProperties:(NSMutableDictionary *)assets;

@end
