//
//  AdRequest+AdSource.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 24/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "AdRequest.h"

@interface AdRequest (AdSource)

- (void)startForAdSequence:(NSInteger)adSequence withCompletionHandler:(AdRequestHandler)handler;

@end
