//
//  JWPlayerView.m
//
//  Created by Arvind Bharadwaj on 28/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "JWPlayerView.h"

@interface JWPlayerView() <UIWebViewDelegate>

@end


@implementation JWPlayerView

- (void)loadVideoWithURL:(NSURL *)videoURL
{
    [self loadWebViewIntoView];
}

- (void)dealloc
{
    [self removeWebView];
}

- (void)loadWebViewIntoView
{
    // Remove the existing webView to reset any state
    [self.webView removeFromSuperview];
    _webView = [self createNewWebView];
    [self addSubview:self.webView];
    
    [self.webView loadHTMLString:[JWPlayerView getHTMLCode] baseURL:nil];
    [self.webView setDelegate:self];
    self.webView.allowsInlineMediaPlayback = YES;
    self.webView.mediaPlaybackRequiresUserAction = NO;
}

- (UIWebView *)createNewWebView {
    UIWebView *webView = [[UIWebView alloc] initWithFrame:self.bounds];
    webView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    webView.scrollView.scrollEnabled = NO;
    webView.scrollView.bounces = NO;
    
    return webView;
}

- (void)removeWebView {
    [self.webView removeFromSuperview];
    self.webView = nil;
}

+ (NSString *)getHTMLCode
{
    return @"<!DOCTYPE html> <html> <head> <style> body{ margin:0px 0px 0px 0px; } </style> <script src='https://www.youtube.com/iframe_api'></script> <script src='https://content.jwplatform.com/libraries/z9aYFUOg.js' ></script> </head> <body> <div id='vidContainer'>Loading the player...</div> <script type='text/javascript'> var playerInstance = jwplayer('vidContainer'); playerInstance.setup({ file: 'https://content.jwplatform.com/videos/HkauGhRi-640.mp4', width: 300, height: 120 }); </script> </body> </html>";
}

#pragma mark - UIWebViewDelegate
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
//    NSLog(@"WebView loaded Video");
}

@end
