//
//  PMMediaViewRenderer.h
//
//  Created by Arvind Bharadwaj on 15/12/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AdAdapter.h"

@interface PMMediaViewRenderer : NSObject

-(instancetype)initWithAdAdapter:(id<AdAdapter>)adAdapter;
-(void)layoutVideoIntoView:(UIView *)mediaView withViewController:(UIViewController *)viewController;
- (void)dispose;

@end
