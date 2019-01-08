//
//  PMAVPlayer.h
//
//  Created by Arvind Bharadwaj on 12/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@class PMAVPlayer;

@protocol PMAVPlayerDelegate <NSObject>

- (void)avPlayer:(PMAVPlayer *)player didError:(NSError *)error withMessage:(NSString *)message;

- (void)avPlayer:(PMAVPlayer *)player playbackTimeDidProgress:(NSTimeInterval)currentPlaybackTime;

- (void)avPlayerDidFinishPlayback:(PMAVPlayer *)player;

- (void)avPlayerDidRecoverFromStall:(PMAVPlayer *)player;

- (void)avPlayerDidStall:(PMAVPlayer *)player;

@end

@interface PMAVPlayer : AVPlayer

// Indicates the duration of the player item.
@property (nonatomic, readonly) NSTimeInterval currentItemDuration;

// Returns the current time of the current player item.
@property (nonatomic, readonly) NSTimeInterval currentPlaybackTime;

- (id)initWithDelegate:(id<PMAVPlayerDelegate>)delegate playerItem:(AVPlayerItem *)playerItem;

- (void)dispose;

@end
