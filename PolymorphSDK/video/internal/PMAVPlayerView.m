//
//  PMAVPlayerView.m
//
//  Created by Arvind Bharadwaj on 12/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "PMAVPlayerView.h"
#import <AVFoundation/AVFoundation.h>

@implementation PMAVPlayerView

+ (Class)layerClass
{
    return [AVPlayerLayer class];
}

- (AVPlayer *)player
{
    AVPlayerLayer *playerLayer = (AVPlayerLayer *)self.layer;
    return playerLayer.player;
}

- (void)setPlayer:(AVPlayer *)player
{
    AVPlayerLayer *playerLayer = (AVPlayerLayer *)self.layer;
    playerLayer.player = player;
}

- (NSString *)videoGravity
{
    AVPlayerLayer *playerLayer = (AVPlayerLayer *)self.layer;
    return playerLayer.videoGravity;
}

- (void)setVideoGravity:(NSString *)videoGravity
{
    AVPlayerLayer *playerLayer = (AVPlayerLayer *)self.layer;
    playerLayer.videoGravity = videoGravity;
}

@end
