//
//  AdPlacerInvocation.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 24/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "AdPlacerInvocation.h"
#import "StreamAdPlacer.h"


@implementation AdPlacerInvocation

+ (NSInvocation *)invocationForTarget:(id)target
                             selector:(SEL)selector
                            indexPath:(NSIndexPath *)indexPath
                       streamAdPlacer:(StreamAdPlacer *)streamAdPlacer
{
    if (![target respondsToSelector:selector]) {
        return nil;
    }
    
    // No invocations for ad rows.
    if ([streamAdPlacer isAdAtIndexPath:indexPath]) {
        return nil;
    }
    
    // Create the invocation.
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:target];
    [invocation setSelector:selector];
    return invocation;
}

+ (NSInvocation *)invokeForTarget:(id)target
                 with2ArgSelector:(SEL)selector
                         firstArg:(id)arg1
                        secondArg:(NSIndexPath *)indexPath
                   streamAdPlacer:(StreamAdPlacer *)streamAdPlacer
{
    NSInvocation *invocation = [AdPlacerInvocation invocationForTarget:target
                                                                selector:selector
                                                               indexPath:indexPath
                                                          streamAdPlacer:streamAdPlacer];
    if (invocation) {
        NSIndexPath *origPath = [streamAdPlacer originalIndexPathForAdjustedIndexPath:indexPath];
        [invocation setArgument:&(arg1) atIndex:2];
        [invocation setArgument:&(origPath) atIndex:3];
        [invocation invoke];
    }
    return invocation;
}

+ (NSInvocation *)invokeForTarget:(id)target
                 with3ArgSelector:(SEL)selector
                         firstArg:(id)arg1
                        secondArg:(id)arg2
                         thirdArg:(NSIndexPath *)indexPath
                   streamAdPlacer:(StreamAdPlacer *)streamAdPlacer
{
    NSInvocation *invocation = [AdPlacerInvocation invocationForTarget:target
                                                                selector:selector
                                                               indexPath:indexPath
                                                          streamAdPlacer:streamAdPlacer];
    if (invocation) {
        NSIndexPath *origPath = [streamAdPlacer originalIndexPathForAdjustedIndexPath:indexPath];
        [invocation setArgument:&(arg1) atIndex:2];
        [invocation setArgument:&(arg2) atIndex:3];
        [invocation setArgument:&(origPath) atIndex:4];
        [invocation invoke];
    }
    return invocation;
}

+ (NSInvocation *)invokeForTarget:(id)target
              with3ArgIntSelector:(SEL)selector
                         firstArg:(id)arg1
                        secondArg:(NSInteger)arg2
                         thirdArg:(NSIndexPath *)indexPath
                   streamAdPlacer:(StreamAdPlacer *)streamAdPlacer
{
    NSInvocation *invocation = [AdPlacerInvocation invocationForTarget:target
                                                                selector:selector
                                                               indexPath:indexPath
                                                          streamAdPlacer:streamAdPlacer];
    if (invocation) {
        NSIndexPath *origPath = [streamAdPlacer originalIndexPathForAdjustedIndexPath:indexPath];
        [invocation setArgument:&(arg1) atIndex:2];
        [invocation setArgument:&(arg2) atIndex:3];
        [invocation setArgument:&(origPath) atIndex:4];
        [invocation invoke];
    }
    return invocation;
}

+ (BOOL)boolResultForInvocation:(NSInvocation *)invocation defaultValue:(BOOL)defaultReturnValue
{
    if (!invocation) {
        return defaultReturnValue;
    }
    
    BOOL returnValue;
    [invocation getReturnValue:&returnValue];
    return returnValue;
}

+ (id)resultForInvocation:(NSInvocation *)invocation defaultValue:(id)defaultReturnValue
{
    if (!invocation) {
        return defaultReturnValue;
    }
    
    __unsafe_unretained id returnValue;
    [invocation getReturnValue:&returnValue];
    return returnValue;
}

+ (NSInteger)integerResultForInvocation:(NSInvocation *)invocation defaultValue:(NSInteger)defaultReturnValue
{
    if (!invocation) {
        return defaultReturnValue;
    }
    
    NSInteger returnValue;
    [invocation getReturnValue:&returnValue];
    return returnValue;
}

@end
