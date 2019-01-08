//
//  PMAdPositions.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 16/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "PMAdPositions.h"

@interface PMAdPositions()

@property (nonatomic,strong) NSMutableOrderedSet *fixedPositions;

@end


@implementation PMAdPositions

- (instancetype) init
{
    self = [super init];
    if(self) {
        _fixedPositions = [[NSMutableOrderedSet alloc] init];
    }
    return self;
}

- (instancetype) copyWithZone:(NSZone *)zone
{
    PMAdPositions *newPositioning = [[[self class] allocWithZone:zone] init];
    newPositioning.repeatingInterval = self.repeatingInterval;
    newPositioning.fixedPositions = [self.fixedPositions copyWithZone:zone];
    
    return newPositioning;
}
@end
