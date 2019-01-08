//
//  JWPlayerView.h
//
//  Created by Arvind Bharadwaj on 28/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface JWPlayerView : UIView 

@property(nonatomic, strong) UIWebView *webView;

- (void)loadVideoWithURL:(NSURL *)videoURL;

@end
