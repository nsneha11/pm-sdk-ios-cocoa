//
//  IANLogProvider.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 21/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "IANLogProvider.h"

@interface IANLogProvider ()

@property (nonatomic, strong) NSMutableArray *loggers;

@end

@interface SystemLogger : NSObject <Logger>
@end


@implementation IANLogProvider

#pragma mark - Singleton instance

+ (IANLogProvider *)sharedLogProvider
{
    static dispatch_once_t once;
    static IANLogProvider *sharedLogProvider;
    dispatch_once(&once, ^{
        sharedLogProvider = [[self alloc] init];
    });
    
    return sharedLogProvider;
}

#pragma mark - Object Lifecycle

- (id)init
{
    self = [super init];
    if (self) {
        _loggers = [NSMutableArray array];
        [self addLogger:[[SystemLogger alloc] init]];
    }
    return self;
}

#pragma mark - Loggers

- (void)addLogger:(id<Logger>)logger
{
    [self.loggers addObject:logger];
}

- (void)removeLogger:(id<Logger>)logger
{
    [self.loggers removeObject:logger];
}

#pragma mark - Logging

- (void)logMessage:(NSString *)message atLogLevel:(LogLevel)logLevel
{
    [self.loggers enumerateObjectsUsingBlock:^(id<Logger> logger, NSUInteger idx, BOOL *stop) {
        if ([logger logLevel] <= logLevel) {
            [logger logMessage:message];
        }
    }];
}

@end

@implementation SystemLogger

- (void)logMessage:(NSString *)message
{
    NSLog(@"%@", message);
}

- (LogLevel)logLevel
{
    return LogGetLevel();
}

@end
