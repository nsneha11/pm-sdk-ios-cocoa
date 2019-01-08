//
//  IANIdentityProvider.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 21/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "IANIdentityProvider.h"
#import "Constants.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= AN_IOS_6_0
#import <AdSupport/AdSupport.h>
#endif

#define ADSNATIVE_IDENTIFIER_DEFAULTS_KEY @"com.adsnative.identifier"

@implementation IANIdentityProvider

+ (BOOL)deviceHasASIdentifierManager
{
    return !!NSClassFromString(@"ASIdentifierManager");
}

+ (NSString *)identifier
{
    return [self _identifier:NO];
}

+ (NSString *)obfuscatedIdentifier
{
    return [self _identifier:YES];
}

+ (NSString *)_identifier:(BOOL)obfuscate
{
    if ([self deviceHasASIdentifierManager]) {
        return [self identifierFromASIdentifierManager:obfuscate];
    } else {
        return [self adsnativeIdentifier:obfuscate];
    }
}

+ (NSString *)identifierFromASIdentifierManager:(BOOL)obfuscate
{
    if (obfuscate) {
        return @"XXXX";
    }
    
    NSString *identifier = nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= AN_IOS_6_0
    identifier = [[ASIdentifierManager sharedManager].advertisingIdentifier UUIDString];
#endif
    
    return [NSString stringWithFormat:@"%@", [identifier uppercaseString]];
}

+ (BOOL)advertisingTrackingEnabled
{
    BOOL enabled = YES;
    
    if ([self deviceHasASIdentifierManager]) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= AN_IOS_6_0
        enabled = [[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled];
#endif
    }
    
    return enabled;
}

+ (NSString *)adsnativeIdentifier:(BOOL)obfuscate
{
    if (obfuscate) {
        return @"adsnative:XXXX";
    }
    
    NSString *identifier = [[NSUserDefaults standardUserDefaults] objectForKey:ADSNATIVE_IDENTIFIER_DEFAULTS_KEY];
    if (!identifier) {
        CFUUIDRef uuidObject = CFUUIDCreate(kCFAllocatorDefault);
        NSString *uuidStr = (NSString *)CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuidObject));
        CFRelease(uuidObject);
        
        identifier = [NSString stringWithFormat:@"adsnative:%@", [uuidStr uppercaseString]];
        [[NSUserDefaults standardUserDefaults] setObject:identifier forKey:ADSNATIVE_IDENTIFIER_DEFAULTS_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    return identifier;
}
@end
