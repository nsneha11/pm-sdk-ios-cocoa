//
//  PMNativeCustomEvent.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 30/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "PMNativeCustomEvent.h"
#import "PMNativeAdAdapter.h"
#import "PMNativeAd+Internal.h"
#import "AdErrors.h"
#import "Logging.h"

@implementation PMNativeCustomEvent

- (void)requestAdWithCustomEventInfo:(NSDictionary *)info
{
    PMNativeAdAdapter *adAdapter = [[PMNativeAdAdapter alloc] initWithAdProperties:[info mutableCopy]];
    
    if (adAdapter.nativeAssets) {
        PMNativeAd *interfaceAd = [[PMNativeAd alloc] initWithAdAdapter:adAdapter];
        [interfaceAd.impressionTrackers addObjectsFromArray:adAdapter.impressionTrackers];
        [interfaceAd.viewabilityTrackers addObjectsFromArray:adAdapter.viewabililityTrackers];
        [interfaceAd.clickTrackers addObjectsFromArray:adAdapter.clickTrackers];
        
        // Get the image urls so we can download them prior to returning the ad.
        NSMutableArray *imageURLs = [NSMutableArray array];
        for (NSString *key in [info allKeys]) {
            if ([[key lowercaseString] rangeOfString:@"image"].length > 0 && [[info objectForKey:key] isKindOfClass:[NSString class]] && ![[info objectForKey:key] isEqualToString:@""]) {
                if (![[self class] addURLString:[info objectForKey:key] toURLArray:imageURLs]) {
                    [self.delegate nativeCustomEvent:self didFailToLoadAdWithError: AdNSErrorForInvalidImageURL()];
                }
            }
        }
        
        [super precacheImagesWithURLs:imageURLs completionBlock:^(NSArray *errors) {
            if (errors) {
                LogDebug(@"%@", errors);
                [self.delegate nativeCustomEvent:self didFailToLoadAdWithError:AdNSErrorForImageDownloadFailure()];
            } else {
                [self.delegate nativeCustomEvent:self didLoadAd:interfaceAd];
            }
        }];
    } else {
        [self.delegate nativeCustomEvent:self didFailToLoadAdWithError: AdNSErrorForInvalidAdServerResponse(nil)];
    }
}

#pragma mark - internal
+ (BOOL)addURLString:(NSString *)urlString toURLArray:(NSMutableArray *)urlArray
{
    if (urlString.length == 0) {
        return NO;
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (url) {
        [urlArray addObject:url];
        return YES;
    } else {
        return NO;
    }
}
@end
