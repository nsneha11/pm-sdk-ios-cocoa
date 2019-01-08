//
//  IANTimer.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 22/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "IANTimer.h"
#import "Logging.h"

@interface IANTimer ()
@property (nonatomic, assign) NSTimeInterval timeInterval;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSDate *pauseDate;
@property (nonatomic, assign) BOOL isPaused;
//@property (nonatomic, assign) NSTimeInterval secondsLeft;

@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector;

@end

@implementation IANTimer

+ (IANTimer *)timerWithTimeInterval:(NSTimeInterval)seconds
                            target:(id)target
                          selector:(SEL)aSelector
                           repeats:(BOOL)repeats
{
    IANTimer *timer = [[IANTimer alloc] init];
    timer.target = target;
    timer.selector = aSelector;
    timer.timer = [NSTimer timerWithTimeInterval:seconds
                                          target:timer
                                        selector:@selector(timerDidFire)
                                        userInfo:nil
                                         repeats:repeats];
    timer.timeInterval = seconds;
    timer.runLoopMode = NSDefaultRunLoopMode;
    return timer;
}

- (void)dealloc
{
    [self.timer invalidate];
}

- (void)timerDidFire
{
    SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(
        [self.target performSelector:self.selector withObject:nil]
    );
}

- (BOOL)scheduleNow
{
    if (![self.timer isValid]) {
        LogDebug(@"Could not schedule invalidated Timer (%p).", self);
        return NO;
    }
    
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:self.runLoopMode];
    return YES;
}

- (void)invalidate
{
    self.target = nil;
    self.selector = nil;
    [self.timer invalidate];
    self.timer = nil;
}

- (BOOL)isValid
{
    return [self.timer isValid];
}

- (BOOL)isScheduled
{
    if (!self.timer) {
        return NO;
    }
    CFRunLoopRef runLoopRef = [[NSRunLoop currentRunLoop] getCFRunLoop];
    CFArrayRef arrayRef = CFRunLoopCopyAllModes(runLoopRef);
    CFIndex count = CFArrayGetCount(arrayRef);
    
    for (CFIndex i = 0; i < count; ++i) {
        CFStringRef runLoopMode = CFArrayGetValueAtIndex(arrayRef, i);
        if (CFRunLoopContainsTimer(runLoopRef, (__bridge CFRunLoopTimerRef)self.timer, runLoopMode)) {
            CFRelease(arrayRef);
            return YES;
        }
    }
    
    CFRelease(arrayRef);
    return NO;
}

- (BOOL)pause
{
    NSTimeInterval secondsLeft;
    if (self.isPaused) {
        LogDebug(@"No-op: tried to pause a Timer (%p) that was already paused.", self);
        return NO;
    }
    
    if (![self.timer isValid]) {
        LogDebug(@"Cannot pause invalidated Timer (%p).", self);
        return NO;
    }
    
    if (![self isScheduled]) {
        LogDebug(@"No-op: tried to pause a Timer (%p) that was never scheduled.", self);
        return NO;
    }
    
    NSDate *fireDate = [self.timer fireDate];
    self.pauseDate = [NSDate date];
    secondsLeft = [fireDate timeIntervalSinceDate:self.pauseDate];
    if (secondsLeft <= 0) {
    LogWarn(@"A Timer was somehow paused after it was supposed to fire.");
    } else {
        LogDebug(@"Paused Timer (%p) %.1f seconds left before firing.", self, secondsLeft);
    }
    
    // Pause the timer by setting its fire date far into the future.
    [self.timer setFireDate:[NSDate distantFuture]];
    self.isPaused = YES;
    
    return YES;
}

- (BOOL)resume
{
    if (![self.timer isValid]) {
        LogDebug(@"Cannot resume invalidated Timer (%p).", self);
        return NO;
    }
    
    if (!self.isPaused) {
        LogDebug(@"No-op: tried to resume a Timer (%p) that was never paused.", self);
        return NO;
    }
    
    LogDebug(@"Resumed Timer (%p), should fire in %.1f seconds.", self.timeInterval);
    
    // Resume the timer.
    NSDate *newFireDate = [NSDate dateWithTimeInterval:self.timeInterval sinceDate:[NSDate date]];
    [self.timer setFireDate:newFireDate];
    
    if (![self isScheduled]) {
        [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:self.runLoopMode];
    }
    
    self.isPaused = NO;
    return YES;
}
@end
