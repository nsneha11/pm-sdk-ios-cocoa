//
//  PMAVPlayer.m
//
//  Created by Arvind Bharadwaj on 12/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "PMAVPlayer.h"
#import "Logging.h"
#import "IANTimer.h"
#import "InstanceProvider.h"

static CGFloat const kAVPlayerTimerInterval = 0.1f;

static NSString * const PMAVPlayerItemLoadErrorTemplate = @"Loading player item at %@ failed.";

@interface PMAVPlayer()

@property (nonatomic, weak, readonly) id<PMAVPlayerDelegate> delegate;

@property (nonatomic, copy) NSURL *mediaURL;
@property (nonatomic) IANTimer *playbackTimer;
@property (nonatomic) CMTime lastContinuousPlaybackCMTime;
@property (nonatomic) BOOL playbackDidStall;

@end

@implementation PMAVPlayer

- (id)initWithDelegate:(id<PMAVPlayerDelegate>)delegate playerItem:(AVPlayerItem *)playerItem
{
    if (playerItem && delegate) {
        self = [super initWithPlayerItem:playerItem];
        if (self) {
            _delegate = delegate;
        }
        return self;
    } else {
        return nil;
    }
}

- (void)dealloc
{
    [self dispose];
}

#pragma mark - controls of AVPlayer

- (void)play
{
    [super play];
    [self startTimeObserver];
    LogDebug(@"start playback");
}

- (void)pause
{
    [super pause];
    [self stopTimeObserver];
    LogDebug(@"playback paused");
}

- (void)setMuted:(BOOL)muted
{
    if ([[self superclass] instancesRespondToSelector:@selector(setMuted:)]) {
        [super setMuted:muted];
    } else {
        if (muted) {
            [self setAudioVolume:0];
        } else {
            [self setAudioVolume:1];
        }
    }
}

// iOS 6 doesn't have muted for avPlayerItem. Use volume to control mute/unmute
- (void)setAudioVolume:(float)volume
{
    NSArray *audioTracks = [self.currentItem.asset tracksWithMediaType:AVMediaTypeAudio];
    NSMutableArray *allAudioParams = [NSMutableArray array];
    for (AVAssetTrack *track in audioTracks) {
        AVMutableAudioMixInputParameters *audioInputParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
        [audioInputParams setVolume:volume atTime:kCMTimeZero];
        [audioInputParams setTrackID:[track trackID]];
        [allAudioParams addObject:audioInputParams];
    }
    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
    [audioMix setInputParameters:allAudioParams];
    [self.currentItem setAudioMix:audioMix];
}

#pragma mark - Timer

- (void)startTimeObserver
{
    // Use custom timer to check for playback time changes and stall detection, since there are bugs
    // in the AVPlayer time observing API that can cause crashes. Also, the AVPlayerItem stall notification
    // does not always report accurately.
    if (_playbackTimer == nil) {
        _playbackTimer = [IANTimer timerWithTimeInterval:kAVPlayerTimerInterval target:self selector:@selector(timerTick) repeats:YES];
        // Add timer to main run loop with common modes to allow the timer to tick while user is scrolling.
        _playbackTimer.runLoopMode = NSRunLoopCommonModes;
        [_playbackTimer scheduleNow];
        _lastContinuousPlaybackCMTime = kCMTimeZero;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidFinish) name:AVPlayerItemDidPlayToEndTimeNotification object:self.currentItem];
    } else {
        [_playbackTimer resume];
    }
}

- (void)timerTick
{
    if (!self.currentItem || self.currentItem.error != nil) {
        [self stopTimeObserver];
        NSError *error = nil;
        NSString *errorMessage = nil;
        if (self.currentItem) {
            error = self.currentItem.error;
            errorMessage = self.currentItem.error.description ?: self.currentItem.errorLog.description;
        } else {
            errorMessage = [NSString stringWithFormat:PMAVPlayerItemLoadErrorTemplate, self.mediaURL];
        }
        
        if ([self.delegate respondsToSelector:@selector(avPlayer:didError:withMessage:)]) {
            [self.delegate avPlayer:self didError:error withMessage:errorMessage];
        }
        LogInfo(@"avplayer experienced error: %@", errorMessage);
    } else {
        CMTime currentCMTime = self.currentTime;
        int32_t result = CMTimeCompare(currentCMTime, self.lastContinuousPlaybackCMTime);
        // finished or stalled
        if (result == 0) {
            NSTimeInterval duration = self.currentItemDuration;
            NSTimeInterval currentPlaybackTime = self.currentPlaybackTime;
            if (!isnan(duration) && !isnan(currentPlaybackTime) && duration > 0 && currentPlaybackTime > 0) {
                [self avPlayerDidStall];
            }
        } else {
            self.lastContinuousPlaybackCMTime = currentCMTime;
            if (result > 0) {
                NSTimeInterval currentPlaybackTime = self.currentPlaybackTime;
                if (!isnan(currentPlaybackTime) && isfinite(currentPlaybackTime)) {
                    // There are bugs in AVPlayer that causes the currentTime to be negative
                    if (currentPlaybackTime < 0) {
                        currentPlaybackTime = 0;
                    }
                    [self avPlayer:self playbackTimeDidProgress:currentPlaybackTime];
                }
            }
        }
        
    }
}

- (void)stopTimeObserver
{
    [_playbackTimer pause];
    LogDebug(@"AVPlayer timer stopped");
}

#pragma mark - disconnect/reconnect handling
//- (void)checkNetworkStatus:(NSNotification *)notice
//{
//    NetworkStatus remoteHostStatus = [self.reachability currentReachabilityStatus];
//    
//    if (remoteHostStatus == NotReachable) {
//        if (!self.rate) {
//            [self pause];
//            if ([self.delegate respondsToSelector:@selector(avPlayerDidStall:)]) {
//                [self.delegate avPlayerDidStall:self];
//            }
//        }
//    } else {
//        if (!self.rate) {
//            [self play];
//        }
//    }
//}

#pragma mark - AVPlayer state changes

- (void)avPlayer:(PMAVPlayer *)player playbackTimeDidProgress:(NSTimeInterval)currentPlaybackTime
{
    if (self.playbackDidStall) {
        self.playbackDidStall = NO;
        if ([self.delegate respondsToSelector:@selector(avPlayerDidRecoverFromStall:)]) {
            [self.delegate avPlayerDidRecoverFromStall:self];
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(avPlayer:playbackTimeDidProgress:)]) {
        [self.delegate avPlayer:self playbackTimeDidProgress:currentPlaybackTime];
    }
}

- (void)avPlayerDidStall
{
    // Only call delegate methods once per stall cycle.
    if (!self.playbackDidStall && [self.delegate respondsToSelector:@selector(avPlayerDidStall:)]) {
        [self.delegate avPlayerDidStall:self];
    }
    self.playbackDidStall = YES;
}

- (void)playbackDidFinish
{
    // Make sure we stop time observing once we know we've done playing.
    [self stopTimeObserver];
    if ([self.delegate respondsToSelector:@selector(avPlayerDidFinishPlayback:)]) {
        [self.delegate avPlayerDidFinishPlayback:self];
    }
    LogDebug(@"playback finished");
}

- (void)dispose
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self stopTimeObserver];
//    [self.reachability stopNotifier];
    if (_playbackTimer) {
        [_playbackTimer invalidate];
        _playbackTimer = nil;
    }
    
    // Cancel preroll after time observer is removed,
    // otherwise an NSInternalInconsistencyException may be thrown and crash on
    // [AVCMNotificationDispatcher _copyAndRemoveListenerAndCallbackForWeakReferenceToListener:callback:name:object:],
    // depends on timing.
    [self cancelPendingPrerolls];
}


#pragma mark - getter

- (NSTimeInterval)currentItemDuration
{
    NSTimeInterval duration = CMTimeGetSeconds(self.currentItem.duration);
    return (isfinite(duration)) ? duration : NAN;
}

- (NSTimeInterval)currentPlaybackTime
{
    NSTimeInterval currentTime = CMTimeGetSeconds(self.currentTime);
    return (isfinite(currentTime)) ? currentTime : NAN;
}
@end
