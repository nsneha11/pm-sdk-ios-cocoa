//
//  ANWebViewPlayer.m
//
//  Created by Arvind Bharadwaj on 17/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "PMWebViewPlayer.h"
#import "YTPlayerView.h"
#import "JWPlayerView.h"
#import "AdAssets.h"
#import "PMImageDownloader.h"

@interface ANWebViewPlayer() <YTPlayerViewDelegate>

@property (nonatomic) NSDictionary *nativeAssets;
@property (nonatomic) BOOL isYTPlayer;

@property (nonatomic) YTPlayerView *ytPlayer;
@property (nonatomic) NSString *ytVideoId;

@property (nonatomic) JWPlayerView *jwPlayer;

@end

@implementation ANWebViewPlayer

- (instancetype)initWithNativeAssets:(NSDictionary *)nativeAssets
{
    self = [super init];
    if (self) {
        _nativeAssets = nativeAssets;
        
        //Determine whether youtube player or other based on embed url
        if ([[nativeAssets objectForKey:kNativeVideoEmbedTypeKey] caseInsensitiveCompare:@"youtube"] == NSOrderedSame) {
            _isYTPlayer = YES;
            
            self.ytVideoId = [self getYTVideoIdFromAssets:self.nativeAssets];
        }
        //for testing
//        _isYTPlayer = YES;
//        self.ytVideoId = @"M7lc1UVf-VE";
    }
    return self;
}

- (void)dispose
{
    if (_isYTPlayer) {
        [_ytPlayer removeFromSuperview];
        _ytPlayer = nil;
    }
}

- (UIView *)getPlayerView
{
    if (_isYTPlayer) {
        _ytPlayer = [[YTPlayerView alloc] init];
        NSDictionary *playerVars = @{
                                     @"enablejsapi" : @1,
                                     @"playsinline" : @1
                                     };
        _ytPlayer.delegate = self;
        [_ytPlayer loadWithVideoId:self.ytVideoId playerVars:playerVars];
        
        return _ytPlayer;
    } else {
        PMImageDownloader *image = [[PMImageDownloader alloc] init];
        UIImage *img = [image getCachedImageForURL:[NSURL URLWithString:[_nativeAssets objectForKey:kNativeMainImageKey]]];
        
        UIImageView *imageView = [[UIImageView alloc] initWithImage:img];
        
        image = nil;
        
        return imageView;
    }
    
}

#pragma mark - ANWebViewPlayer controls
- (void)playVideo
{
    if (_isYTPlayer) {
        [_ytPlayer playVideo];
    }
}

- (void)pauseVideo
{
    if (_isYTPlayer) {
        [_ytPlayer pauseVideo];
    }
}

#pragma mark - Internal
- (NSString *)getYTVideoIdFromAssets:(NSDictionary *)nativeAssets
{
    NSString *youtubeURL = [self getVideoUrlFromNativeAssets:nativeAssets];
    
//    youtubeURL = @"https://www.youtube.com/watch?v=pY9b6jgbNyc";
//    youtubeURL = @"http://www.youtube.com/embed/M7lc1UVf-VE";
    if  ([youtubeURL rangeOfString:@"watch"].length != 0) {
        
        if  ([youtubeURL rangeOfString:@"?"].length != 0) {
            youtubeURL = [youtubeURL substringFromIndex:[youtubeURL rangeOfString:@"?"].location+1];
            
            if ([youtubeURL rangeOfString:@"v="].length != 0) {
                youtubeURL = [youtubeURL substringFromIndex:[youtubeURL rangeOfString:@"v="].location+2];
                
                if ([youtubeURL rangeOfString:@"&"].length != 0) {
                    youtubeURL = [youtubeURL substringToIndex:[youtubeURL rangeOfString:@"&"].location];
                }
                return youtubeURL;
            }
        }
    } else if ([youtubeURL rangeOfString:@"embed/"].length != 0) {
        youtubeURL = [youtubeURL substringFromIndex:[youtubeURL rangeOfString:@"embed/"].location +6];
        
        if ([youtubeURL rangeOfString:@"?"].length != 0) {
            youtubeURL = [youtubeURL substringToIndex:[youtubeURL rangeOfString:@"?"].location];
        }
        return youtubeURL;
    }
    
    self.isYTPlayer = NO;
    return nil;
}

- (NSString *)getVideoUrlFromNativeAssets:(NSDictionary *)nativeAssets
{
    NSSet *sources = [nativeAssets objectForKey:kNativeVideoSourcesKey];
    for (NSString *videoUrl in sources) {
        if ([videoUrl rangeOfString:@"youtube"].length > 0) {
            return videoUrl;
        }
    }
    return nil;
}

#pragma mark - YTPlayerViewDelegate
- (void)playerViewDidBecomeReady:(YTPlayerView *)playerView
{
    if ([self.delegate respondsToSelector:@selector(webViewPlayerReadyToPlay)]) {
        [self.delegate webViewPlayerReadyToPlay];
    }
}

- (void)playerView:(YTPlayerView *)playerView didPlayTime:(float)playTime
{
    if ([self.delegate respondsToSelector:@selector(webViewPlayerDidProgressToTime:withTotalTime:)]) {
        [self.delegate webViewPlayerDidProgressToTime:playTime withTotalTime:playerView.duration];
    }
}

- (void)playerView:(YTPlayerView *)playerView didChangeToState:(YTPlayerState)state
{
    self.webPlayerState = kWebPlayerStateUnknown;
    
    if (state == kYTPlayerStatePlaying) {
        self.webPlayerState = kWebPlayerStatePlaying;
        
        if ([self.delegate respondsToSelector:@selector(webViewPlayerDidPlay)]) {
            [self.delegate webViewPlayerDidPlay];
        }
        
    } else if (state == kYTPlayerStatePaused) {
        self.webPlayerState = kWebPlayerStatePaused;
        
        if ([self.delegate respondsToSelector:@selector(webViewPlayerDidPause)]) {
            [self.delegate webViewPlayerDidPause];
        }
        
    } else if (state == kYTPlayerStateEnded) {
        self.webPlayerState = kWebPlayerStateEnded;
        
        if ([self.delegate respondsToSelector:@selector(webViewPlayerDidFinishPlayback)]) {
            [self.delegate webViewPlayerDidFinishPlayback];
        }
        
    } else if (state == kYTPlayerStateUnstarted) {
        self.webPlayerState = kWebPlayerStateUnstarted;
    }
}
@end
