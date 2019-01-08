//
//  AdSourceDelegate.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AdSource;

@protocol AdSourceDelegate <NSObject>

- (void)adSourceDidFinishRequest: (AdSource *)source;

@end
