//
//  IANLogProvider.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 21/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Logging.h"

@protocol Logger;

@interface IANLogProvider : NSObject

+ (IANLogProvider *)sharedLogProvider;
- (void)addLogger:(id<Logger>)logger;
- (void)removeLogger:(id<Logger>)logger;
- (void)logMessage:(NSString *)message atLogLevel:(LogLevel)logLevel;

@end

@protocol Logger <NSObject>

- (LogLevel)logLevel;
- (void)logMessage:(NSString *)message;

@end
