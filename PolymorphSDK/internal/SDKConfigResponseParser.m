//
//  SDKConfigResponseParser.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 28/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "SDKConfigResponseParser.h"
#import "NSJSONSerialization+Additions.h"
#import "PMClientAdPositions.h"
#import "SDKConfigs.h"
#import "PMAdRendering.h"
#import "Logging.h"
#import "Constants.h"

static NSString * const SDKConfigResponseDeserializationErrorDomain = @"com.adsnative.iossdk.config.deserialization";

//for positions
static NSString * const PositionResponseKey = @"adPositions";
static NSString * const PositionResponseFixedPositionsKey = @"fixed";
static NSString * const PositionResponseSectionKey = @"section";
static NSString * const PositionResponsePositionKey = @"position";
static NSString * const PositionResponseRepeatingKey = @"repeating";
static NSString * const PositionResponseIntervalKey = @"interval";
static NSString * const VideoAssetsKey = @"video";
static NSInteger const MinRepeatingInterval = 2;
static NSInteger const MaxRepeatingInterval = 1 << 16;

//for video
static NSString * const PlayButtonImageURLKey = @"playButtonUrl";
static NSString * const CloseButtonImageURLKey = @"closeButtonUrl";
static NSString * const ExpandButtonImageURLKey = @"expandButtonUrl";
static NSString * const PlayPercentVisibleForAutoPlayKey = @"percentVisible";

//for rendering class
static NSString * const RenderingClassKey = @"layout";

//for header bidding interval
static NSString * const BidderIntervalKey = @"biddingInterval";

//for banner
static NSString * const RefreshIntervalKey = @"refreshInterval";

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation SDKConfigResponseParser

+ (instancetype)deserializer
{
    return [[[self class] alloc] init];
}

- (SDKConfigs *)sdkConfigsForData:(NSData *)data error:(NSError **)error
{
    SDKConfigs *configs = [[SDKConfigs alloc] init];
    
    NSError *deserializationError = nil;
    NSDictionary *configDictionary = [NSJSONSerialization pm_JSONObjectWithData:data options:0 clearNullObjects:YES error:&deserializationError];
    NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
    //if error return empty positioning object wrapped in configs object
    if (deserializationError) {
        [self safeAssignError:error code:SDKConfigResponseIsNotValidJSON description:@"Failed to deserialize JSON." underlyingError:deserializationError];
        configs.positions = [PMClientAdPositions positioning];
        return configs;
    }
    
    NSDictionary *videoAssets = [configDictionary objectForKey:VideoAssetsKey];
    
    if (![videoAssets objectForKey:PlayButtonImageURLKey] || ![[videoAssets objectForKey:PlayButtonImageURLKey] isKindOfClass:[NSString class]] || [[videoAssets objectForKey:PlayButtonImageURLKey] length] == 0) {
        LogDebug(@"Could not find play button image. Loading default image");
        configs.playButtonImageURL = (NSString *)kDefaultPlayButtonImageURL;
    } else {
        configs.playButtonImageURL = [videoAssets objectForKey:PlayButtonImageURLKey];
    }
    
    if (![videoAssets objectForKey:CloseButtonImageURLKey] || ![[videoAssets objectForKey:CloseButtonImageURLKey] isKindOfClass:[NSString class]] || [[videoAssets objectForKey:CloseButtonImageURLKey] length] == 0) {
        LogDebug(@"Could not find close button image. Loading default image");
        configs.closeButtonImageURL = (NSString *)kDefaultCloseButtonImageURL;
    } else {
        configs.closeButtonImageURL = [videoAssets objectForKey:CloseButtonImageURLKey];
    }
    
    if (![videoAssets objectForKey:ExpandButtonImageURLKey] || ![[videoAssets objectForKey:ExpandButtonImageURLKey] isKindOfClass:[NSString class]] || [[videoAssets objectForKey:ExpandButtonImageURLKey] length] == 0) {
        LogDebug(@"Could not find expand button image. Loading default image");
        configs.expandButtonImageURL = (NSString *)kDefaultExpandButtonImageURL;
    } else {
        configs.expandButtonImageURL = [videoAssets objectForKey:ExpandButtonImageURLKey];
    }
    
    if (![videoAssets objectForKey:PlayPercentVisibleForAutoPlayKey]) {
        LogDebug(@"Could not find autoplay percent visibility in configs. Loading defaults");
        configs.percentVisibleForAutoplay = (float)kDefaultPercentVisibleForAutoplay;
    } else {
        float percentVisible = [[videoAssets objectForKey:PlayPercentVisibleForAutoPlayKey] floatValue];
        if (percentVisible > 0.0f && percentVisible <= 100.0f) {
            configs.percentVisibleForAutoplay = percentVisible;
        } else {
            LogDebug(@"Could not find autoplay percent visibility in configs. Loading defaults");
            configs.percentVisibleForAutoplay = (float)kDefaultPercentVisibleForAutoplay;
        }
    }
    
    id positioningData = [configDictionary objectForKey:PositionResponseKey];
    
    //Check if positons information is received
    if (!positioningData || [positioningData count] == 0) {
        LogDebug(@"Positions for stream ads have not been set on the server. Assuming client side positions are being set.");

        configs.positions = [PMClientAdPositions positioning];
    } else {
    
        PMClientAdPositions *positioning = [self clientPositioningForData:positioningData error:error];
        configs.positions = positioning;
    }
    
    //Check if layout is received
    if ([[configDictionary objectForKey:RenderingClassKey] length] == 0) {
        LogDebug(@"Rendering class not set on the server. Assuming only default rendering class on the client.");
        configs.renderingClass = nil;
        
    } else {
        //Check if rendering class exists as per specs. If not, make it nil.
        Class renderingClass = NSClassFromString([configDictionary objectForKey:RenderingClassKey]);
        
        if (!([renderingClass conformsToProtocol:@protocol(PMAdRendering)] && [renderingClass isSubclassOfClass:[UIView class]])) {
            LogWarn(@"Rendering class fetched does not conform to PMAdRendering protocol or isn't a subclass of UIView.");
            configs.renderingClass = nil;
        } else {
            configs.renderingClass = NSClassFromString([configDictionary objectForKey:RenderingClassKey]);
        }
    }
    
    //Check if refresh interval for banner is present
    if ([configDictionary objectForKey:RefreshIntervalKey] && [[configDictionary objectForKey:RefreshIntervalKey] isKindOfClass:[NSNumber class]]) {
        int refreshInterval = [[configDictionary objectForKey:RefreshIntervalKey] intValue];
        if (refreshInterval < MINIMUM_REFRESH_INTERVAL) {
            LogWarn(@"Refresh interval on server cannot be less than %d. Using defaults.", MINIMUM_REFRESH_INTERVAL);
            configs.refreshInterval = kDefaultRefreshInterval;
        } else {
            configs.refreshInterval = refreshInterval;
        }
    } else {
        LogDebug(@"Banner refresh interval not set on server. Using default.");
        configs.refreshInterval = kDefaultRefreshInterval;
        
    }
    
    
    if ([configDictionary objectForKey:BidderIntervalKey] && [[configDictionary objectForKey:BidderIntervalKey] isKindOfClass:[NSNumber class]]) {
        float biddingInterval = [(NSNumber *)[configDictionary objectForKey:BidderIntervalKey] floatValue];
        configs.biddingInterval = biddingInterval;
        
    } else {
        LogDebug(@"Could not find bidding interval in configs. Loading defaults");
        configs.biddingInterval = (float)kDefaultBiddingInterval;
    }
    return configs;
    
}

/**
 * Returns an ad positioning object given a data object.
 *
 * If an error occurs during the data conversion, this method will return an empty positioning
 * object containing no desired ad positions.
 *
 * @param data A data object containing positioning information.
 * @param error A pointer to an error object. If an error occurs, this pointer will be set to an
 * actual error object containing the error information.
 *
 * @return An `PMClientAdPositions` object. This is guaranteed to be non-nil; if an error occurs
 * during deserialization, the return value will still be a positioning object with no ad positions.
 */
- (PMClientAdPositions *)clientPositioningForData:(NSDictionary *)data error:(NSError **)error
{
    PMClientAdPositions *positioning = [PMClientAdPositions positioning];
    
    
//    NSError *deserializationError = nil;
    NSDictionary *positionDictionary = data;
//    NSDictionary *positionDictionary = [NSJSONSerialization pm_JSONObjectWithData:data options:0 clearNullObjects:YES error:&deserializationError];
    
//    if (deserializationError) {
//        [self safeAssignError:error code:SDKConfigResponseIsNotValidJSON description:@"Failed to deserialize JSON." underlyingError:deserializationError];
//        return [PMClientAdPositions positioning];
//    }
    
    NSError *fixedPositionsError = nil;
    NSArray *fixedPositions = [self parseFixedPositionsObject:[positionDictionary objectForKey:PositionResponseFixedPositionsKey] error:&fixedPositionsError];
    
    if (fixedPositionsError) {
        if (error) {
            *error = fixedPositionsError;
        }
        return [PMClientAdPositions positioning];
    }
    
    NSError *repeatingIntervalError = nil;
    NSInteger repeatingInterval = [self parseRepeatingIntervalObject:[positionDictionary objectForKey:PositionResponseRepeatingKey] error:&repeatingIntervalError];
    
    if (repeatingIntervalError) {
        if (error) {
            *error = repeatingIntervalError;
        }
        return [PMClientAdPositions positioning];
    }
    
    if ([fixedPositions count] == 0 && repeatingInterval <= 0) {
        [self safeAssignError:error code:SDKConfigResponseJSONHasInvalidPositionData description:@"Positioning object must have either fixed positions or a repeating interval."];
        return [PMClientAdPositions positioning];
    }
    
    [fixedPositions enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
        [positioning addFixedIndexPath:indexPath];
    }];
    [positioning enableRepeatingPositionsWithInterval:repeatingInterval];
    return positioning;
}

#pragma mark - Parsing and validation

- (NSArray *)parseFixedPositionsObject:(id)positionsObject error:(NSError **)error
{
    NSMutableArray *parsedPositions = [NSMutableArray array];
    
    if (positionsObject && ![positionsObject isKindOfClass:[NSArray class]]) {
        [self safeAssignError:error code:SDKConfigResponseJSONHasInvalidPositionData description:[NSString stringWithFormat:@"Expected object for key \"%@\" to be an array. Actual: %@", PositionResponseFixedPositionsKey, positionsObject]];
        return nil;
    }
    
    __block NSError *fixedPositionError = nil;
    [positionsObject enumerateObjectsUsingBlock:^(id positionObj, NSUInteger idx, BOOL *stop) {
        if (![self validatePositionObject:positionObj error:&fixedPositionError]) {
            *stop = YES;
            return;
        }
        
        NSInteger section = [self integerFromDictionary:positionObj forKey:PositionResponseSectionKey defaultValue:0];
        NSInteger position = [self integerFromDictionary:positionObj forKey:PositionResponsePositionKey defaultValue:0];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:position inSection:section];
        [parsedPositions addObject:indexPath];
    }];
    
    if (fixedPositionError) {
        if (error) {
            *error = fixedPositionError;
        }
        return nil;
    }
    
    return parsedPositions;
}


- (NSInteger)parseRepeatingIntervalObject:(id)repeatingIntervalObject error:(NSError **)error
{
    if (!repeatingIntervalObject) {
        return 0;
    }
    
    NSError *repeatingIntervalError = nil;
    if (![self validateRepeatingIntervalObject:repeatingIntervalObject error:&repeatingIntervalError]) {
        if (error) {
            *error = repeatingIntervalError;
        }
        return 0;
    }
    NSInteger interval = [self integerFromDictionary:repeatingIntervalObject forKey:PositionResponseIntervalKey defaultValue:10];
    if (interval < 2)
        //setting default repeating interval
        interval = 10;
    return interval;
}

- (BOOL)validatePositionObject:(id)positionObject error:(NSError **)error
{
    if (![positionObject isKindOfClass:[NSDictionary class]]) {
        [self safeAssignError:error code:SDKConfigResponseJSONHasInvalidPositionData description:[NSString stringWithFormat:@"Position object is not a dictionary: %@.", positionObject]];
        return NO;
    }
    
    // Section number is not required. If it's present, we have to check that it's non-negative;
    // if it isn't there, we assign a section number of 0.
    NSInteger section = [positionObject objectForKey:PositionResponseSectionKey] ? [self integerFromDictionary:positionObject forKey:PositionResponseSectionKey defaultValue:-1] : 0;
    if (section < 0) {
        [self safeAssignError:error code:SDKConfigResponseJSONHasInvalidPositionData description:[NSString stringWithFormat:@"Position object has an invalid \"%@\" value or is not a positive number: %ld.", PositionResponseSectionKey, (long)section]];
        return NO;
    }
    
    // Unlike section, position is required. It also must be a non-negative number.
    NSInteger position = [self integerFromDictionary:positionObject forKey:PositionResponsePositionKey defaultValue:-1];
    if (position < 0) {
        [self safeAssignError:error code:SDKConfigResponseJSONHasInvalidPositionData description:[NSString stringWithFormat:@"Position object has an invalid \"%@\" value or is not a positive number: %ld.", PositionResponsePositionKey, (long)position]];
        return NO;
    }
    
    return YES;
}

- (BOOL)validateRepeatingIntervalObject:(id)repeatingIntervalObject error:(NSError **)error
{
    if (![repeatingIntervalObject isKindOfClass:[NSDictionary class]]) {
        [self safeAssignError:error code:SDKConfigResponseJSONHasInvalidPositionData description:[NSString stringWithFormat:@"Repeating interval object is not a dictionary: %@.", repeatingIntervalObject]];
        return NO;
    }
    
    // The object must contain a value between MinRepeatingInterval and MaxRepeatingInterval.
    NSInteger interval = [self integerFromDictionary:repeatingIntervalObject forKey:PositionResponseIntervalKey defaultValue:0];
    if (interval > MaxRepeatingInterval) {
        [self safeAssignError:error code:SDKConfigResponseJSONHasInvalidPositionData description:[NSString stringWithFormat:@"\"%@\" value in repeating interval object needs to be less than %ld: %ld.", PositionResponseIntervalKey, (long)MaxRepeatingInterval, (long)interval]];
        return NO;
    }
    if (interval < MinRepeatingInterval) {
        LogWarn(@"Repeating interval is set at %1d. It should be atleast %1d. Setting defaults.", (long)interval, (long)MinRepeatingInterval);
    }
    
    return YES;
}

#pragma mark - Dictionary helpers

/**
 * Returns an `NSInteger` value associated with a certain key in a dictionary, or a specified
 * default value if the key is not associated with a valid integer representation.
 *
 * Valid integer representations include `NSNumber` objects and `NSString` objects that
 * consist only of integer or sign characters.
 *
 * @param dictionary A dictionary containing keys and values.
 * @param key The key for which to return an integer value.
 * @param defaultValue A value that should be returned if `key` is not associated with an object
 * that contains an integer representation.
 *
 * @return The integer value associated with `key`, or `defaultValue` if the object is not an
 * `NSNumber` or an `NSString` representing an integer.
 */
- (NSInteger)integerFromDictionary:(NSDictionary *)dictionary forKey:(NSString *)key defaultValue:(NSInteger)defaultValue
{
    static NSCharacterSet *nonIntegerCharacterSet;
    
    id object = [dictionary objectForKey:key];
    
    if ([object isKindOfClass:[NSNumber class]]) {
        return [object integerValue];
    } else if ([object isKindOfClass:[NSString class]]) {
        if (!nonIntegerCharacterSet) {
            nonIntegerCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789-"] invertedSet];
        }
        
        // If the string consists of all digits, we'll call -integerValue. Otherwise, return the
        // default value.
        if ([object rangeOfCharacterFromSet:nonIntegerCharacterSet].location == NSNotFound) {
            return [object integerValue];
        } else {
            return defaultValue;
        }
    } else {
        return defaultValue;
    }
}

#pragma mark - Error helpers

- (void)safeAssignError:(NSError **)error code:(SDKConfigResponseDeserializationErrorCode)code userInfo:(NSDictionary *)userInfo
{
    if (error) {
        *error = [self deserializationErrorWithCode:code userInfo:userInfo];
    }
}

- (void)safeAssignError:(NSError **)error code:(SDKConfigResponseDeserializationErrorCode)code description:(NSString *)description
{
    [self safeAssignError:error code:code description:description underlyingError:nil];
}

- (void)safeAssignError:(NSError **)error code:(SDKConfigResponseDeserializationErrorCode)code description:(NSString *)description underlyingError:(NSError *)underlyingError
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    
    if (description) {
        [userInfo setObject:description forKey:NSLocalizedDescriptionKey];
    }
    
    if (underlyingError) {
        [userInfo setObject:underlyingError forKey:NSUnderlyingErrorKey];
    }
    
    [self safeAssignError:error code:code userInfo:userInfo];
}

- (NSError *)deserializationErrorWithCode:(SDKConfigResponseDeserializationErrorCode)code userInfo:(NSDictionary *)userInfo
{
    return [NSError errorWithDomain:SDKConfigResponseDeserializationErrorDomain
                               code:code
                           userInfo:userInfo];
}

@end
