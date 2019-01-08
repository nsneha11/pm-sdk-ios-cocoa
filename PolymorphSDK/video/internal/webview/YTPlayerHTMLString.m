//
//  YTPlayerHTMLString.m
//
//  Created by Arvind Bharadwaj on 29/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "YTPlayerHTMLString.h"

@implementation YTPlayerHTMLString

+ (NSString *)getYTPlayerHTMLCode
{
    return @"<!DOCTYPE html> <html> <head> <style> body { margin: 0; width:100%%; height:100%%; background-color:#000000 !important; } html { width:100%%; height:100%%; background-color:#000000 !important; } .embed-container iframe, .embed-container object, .embed-container embed { position: absolute; top: 0; left: 0; width: 100%% !important; height: 100%% !important; background-color:#000000 !important; } </style> </head> <body> <div class='embed-container'> <div id='player'></div> </div> <script src=\"https://www.youtube.com/iframe_api\"></script> <script> var player; var error = false; YT.ready(function() { player = new YT.Player('player', %@); player.setSize(window.innerWidth, window.innerHeight); window.location.href = 'ytplayer://onYouTubeIframeAPIReady'; function getCurrentTime() { var state = player.getPlayerState(); if (state == YT.PlayerState.PLAYING) { time = player.getCurrentTime(); window.location.href = 'ytplayer://onPlayTime?data=' + time; } } window.setInterval(getCurrentTime, 500); }); function onReady(event) { window.location.href = 'ytplayer://onReady?data=' + event.data; } function onStateChange(event) { if (!error) { window.location.href = 'ytplayer://onStateChange?data=' + event.data; } else { error = false; } } function onPlaybackQualityChange(event) { window.location.href = 'ytplayer://onPlaybackQualityChange?data=' + event.data; } function onPlayerError(event) { if (event.data == 100) { error = true; } window.location.href = 'ytplayer://onError?data=' + event.data; } window.onresize = function() { player.setSize(window.innerWidth, window.innerHeight); } </script> </body> </html>";
}

@end
