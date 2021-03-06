//
//  PMClientAdPositions.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 16/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "PMAdPositions.h"

@interface PMClientAdPositions : PMAdPositions

+ (instancetype)positioning;

- (void)addFixedIndexPath:(NSIndexPath *)indexPath;

- (void)enableRepeatingPositionsWithInterval:(NSUInteger)interval;

@end
