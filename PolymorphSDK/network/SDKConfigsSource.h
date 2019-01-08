//
//  SDKConfigsSource.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 28/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SDKConfigs;

typedef enum : NSUInteger {
    SDKConfigsSourceInvalidAdUnitIdentifier,
    SDKConfigsSourceEmptyResponse,
    SKConfigsSourceDeserializationFailed,
    SDKConfigsSourceConnectionFailed,
} SDKConfigsSourceErrorCode;

@interface SDKConfigsSource : NSObject

@property (nonatomic, strong) SDKConfigs *sdkConfigs;

+ (SDKConfigsSource *)sharedInstance;

- (SDKConfigs *)getSDKConfigsForAdUnitId:(NSString *)adUnitId;

- (void)loadConfigsWithAdUnitIdentifier:(NSString *)identifier completionHandler:(void (^)(SDKConfigs *config, NSError *error))completionHandler;
- (void)cancel;

@end
