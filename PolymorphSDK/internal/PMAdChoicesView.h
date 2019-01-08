//
//  PMAdChoicesView.h
//  Sample App
//
//  Created by Arvind Bharadwaj on 03/09/18.
//  Copyright © 2018 AdsNative. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PMAdChoicesViewDelegate;

@interface PMAdChoicesView : UIImageView

- (instancetype)initWithPrivacyInfo:(NSDictionary *)info;
@property (nonatomic,weak) id<PMAdChoicesViewDelegate> delegate;

- (instancetype)getPMAdChoicesView;
@end


@protocol PMAdChoicesViewDelegate<NSObject>

@optional
- (void)adChoicesWillLeaveApplication;
@end
