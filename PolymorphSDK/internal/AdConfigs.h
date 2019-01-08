//
//  AdConfigs.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 24/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AdConfigs : NSObject

@property (nonatomic, strong) NSArray *clickTrackers;
@property (nonatomic, strong) NSArray *impressionTrackers;
@property (nonatomic, strong) NSArray *viewabilityTrackers;
//No-Fill will be present only for network objects
@property (nonatomic, strong) NSArray *noFillTrackers;
@property (nonatomic, assign) Class customEventClass;
@property (nonatomic, strong) NSDictionary *customEventClassData;
@property (nonatomic, strong) NSString *adtype;

- (id)initWithHeaders:(NSDictionary *)headers data:(NSData *)data;

@end
