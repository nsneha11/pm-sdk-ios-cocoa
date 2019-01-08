//
//  PMNativeVideoCustomEvent.m
//
//  Created by Arvind Bharadwaj on 26/11/15.
//  Copyright © 2015 AdsNative. All rights reserved.
//

#import "PMNativeVideoCustomEvent.h"
#import "PMNativeVideoAdAdapter.h"
#import "PMNativeAd+Internal.h"
#import "AdAssets.h"
#import "SDKConfigs.h"
#import "AdErrors.h"
#import "Logging.h"

@implementation PMNativeVideoCustomEvent

- (void)requestAdWithCustomEventInfo:(NSDictionary *)info
{
    PMNativeVideoAdAdapter *adAdapter = [[PMNativeVideoAdAdapter alloc] initWithAdProperties:[info mutableCopy]];
    
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
        
        //adding default video assets to precache along with ad assets
        [[self class] addURLString:(NSString *)kDefaultPlayButtonImageURL toURLArray:imageURLs];
        [[self class] addURLString:(NSString *)kDefaultExpandButtonImageURL toURLArray:imageURLs];
        [[self class] addURLString:(NSString *)kDefaultCloseButtonImageURL toURLArray:imageURLs];
        
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
