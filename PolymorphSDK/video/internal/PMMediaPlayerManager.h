//
//  PMMediaPlayerManager.h
//
//  Created by Arvind Bharadwaj on 15/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface PMMediaPlayerManager : NSObject

@property (nonatomic) UIViewController *currentPlayerViewController;

+ (PMMediaPlayerManager *)sharedInstance;
- (void)disposePlayerViewController;

- (UIViewController *)playerViewControllerWithAdAssets:(NSDictionary *)nativeAssets;

@end
