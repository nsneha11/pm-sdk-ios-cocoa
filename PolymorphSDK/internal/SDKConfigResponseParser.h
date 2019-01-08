//
//  SDKConfigResponseParser.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 28/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class PMClientAdPositions;
@class SDKConfigs;

typedef enum : NSUInteger {
    SDKConfigResponseDataIsEmpty,
    SDKConfigResponseIsNotValidJSON,
    SDKConfigResponseJSONHasInvalidPositionData,
    SDKConfigResponsePositionDataIsEmpty
} SDKConfigResponseDeserializationErrorCode;

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface SDKConfigResponseParser : NSObject

/**
 * Creates and returns an object that can deserialize HTTP response data into config
 * objects.
 *
 * @return The newly created deserializer.
 */
+ (instancetype)deserializer;

/**
 * Returns a `SDKConfigs` object given a data object.
 * If an error occurs during the data conversion, this method will return an empty SDKConfig
 * object which would contain no desired ad positions.
 *
 * @param data A data object containing config information.
 * @param error A pointer to an error object. If an error occurs, this pointer will be set to an
 * actual error object containing the error information.
 
 * @return A `SDKConfigs` object. This is guaranteed to be non-nil; if an error occurs
 * during deserialization, the return value will still contain a positioning object with no ad positions.
 */
- (SDKConfigs *)sdkConfigsForData:(NSData *)data error:(NSError **)error;

@end
