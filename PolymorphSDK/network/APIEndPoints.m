//
//  APIEndPoints.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 21/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "APIEndPoints.h"


@implementation APIEndPoints

static BOOL sUsesHTTPS = true;

+ (void)setUsesHTTPS:(BOOL)usesHTTPS
{
    sUsesHTTPS = usesHTTPS;
}

+ (NSString *)APIScheme
{
    return sUsesHTTPS ? @"https" : @"http";
}

+ (NSString *)baseURL
{
    return [NSString stringWithFormat:@"%@://%@",
            [[self class] APIScheme], ADSNATIVE_ADREQUEST_HOSTNAME];
}

+ (NSString *)baseURLStringWithPath:(NSString *)path fetchConfigs:(BOOL)isConfigCall testing:(BOOL)testing
{
    if (isConfigCall) {
        
    return [NSString stringWithFormat:@"%@://%@%@",
            [[self class] APIScheme],
            testing ? ADSNATIVE_CONFIG_HOSTNAME_FOR_TESTING : ADSNATIVE_CONFIG_HOSTNAME ,
            path];
    } else {
        return [NSString stringWithFormat:@"%@://%@%@",
                [[self class] APIScheme],
                testing ? ADSNATIVE_ADREQUEST_HOSTNAME_FOR_TESTING : ADSNATIVE_ADREQUEST_HOSTNAME,
                path];
    }
}

+ (NSString *)baseURLStringForApiMediationForTesting:(BOOL)testing
{
    return [NSString stringWithFormat:@"%@://%@",
            [[self class] APIScheme],
            testing ? ADSNATIVE_MEDITAION_HOSTNAME_FOR_TESTING : ADSNATIVE_MEDIATION_HOSTNAME];
}

@end
