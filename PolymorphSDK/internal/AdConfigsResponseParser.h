//
//  AdConfigsResponseParser.h
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 30/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    AdResponseDataIsEmpty,
    AdResponseIsNotValidJSON,
    AdResponseJSONHasInvalidNetworkData,
    AdResponseFailed
} AdResponseDeserializationErrorCode;

@interface AdConfigsResponseParser : NSObject

/*
 * For Mediation Request, the networks Object is needed as is. If the ad response parsing is succesful, this
 * will contain the entire networks object as a dictionary. It will be nil otherwise.
 */
@property (nonatomic, strong) NSDictionary *networksObject;

/**
 * Returns a `NSMutableOrderedSet` given a data object.
 * If an error occurs during the data conversion, this method will return an empty
 * set which would contain no `AdConfig` objects.
 *
 * @param data A data object containing the order of the various network ad requests to be made.
 * @param error A pointer to an error object. If an error occurs, this pointer will be set to an
 * actual error object containing the error information.
 
 * @return An `NSMutableOrderedSet` object. This is guaranteed to be non-nil; if an error occurs
 * during deserialization, the return value will still contain an empty set with no ads or networks to fetch ads from.
 */
- (NSMutableOrderedSet *)adConfigsSetForData:(NSData *)data error:(NSError **)error;


@end
