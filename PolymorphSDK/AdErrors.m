//
//  AdErrors.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "AdErrors.h"

NSString * const PolymorphSDKDomain = @"com.adsnative.ads";

NSError *AdNSErrorForInvalidAdServerResponse(NSString *reason) {
    if (reason.length == 0) {
        reason = @"Invalid ad server response";
    }
    
    return [NSError errorWithDomain:PolymorphSDKDomain code:AdErrorInvalidServerResponse userInfo:@{NSLocalizedDescriptionKey : [reason copy]}];
}

NSError *AdNSErrorForImageDownloadFailure() {
    return [NSError errorWithDomain:PolymorphSDKDomain code:AdErrorImageDownloadFailed userInfo:@{NSLocalizedDescriptionKey : @"Failed to download images"}];
}

NSError *AdNSErrorForInvalidImageURL() {
    return AdNSErrorForInvalidAdServerResponse(@"Invalid image URL");
}

NSError *AdNSErrorForNetworkConnectionError() {
    return [NSError errorWithDomain:PolymorphSDKDomain code:AdErrorHTTPError userInfo:@{NSLocalizedDescriptionKey : @"Connection error"}];
}

NSError *AdNSErrorForNoFill() {
    return [NSError errorWithDomain:PolymorphSDKDomain code:AdErrorNoInventory userInfo:@{NSLocalizedDescriptionKey : @"No-Fill for ad request"}];
}

NSError *AdNSErrorForContentDisplayErrorMissingRootController() {
    return [NSError errorWithDomain:PolymorphSDKDomain code:AdErrorContentDisplayError userInfo:@{NSLocalizedDescriptionKey : @"Cannot display content without a root view controller"}];
}

NSError *AdNSErrorForContentDisplayErrorInvalidURL() {
    return [NSError errorWithDomain:PolymorphSDKDomain code:AdErrorContentDisplayError userInfo:@{NSLocalizedDescriptionKey : @"Cannot display content without a valid URL"}];
}
