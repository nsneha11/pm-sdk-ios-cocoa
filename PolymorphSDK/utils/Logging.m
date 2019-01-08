//
//  Logging.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 21/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "Logging.h"
#import "IANIdentityProvider.h"
#import "IANLogProvider.h"

NSString * const kClearErrorLogFormatWithAdUnitID = @"No ads found for ad unit: %@";

NSString * const kSystemLogPrefix = @"Polymorph: %@";

static LogLevel systemLogLevel = LogLevelInfo;

LogLevel LogGetLevel()
{
    return systemLogLevel;
}

void LogSetLevel(LogLevel level)
{
    systemLogLevel = level;
}

void _Log(LogLevel level, NSString *format, va_list args)
{
    static NSString *sIdentifier;
    static NSString *sObfuscatedIdentifier;
    
    if (!sIdentifier) {
        sIdentifier = [[IANIdentityProvider identifier] copy];
    }
    
    if (!sObfuscatedIdentifier) {
        sObfuscatedIdentifier = [[IANIdentityProvider obfuscatedIdentifier] copy];
    }
    
    NSString *logString = [[NSString alloc] initWithFormat:format arguments:args];
    
    // Replace identifier with a obfuscated version when logging.
    logString = [logString stringByReplacingOccurrencesOfString:sIdentifier withString:sObfuscatedIdentifier];
    
    [[IANLogProvider sharedLogProvider] logMessage:logString atLogLevel:level];
}


void _LogTrace(NSString *format, ...)
{
    format = [NSString stringWithFormat:kSystemLogPrefix, format];
    va_list args;
    va_start(args, format);
    _Log(LogLevelTrace, format, args);
    va_end(args);
}

void _LogDebug(NSString *format, ...)
{
    format = [NSString stringWithFormat:kSystemLogPrefix, format];
    va_list args;
    va_start(args, format);
    _Log(LogLevelDebug, format, args);
    va_end(args);
}

void _LogWarn(NSString *format, ...)
{
    format = [NSString stringWithFormat:kSystemLogPrefix, format];
    va_list args;
    va_start(args, format);
    _Log(LogLevelWarn, format, args);
    va_end(args);
}

void _LogInfo(NSString *format, ...)
{
    format = [NSString stringWithFormat:kSystemLogPrefix, format];
    va_list args;
    va_start(args, format);
    _Log(LogLevelInfo, format, args);
    va_end(args);
}

void _LogError(NSString *format, ...)
{
    format = [NSString stringWithFormat:kSystemLogPrefix, format];
    va_list args;
    va_start(args, format);
    _Log(LogLevelError, format, args);
    va_end(args);
}

void _LogFatal(NSString *format, ...)
{
    format = [NSString stringWithFormat:kSystemLogPrefix, format];
    va_list args;
    va_start(args, format);
    _Log(LogLevelFatal, format, args);
    va_end(args);
}
