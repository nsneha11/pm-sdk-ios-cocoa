//
//  ANWebViewPlayer.h
//
//  Created by Arvind Bharadwaj on 17/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

/** These enums represent the state of the current video player. */
typedef NS_ENUM(NSInteger, WebPlayerState) {
    kWebPlayerStateUnstarted,
    kWebPlayerStateEnded,
    kWebPlayerStatePlaying,
    kWebPlayerStatePaused,
    kWebPlayerStateUnknown
};

@protocol PMWebViewPlayerDelegate <NSObject>

@optional
- (void)webViewPlayerReadyToPlay;
- (void)webViewPlayerDidPlay;
- (void)webViewPlayerDidPause;
- (void)webViewPlayerDidProgressToTime:(NSTimeInterval)playbackTime withTotalTime:(NSTimeInterval)totalTime;
- (void)webViewPlayerDidFinishPlayback;

@end

@interface ANWebViewPlayer : NSObject

@property (nonatomic,weak) id<PMWebViewPlayerDelegate> delegate;
@property (nonatomic) WebPlayerState webPlayerState;

- (instancetype)initWithNativeAssets:(NSDictionary *)nativeAssets;
- (UIView *)getPlayerView;

#pragma mark - ANWebViewPlayer controls
- (void)playVideo;
- (void)pauseVideo;

- (void)dispose;
@end
