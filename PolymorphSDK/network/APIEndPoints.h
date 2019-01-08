//
//  APIEndPoints.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 21/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>

#define ADSNATIVE_ADREQUEST_HOSTNAME                 @"api.adsnative.com"
#define ADSNATIVE_ADREQUEST_HOSTNAME_FOR_TESTING     @"demo4180563.mockable.io"

#define ADSNATIVE_API_PATH_AD_REQUEST               @"/v1/ad.json"

#define ADSNATIVE_CONFIG_HOSTNAME                   @"api.adsnative.com"
#define ADSNATIVE_CONFIG_HOSTNAME_FOR_TESTING       @"demo6288954.mockable.io"
#define ADSNATIVE_API_PATH_NATIVE_CONFIGS           @"/v1/sdk/configs.json"

#define ADSNATIVE_MEDIATION_HOSTNAME                @"mediation.adsnative.com/request.json"
#define ADSNATIVE_MEDITAION_HOSTNAME_FOR_TESTING    @"kp.local/request.json"

@interface APIEndPoints : NSObject

+ (NSString *)baseURL;
+ (void)setUsesHTTPS:(BOOL)usesHTTPS;
+ (NSString *)baseURLStringWithPath:(NSString *)path fetchConfigs:(BOOL)isConfigCall testing:(BOOL)testing;
+ (NSString *)baseURLStringForApiMediationForTesting:(BOOL)testing;
@end
