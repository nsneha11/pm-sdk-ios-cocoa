//
//  SDKConfigs.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 28/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "SDKConfigs.h"
#import "PMClientAdPositions.h"
#import "Constants.h"

const NSString *kDefaultPlayButtonImageURL = @"http://cdn.adsnative.com/static/img/common/AN_Play-Icon_128x128.png";
const NSString *kDefaultCloseButtonImageURL = @"http://cdn.adsnative.com/static/img/common/AN_close-Icon_128x128.png";
const NSString *kDefaultExpandButtonImageURL = @"http://cdn.adsnative.com/static/img/common/AN_expand-Icon_128x128.png";
const float kDefaultPercentVisibleForAutoplay = 50.0f;
const float kDefaultBiddingInterval = 0.05f;
 const float kDefaultRefreshInterval = DEFAULT_PMBANNER_REFRESH_INTERVAL;

@implementation SDKConfigs

-(instancetype) init
{
    self = [super init];
    if(self) {
        self.positions = [PMClientAdPositions positioning];
    }
    return self;
}

+ (instancetype)populateWithDefaults
{
    SDKConfigs *defaultConfigs = [[SDKConfigs alloc] init];
    
    defaultConfigs.closeButtonImageURL = (NSString *)kDefaultCloseButtonImageURL;
    defaultConfigs.playButtonImageURL = (NSString *)kDefaultPlayButtonImageURL;
    defaultConfigs.expandButtonImageURL = (NSString *)kDefaultExpandButtonImageURL;
    defaultConfigs.percentVisibleForAutoplay = (float)kDefaultPercentVisibleForAutoplay;
    
    PMClientAdPositions *positions = [PMClientAdPositions positioning];
    defaultConfigs.positions = positions;
    
    defaultConfigs.biddingInterval = (float)kDefaultBiddingInterval;
    
    defaultConfigs.refreshInterval = (int)kDefaultRefreshInterval;
    
    return defaultConfigs;
}

- (void)populateWithDefaultVideoAssets
{
    self.closeButtonImageURL = (NSString *)kDefaultCloseButtonImageURL;
    self.playButtonImageURL = (NSString *)kDefaultPlayButtonImageURL;
    self.expandButtonImageURL = (NSString *)kDefaultExpandButtonImageURL;
}
@end
