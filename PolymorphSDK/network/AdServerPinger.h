//
//  AdServerPinger.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AdServerPingerDelegate;
@class AdConfigs;

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface AdServerPinger : NSObject <NSURLConnectionDataDelegate>

@property (nonatomic, weak) id<AdServerPingerDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL loading;

- (id)initWithDelegate:(id<AdServerPingerDelegate>)delegate;

- (void)loadURL:(NSURL *)URL;
- (void)cancel;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol AdServerPingerDelegate <NSObject>

@required
- (void)pingerDidReceiveAdConfiguration:(NSMutableOrderedSet *)adConfigurations withNetworksList:(NSDictionary *)networksList;
- (void)pingerDidFailWithError:(NSError *)error;

@end