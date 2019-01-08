//
//  PMClientAdPositions.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 16/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "PMClientAdPositions.h"
#import "Logging.h"

@implementation PMClientAdPositions

+ (instancetype)positioning
{
    return [[self alloc] init];
}

- (void)addFixedIndexPath:(NSIndexPath *)indexPath
{
    [self.fixedPositions addObject:indexPath];
}

- (void)enableRepeatingPositionsWithInterval:(NSUInteger)interval
{
    if (interval > 1) {
        self.repeatingInterval = interval;
    } else {
        LogWarn(@"Repeating positions will not be enabled: The interval must be greater than 1");
    }
}

@end
