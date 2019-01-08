//
//  IANAdServerURLBuilder.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "IANAdServerURLBuilder.h"
#import "Constants.h"
#import "APIEndPoints.h"
#import "IANIdentityProvider.h"
#import "GeoLocationProvider.h"
#import "InstanceProvider.h"
#import "IANReachability.h"
#import "Logging.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
@interface IANAdServerURLBuilder ()

+ (NSString *)queryParameterForKeywords:(NSArray *)keywords;
+ (NSString *)queryParameterForDNT;
//+ (NSString *)queryParameterForConnectionType;
+ (NSString *)queryParameterForDesiredAdAssets:(NSArray *)assets;
+ (BOOL)advertisingTrackingEnabled;
+ (NSString *)queryParameterForUserAgent;
+ (NSString *)queryParamForAppSpecs;
+ (NSString *)queryParamsForDeviceDimensions;
+ (NSString *)carrierName;

+ (NSString *)postQueryParameterForKeywords:(NSArray *)keywords;
//+ (NSString *)queryParameterForConnectionType;
+ (NSString *)postQueryParameterForDesiredAdAssets:(NSArray *)assets;
+ (NSString *)postQueryParameterForUserAgent;
+ (NSDictionary *)postQueryParamForAppSpecs;
+ (NSNumber *)postQueryParameterForDNT;
+ (NSDictionary *)postQueryParameterForLocation:(CLLocation *)location;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation IANAdServerURLBuilder

+ (NSURL *)URLWithAdUnitID:(NSString *)adUnitID
                  keywords:(NSArray *)keywords
                   testing:(BOOL)testing
{
    return [self URLWithAdUnitID:adUnitID
                        keywords:keywords
                         version:AN_SDK_VERSION
                   desiredAssets:nil
                        location:nil
                         testing:testing];
}

+ (NSURL *)URLWithAdUnitID:(NSString *)adUnitID
                  keywords:(NSArray *)keywords
             desiredAssets:(NSArray *)assets
                  location:(CLLocation *)location
                   testing:(BOOL)testing
{
    return [self URLWithAdUnitID:adUnitID keywords:keywords version:AN_SDK_VERSION desiredAssets:assets location:location testing:testing];
}



+ (NSURL *)URLWithAdUnitID:(NSString *)adUnitID
                  keywords:(NSArray *)keywords
                   version:(NSString *)version
             desiredAssets:(NSArray *)assets
                  location:(CLLocation *)location
                   testing:(BOOL)testing
{
    //    NSString *URLString = [NSString stringWithFormat:@"%@?udid=%@&idfa=%@&zid=%@&sdk=%@&num_ads=1&app=true",
    //                           [APIEndPoints baseURLStringWithPath:ADSNATIVE_API_PATH_AD_REQUEST fetchConfigs:NO testing:testing],
    //                          [self getURLEncoded:[IANIdentityProvider identifier]],
    //                           [self getURLEncoded:[IANIdentityProvider identifier]],
    //                           [self getURLEncoded:adUnitID],
    //                           version];
    //
    //    URLString = [URLString stringByAppendingString:[self queryParameterForLocale]];
    //    URLString = [URLString stringByAppendingString:[self queryParameterForLocation:location]];
    //    URLString = [URLString stringByAppendingString:[self queryParameterForDNT]];
    //    URLString = [URLString stringByAppendingString:[self queryParamForAppSpecs]];
    //    URLString = [URLString stringByAppendingString:[self getConnectionType]];
    //    URLString = [URLString stringByAppendingString:[self queryParameterForUserAgent]];
    //    URLString = [URLString stringByAppendingString:[self queryParameterForKeywords:keywords]];
    //    URLString = [URLString stringByAppendingString:[self queryParamsForDeviceDimensions]];
    
    NSString *URLString = [NSString stringWithFormat:@"%@",
                           [APIEndPoints baseURLStringWithPath:ADSNATIVE_API_PATH_AD_REQUEST fetchConfigs:NO testing:NO]];
    
    NSDictionary *device = @{@"ua": [self postQueryParameterForUserAgent],
                             @"ip": [self deviceIPAddress],//@"138.197.58.55",
                             @"h" : @([UIScreen mainScreen].bounds.size.height),
                             @"w" : @([UIScreen mainScreen].bounds.size.width),
//                             @"ort" : @"v",
                             @"ct" : [self getConnectionType],
                             @"carrier" : [self carrierName],
                             @"al" : [self postQueryParameterForLocale]};
    
    NSDictionary *user = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                          [self deviceUUID], @"uuid",
                          [self deviceUUID], @"idfa",
                          //                          @29, @"age",
                          //                          @"m", @"gender",
                          [self postQueryParameterForDNT], @"dnt",
                          nil];
    
    NSMutableDictionary *tmp = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                      [self postQueryParamForAppSpecs], @"app",
                                      device, @"device",
                                      user, @"user",
                                      adUnitID, @"zid",
                                      //                         @1, @"fetch_num",
                                      //                         @false, @"s2s_tracking",
                                      [self postQueryParameterForKeywords:keywords], @"hb",
                                      //@"c9cujyr756hdg6537:1234", @"pchain",
                                      @1, @"is_sdk",
                                [self postQueryParameterForLocation:location], @"geo",
                                      nil];
    
  
    [[NSUserDefaults standardUserDefaults] setObject:tmp forKey:@"POST_DICT"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    return [NSURL URLWithString:URLString];
    
}


#pragma mark - query params
+ (NSString *)deviceUUID
{
    if([[NSUserDefaults standardUserDefaults] objectForKey:[[NSBundle mainBundle] bundleIdentifier]])
        return [[NSUserDefaults standardUserDefaults] objectForKey:[[NSBundle mainBundle] bundleIdentifier]];
    
    @autoreleasepool {
        
        CFUUIDRef uuidReference = CFUUIDCreate(nil);
        CFStringRef stringReference = CFUUIDCreateString(nil, uuidReference);
        NSString *uuidString = (__bridge NSString *)(stringReference);
        [[NSUserDefaults standardUserDefaults] setObject:uuidString forKey:[[NSBundle mainBundle] bundleIdentifier]];
        [[NSUserDefaults standardUserDefaults] synchronize];
        CFRelease(uuidReference);
        CFRelease(stringReference);
        return uuidString;
    }
}

+ (NSString *)queryParamsForDeviceDimensions
{
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenWidth = screenRect.size.width;
    CGFloat screenHeight = screenRect.size.height;
    
    return [NSString stringWithFormat:@"&screen_width=%.2f&screen_height=%.2f", screenWidth, screenHeight];
}

+ (NSString *)queryParameterForKeywords:(NSArray *)keywords
{
    NSMutableString *keywordParams = [NSMutableString string];
    
    for (NSString *keyword in keywords) {
        NSString *encodedKeyword = [keyword stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [keywordParams appendFormat:@"&kw=%@",encodedKeyword];
    }
    return keywordParams;
}

+ (NSString *)queryParameterForDNT
{
    return [self advertisingTrackingEnabled] ? @"&dnt=0" : @"&dnt=1";
}

//not using for now
+ (NSString *)queryParameterForDesiredAdAssets:(NSArray *)assets
{
    NSString *concatenatedAssets = [assets componentsJoinedByString:@","];
    return [concatenatedAssets length] ? [NSString stringWithFormat:@"&assets=%@", concatenatedAssets] : @"";
}

+ (BOOL)advertisingTrackingEnabled
{
    return [IANIdentityProvider advertisingTrackingEnabled];
}

+ (NSString *)queryParameterForUserAgent {
    return [NSString stringWithFormat:@"&ua=%@",[self getURLEncoded:[[[UIWebView alloc] init] stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"]]];
}

+ (NSString *)queryParameterForLocale {
    NSString* locale = [[[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"] objectAtIndex:0];
    return [NSString stringWithFormat:@"&al=%@",[self getURLEncoded:locale]];
}


+ (NSString *)queryParameterForLocation:(CLLocation *)location
{
    NSString *result = @"";
    
    CLLocation *bestLocation = location;
    CLLocation *locationFromProvider = [[[InstanceProvider sharedProvider] sharedGeoLocationProvider] lastKnownLocation];
    
    if (locationFromProvider) {
        bestLocation = locationFromProvider;
    }
    
    if (bestLocation && bestLocation.horizontalAccuracy >= 0) {
        result = [NSString stringWithFormat:@"&ll=%@,%@",
                  [NSNumber numberWithDouble:bestLocation.coordinate.latitude],
                  [NSNumber numberWithDouble:bestLocation.coordinate.longitude]];
        
        if (bestLocation.horizontalAccuracy) {
            result = [result stringByAppendingFormat:@"&lla=%@",
                      [NSNumber numberWithDouble:bestLocation.horizontalAccuracy]];
        }
        
        if (bestLocation == locationFromProvider) {
            result = [result stringByAppendingString:@"&llsdk=1"];
        }
        
        //        NSTimeInterval locationLastUpdatedMillis = [[NSDate date] timeIntervalSinceDate:bestLocation.timestamp] * 1000.0;
        //
        //        result = [result stringByAppendingFormat:@"&llf=%.0f", locationLastUpdatedMillis];
    }
    
    return result;
}

+ (NSString *)queryParamForAppSpecs
{
    NSString *result = @"";
    
    NSString *appId = [[[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"] componentsSeparatedByString:@"."] lastObject];
    
    result = [result stringByAppendingFormat:@"&bundle_id=%@",[[NSBundle mainBundle] bundleIdentifier]];
    
    result = [result stringByAppendingFormat:@"&app_id=%@",appId];
    
    result = [result stringByAppendingFormat:@"&app_name=%@",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]];
    
    return [result stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - helpers

+(NSString *)getConnectionType {
    IANReachability* reach = [IANReachability reachabilityForInternetConnection];
    NetworkStatus netStatus = [reach currentReachabilityStatus];
    NSString *reachability;
    switch (netStatus)
    {
        case NotReachable: {
            reachability = @"None";
            break;
        }
        case ReachableViaWWAN: {
            reachability = @"WWAN";
            break;
        }
        case ReachableViaWiFi: {
            reachability = @"Wifi";
            break;
        }
    }
    //return [NSString stringWithFormat:@"&bd=%@",[self getURLEncoded:reachability]];
    return [self getURLEncoded:reachability];
}

+ (NSString *)getURLEncoded:(NSString *)string {
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                 (CFStringRef)string,
                                                                                 NULL,
                                                                                 (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                                 kCFStringEncodingUTF8));
}



+ (NSString *)deviceIPAddress
{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    
                }
                
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
}

#pragma mark - POST queries

+ (NSNumber *)postQueryParameterForKeywords:(NSArray *)keywords
{
//    NSMutableString *keywordParams = [NSMutableString string];
    for (NSString *keyword in keywords) {
//        NSString *encodedKeyword = [keyword stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//        [keywordParams appendFormat:@"&kw=%@",encodedKeyword];
        if ([keyword  isEqual: @"&hb=1"]) {
            return @1;
        }
    }
    return @0;
}

+ (NSNumber *)postQueryParameterForDNT
{
    return [self advertisingTrackingEnabled] ? @0 : @1;
}


+ (NSString *) carrierName {
    CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [netinfo subscriberCellularProvider];
    NSLog(@"Carrier Name: %@", [carrier carrierName]);
    return carrier.carrierName == NULL ? @"verizon": carrier.carrierName;
}

//not using for now
+ (NSString *)postQueryParameterForDesiredAdAssets:(NSArray *)assets
{
    NSString *concatenatedAssets = [assets componentsJoinedByString:@","];
    return [concatenatedAssets length] ? [NSString stringWithFormat:@"&assets=%@", concatenatedAssets] : @"";
}

+ (NSString *)postQueryParameterForUserAgent {
    return [self getURLEncoded:[[[UIWebView alloc] init] stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"]];
}

+ (NSString *)postQueryParameterForLocale {
    NSString* locale = [[[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"] objectAtIndex:0];
    return [self getURLEncoded:locale];
}


+ (NSDictionary *)postQueryParameterForLocation:(CLLocation *)location
{
    NSDictionary *result;
    
    CLLocation *bestLocation = location;
    CLLocation *locationFromProvider = [[[InstanceProvider sharedProvider] sharedGeoLocationProvider] lastKnownLocation];
    
    if (locationFromProvider) {
        bestLocation = locationFromProvider;
    }
    
    if (bestLocation && bestLocation.horizontalAccuracy >= 0) {
        
        if (bestLocation.horizontalAccuracy && bestLocation == locationFromProvider) {
            
            result = @{@"lat": [NSNumber numberWithDouble:bestLocation.coordinate.latitude],
                       @"lon": [NSNumber numberWithDouble:bestLocation.coordinate.longitude],
                       @"lla": [NSNumber numberWithDouble:bestLocation.horizontalAccuracy],
                       @"loc_type": @1};
            //        result = [NSString stringWithFormat:@"&ll=%@,%@",
            //                  [NSNumber numberWithDouble:bestLocation.coordinate.latitude],
            //                  [NSNumber numberWithDouble:bestLocation.coordinate.longitude]];
        }
        //
        else if (bestLocation.horizontalAccuracy) {
            result = @{@"lat": [NSNumber numberWithDouble:bestLocation.coordinate.latitude],
                       @"lon": [NSNumber numberWithDouble:bestLocation.coordinate.longitude],
                       @"lla": [NSNumber numberWithDouble:bestLocation.horizontalAccuracy]};
        }
        //
        else if (bestLocation == locationFromProvider) {
            result = @{@"lat": [NSNumber numberWithDouble:bestLocation.coordinate.latitude],
                       @"lon": [NSNumber numberWithDouble:bestLocation.coordinate.longitude],
                       @"loc_type": @1};
        }
        
        //        NSTimeInterval locationLastUpdatedMillis = [[NSDate date] timeIntervalSinceDate:bestLocation.timestamp] * 1000.0;
        //
        //        result = [result stringByAppendingFormat:@"&llf=%.0f", locationLastUpdatedMillis];
        
        
        
        
        
    }
    
    return result;
}

+ (NSDictionary *)postQueryParamForAppSpecs
{
    NSDictionary *result;
    
    NSString *appId = [[[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"] componentsSeparatedByString:@"."] lastObject];
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    result = @{@"bnid": @[[[NSBundle mainBundle] bundleIdentifier]],
               @"app_id": appId,
               @"ver": version,
               //@"store_id": @102323235,
               };
    
    //    result[@"&bundle_id=%@"] = [[NSBundle mainBundle] bundleIdentifier]];
    //
    //    result = [result stringByAppendingFormat:@"&app_id=%@",appId];
    //
    //    result = [result stringByAppendingFormat:@"&app_name=%@",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]];
    
    return result;
}

@end
