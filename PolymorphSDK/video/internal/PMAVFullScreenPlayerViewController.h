//
//  PMAVFullscreenPlayerViewController.h
//
//  Created by Arvind Bharadwaj on 15/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PMPlayerViewController;
@class PMPlayerView;
@class PMAVFullscreenPlayerViewController;

@protocol PMAVFullscreenPlayerViewControllerDelegate <NSObject>

- (void)playerDidProgressToTime:(NSTimeInterval)playbackTime totalTime:(NSTimeInterval)totalTime;

@end

typedef void (^PMAVFullscreenPlayerViewControllerDismissBlock)(UIView *originalParentView);

@interface PMAVFullscreenPlayerViewController : UIViewController

@property (nonatomic) PMPlayerView *playerView;
@property (nonatomic) BOOL isPresented;

@property (nonatomic, weak) id<PMAVFullscreenPlayerViewControllerDelegate> delegate;

- (instancetype)initWithVideoPlayer:(PMPlayerViewController *)playerController nativeAssets:(NSDictionary *)nativeAssets dismissBlock:(PMAVFullscreenPlayerViewControllerDismissBlock)dismiss;

- (void)dispose;
@end
