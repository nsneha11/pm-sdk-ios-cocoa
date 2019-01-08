//
//  PMAVPlayerView.h
//
//  Created by Arvind Bharadwaj on 12/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AVPlayer;

@interface PMAVPlayerView : UIView

@property (nonatomic) AVPlayer *player;
@property (nonatomic) NSString *videoGravity;

@end
