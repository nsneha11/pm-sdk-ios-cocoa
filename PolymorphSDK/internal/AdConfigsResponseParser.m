//
//  AdConfigsResponseParser.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 30/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "AdConfigsResponseParser.h"
#import "NSJSONSerialization+Additions.h"
#import "AdConfigs.h"
#import "AdAssets.h"
#import "Logging.h"
#import "PMNativeCustomEvent.h"
#import "PMNativeVideoCustomEvent.h"
#import "PMBannerInternalCustomEvent.h"
#import "SDKConfigsSource.h"
#import "SDKConfigs.h"
#import "Constants.h"

static NSString * const AdResponseDeserializationErrorDomain = @"com.adsnative.iossdk.ad.deserialization";

/* Adtype values */
static NSString * const DefaultAdType = @"native";
static NSString * const AdTypeBanner = @"banner";

/*Status and message*/
static NSString * const StatusKey = @"status";
static NSString * const MessageKey = @"message";

/* Ad Response Keys */
static NSString * const AdUnitIDKey = @"zid";
static NSString * const EcpmKey = @"ecpm";
static NSString * const CountResponseKey = @"count";

//networks object
static NSString * const NetworkResponseKey = @"networks";
static NSString * const NetworkProviderClassNameKey = @"adNetworkClassName";
static NSString * const NetworkProviderDataKey = @"providerData";
static NSString * const NetworkNoFillTrackerKey = @"nofills";

//AdsNative ad object
static NSString * const AdResponseKey = @"ad";
static NSString * const CTATitleKey = @"ctaTitle";
static NSString * const SummaryKey = @"summary";
static NSString * const TitleKey = @"title";
static NSString * const IconImageKey = @"brandImageUrl";
static NSString * const MainImageKey = @"imageSrc";
static NSString * const HTMLKey = @"html";
static NSString * const EmbedUrlKey = @"embedUrl";
//static NSString * const StarRatingKey = @"starRating"; //not supported
static NSString * const CustomAssetsKey = @"customFields";
static NSString * const SponsoredByTagKey = @"promotedByTag";
static NSString * const SponsoredByKey = @"promotedBy";
static NSString * const LandingUrlKey = @"landingUrl";
static NSString * const AdTypeKey = @"type";
static NSString * const AdTypeVideoKey = @"video";

//Privacy object
static NSString * const PrivacyResponseKey = @"privacy";
static NSString * const PrivacyAdvertiserPolicyResponseKey = @"advertiserPolicyUrl";
static NSString * const PrivacyIconUrlResponseKey = @"iconUrl";

//Video assets from AdsNative ad object
static NSString * const VideoAssetsKey = @"video";
static NSString * const VideoSourcesKey = @"sources";
static NSString * const VideoExperienceKey = @"experience";
static NSString * const VideoExperienceDefaultKey = @"click_to_play";
static NSString * const VideoEmbedTypeKey = @"embedType";
static NSString * const VideoEmbedTypeIframeKey = @"iframe";
static NSString * const VideoEmbedTypeVastKey = @"vast";
static NSString * const VideoTrackingUrlsKey = @"trackingUrls";
static NSString * const VideoDurationKey = @"duration";
static NSString * const VideoPercentageKey = @"percentage";
static NSString * const VideoCompletionTrackerKey = @"complete";
static NSString * const VideoImpressionTrackerKey = @"impression";
static NSString * const VideoClickThroughTrackerKey = @"clickThrough";
static NSString * const VideoPlayTrackerKey = @"view";


//Other keys
static NSString * const SDKConfigsKey = @"sdkConfigs";
static NSString * const IsBackupClassRequiredKey = @"isBackupClassRequired";

//Common keys
//Tracking
static NSString * const TrackingUrlKey = @"trackingUrls";
static NSString * const ImpressionTrackerKey = @"impressions";
static NSString * const ViewableImpressionKey = @"viewables";
static NSString * const ClickTrackerKey = @"clicks";
static NSString * const CustomActionsKey = @"actions";


//////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface AdConfigsResponseParser()

@property (nonatomic,strong) NSMutableOrderedSet *adConfigsSet;

@end

//////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation AdConfigsResponseParser

- (instancetype)init
{
    return [super init];
}

- (NSMutableOrderedSet *)adConfigsSetForData:(NSData *)data error:(NSError **)error
{
    NSError *deserializationError = nil;
    NSDictionary *adResponseDictionary = [NSJSONSerialization pm_JSONObjectWithData:data options:0 clearNullObjects:YES error:&deserializationError];
    NSLog(@"%@",adResponseDictionary);
    
    //if error return empty set
    if (deserializationError) {
        [self safeAssignError:error code:AdResponseIsNotValidJSON description:@"Failed to deserialize JSON."
              underlyingError:deserializationError];
        return [[NSMutableOrderedSet alloc] initWithCapacity:1];
    }
    
    //Initialise the ordered set with value from `CountResponseKey` as capacity
    NSInteger count = [self integerFromDictionary:adResponseDictionary forKey:CountResponseKey defaultValue:-1];
    if (count != -1)
        _adConfigsSet = [[NSMutableOrderedSet alloc] initWithCapacity:count];
    else
        _adConfigsSet = [[NSMutableOrderedSet alloc] init];
    
    //Check for failed status
    NSString *status = [adResponseDictionary objectForKey:StatusKey];
    
    if (status && [status rangeOfString:@"FAIL"].length > 0) {
        //put message in error response
        NSString *message = [adResponseDictionary objectForKey:MessageKey];
        [self safeAssignError:error code:AdResponseFailed description:[NSString stringWithFormat:@"Response failed with error: %@", message]];
        return self.adConfigsSet;
    }
    
    NSError *networksError = nil;
    id networksObject = [adResponseDictionary objectForKey:NetworkResponseKey];
    
    [self parseNetworksObject:networksObject error:&networksError];
    
    if (networksError) {
        [self safeAssignError:error code:AdResponseIsNotValidJSON description:@"Failed to deserialize JSON." underlyingError:networksError];
        return self.adConfigsSet;
    }
    
    //Populate networksObject if it exists. This is required for mediation requests.
    if (networksObject) {
        NSMutableDictionary *networksList = [[NSMutableDictionary alloc] init];
        [networksList setObject:networksObject forKey:NetworkResponseKey];
        self.networksObject = networksList;
    }
    
    
    //add network objects to set
    [networksObject enumerateObjectsUsingBlock:^(id networkObj, NSUInteger idx, BOOL *stop) {
        
        __block NSError *networkObjectError = nil;
        if (![self validateNetworkObject:networkObj error:&networkObjectError]) {
            LogWarn(@"Network Object %d is an invalid json, ignoring it",idx);
            LogDebug(@"Network Object %d : %@",idx,networkObj);
            return;
        }
        
        AdConfigs *adConfig = [[AdConfigs alloc] init];
        //        NSString *customEventClassName = [networkObj objectForKey:NetworkProviderNameKey];
        
        //set adtype to native by default for networks
        adConfig.adtype = DefaultAdType;
        
        //Extracting the class name from NetworkProviderDataKey
        NSString *providerDataAsString = [networkObj objectForKey:NetworkProviderDataKey];
        
        NSData *data = [providerDataAsString dataUsingEncoding:NSUTF8StringEncoding];
        id networkProviderDataFixed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        
        //re-check if iteration happens when return is executed
        if (![networkProviderDataFixed isKindOfClass:[NSDictionary class]]) {
            return;
        }

        NSMutableDictionary *networkProviderData = [[NSMutableDictionary alloc] initWithDictionary:networkProviderDataFixed];

        //        id networkProviderData = [networkObj objectForKey:NetworkProviderDataKey];
        NSString *customEventClassName = [networkProviderData objectForKey:NetworkProviderClassNameKey];
        adConfig.customEventClass = NSClassFromString(customEventClassName);
        
        if ([networkObj objectForKey:EcpmKey] && [[networkObj objectForKey:EcpmKey] isKindOfClass:[NSNumber class]]) {
            [networkProviderData setObject:[networkObj objectForKey:EcpmKey] forKey:kNativeEcpmKey];
        }
        
        //        adConfig.customEventClassData = [networkObj objectForKey:NetworkProviderDataKey];
        adConfig.customEventClassData = networkProviderData;
        
        id trackingObjects = [networkObj objectForKey:TrackingUrlKey];
        
        //adding impressions and viewables to the impression tracker list
        NSMutableArray *impTrackers = [trackingObjects objectForKey:ImpressionTrackerKey];
        if ([trackingObjects objectForKey:ViewableImpressionKey] && [[trackingObjects objectForKey:ViewableImpressionKey] isKindOfClass:[NSArray class]] && [[trackingObjects objectForKey:ViewableImpressionKey] count] > 0) {
            adConfig.viewabilityTrackers = [trackingObjects objectForKey:ViewableImpressionKey];
        }
        
        
        adConfig.impressionTrackers = impTrackers;
        adConfig.clickTrackers = [trackingObjects objectForKey:ClickTrackerKey];
        
        //Adding network no fill trackers
        if ([trackingObjects objectForKey:NetworkNoFillTrackerKey] && [[trackingObjects objectForKey:NetworkNoFillTrackerKey] isKindOfClass:[NSArray class]] && [[trackingObjects objectForKey:NetworkNoFillTrackerKey] count] != 0) {
            adConfig.noFillTrackers = [trackingObjects objectForKey:NetworkNoFillTrackerKey];
        }
        
        //Adding the network object to the set
        if(customEventClassName && !adConfig.customEventClass)
            LogWarn(@"Could not find custom event class named %@", customEventClassName);
        [self.adConfigsSet addObject:adConfig];
    }];
    
    NSError *adsError = nil;
    id adObject = [adResponseDictionary objectForKey:AdResponseKey];
    [self validateAdObject:adObject error:&adsError];
    
    if (adsError) {
        [self safeAssignError:error code:AdResponseIsNotValidJSON description:@"Failed to deserialize JSON for direct AdsNative ad." underlyingError:adsError];
        return self.adConfigsSet;
    }
    /**
     * Add AN ad object to set.
     * For an AN ad object, we read all the keys and put them into `customEventClassData` which
     * is then passed to `PMNativeCustomEvent`s `requestAdWithCustomEventInfo` message in the
     * "info" params as dictionary
     */
    AdConfigs *adConfig = [[AdConfigs alloc] init];
    NSMutableDictionary *assets = [[NSMutableDictionary alloc] init];
    
    //get the ad body for a given ad object
    NSDictionary *adBody = [adResponseDictionary objectForKey:AdResponseKey];
    
    //If adBody doesn't exist, return
    if (adBody == nil || [adBody count] == 0) {
        return self.adConfigsSet;
    }
    
    NSString *adUnitId = @"";
    //getting ad unit id from ad response
    if ([adResponseDictionary objectForKey:AdUnitIDKey] != nil && [[adResponseDictionary objectForKey:AdUnitIDKey] isKindOfClass:[NSString class]]) {
        adUnitId = (NSString *)[adResponseDictionary objectForKey:AdUnitIDKey];
    }
    
    
    //Populating SDK Configs
    SDKConfigsSource *sdkConfigSource = [SDKConfigsSource sharedInstance];
    SDKConfigs *sdkConfigs = [sdkConfigSource getSDKConfigsForAdUnitId:adUnitId];
    if (sdkConfigs != nil) {
        [assets setObject:sdkConfigs forKey:kNativeSDKConfigsKey];
    } else {
        LogInfo(@"SDK Configs hasn't returned yet. Using default configs for ad response.");
        SDKConfigs *defaultConfigs = [SDKConfigs populateWithDefaults];
        
        [assets setObject:defaultConfigs forKey:kNativeSDKConfigsKey];
    }
    
    //Ad Type
    [assets setObject:[adBody objectForKey:AdTypeKey] forKey:kNativeAdTypeKey];
    if ([[adBody objectForKey:AdTypeKey] isEqualToString:AdTypeBanner]) {
        adConfig.adtype = AdTypeBanner;
    } else {
        adConfig.adtype = DefaultAdType;
    }
    
    NSMutableArray *impTrackers = [[NSMutableArray alloc] init];
    
    if ([(NSString *)[adBody objectForKey:AdTypeKey] rangeOfString:AdTypeVideoKey].length > 0) {
        
        NSError *videoError = nil;
        [self validateVideoAdObject:adBody error:&videoError];
        
        if (videoError) {
            LogWarn(@"Video object is invalid. Loading Main image instead.");
            
            //The custom event class name for our direct AN Native ad demands
            adConfig.customEventClass = [PMNativeCustomEvent class];
            adConfig.customEventClassData = assets;
            
        } else {
            
            NSDictionary *videoAssets = (NSDictionary *)[adBody objectForKey:VideoAssetsKey];
            
            if ([[videoAssets objectForKey:VideoEmbedTypeKey] caseInsensitiveCompare:@"native"] == NSOrderedSame) {
                //add the sources of the video after reading the sources dict for native videos
                NSMutableArray *sources = [[NSMutableArray alloc] init];
                for (NSDictionary *sourceDict in [videoAssets objectForKey:VideoSourcesKey]) {
                    NSString *url = sourceDict[@"url"];
                    [sources addObject:url];
                }

                [assets setObject:sources forKey:kNativeVideoSourcesKey];
            } else {
                //add the sources of the video directly if youtube ad
                [assets setObject:[videoAssets objectForKey:VideoSourcesKey] forKey:kNativeVideoSourcesKey];
            }
            
            //get the video experience
            if (![videoAssets objectForKey:VideoExperienceKey] || ![[videoAssets objectForKey:VideoExperienceKey] isKindOfClass:[NSString class]] || [[videoAssets objectForKey:VideoExperienceKey] length] == 0) {
                [assets setObject:VideoExperienceDefaultKey forKey:kNativeVideoExperienceKey];
            }else {
                [assets setObject:[videoAssets objectForKey:VideoExperienceKey] forKey:kNativeVideoExperienceKey];
            }
            //get the embed type
            [assets setObject:[videoAssets objectForKey:VideoEmbedTypeKey] forKey:kNativeVideoEmbedTypeKey];
            
            //check if tracking urls is present
            if (![videoAssets objectForKey:VideoTrackingUrlsKey] || ![[videoAssets objectForKey:VideoTrackingUrlsKey] isKindOfClass:[NSDictionary class]] || [[videoAssets objectForKey:VideoTrackingUrlsKey] count] == 0) {
                
                LogDebug(@"Video Object Doesnt contain tracking url:%@",videoAssets);
                
            } else {
                NSDictionary *trackingUrls = (NSDictionary *)[videoAssets objectForKey:VideoTrackingUrlsKey];
                
                //check if duration is present
                if (![trackingUrls objectForKey:VideoDurationKey] || ![[trackingUrls objectForKey:VideoDurationKey] isKindOfClass:[NSDictionary class]] || [[trackingUrls objectForKey:VideoDurationKey] count] == 0) {
                    LogDebug(@"Video tracking object Doesn't contain duration key:%@",videoAssets);
                } else {
                    NSDictionary *duration = (NSDictionary *)[trackingUrls objectForKey:VideoDurationKey];
                    //check if duration contains percentage and video complete keys
                    if (![duration objectForKey:VideoPercentageKey] || ![[duration objectForKey:VideoPercentageKey] isKindOfClass:[NSDictionary class]] || [[duration objectForKey:VideoPercentageKey] count] == 0) {
                        LogDebug(@"Video asset doesnt contain percentage trackers:%@",videoAssets);
                        
                    } else {
                        [assets setObject:[duration objectForKey:VideoPercentageKey] forKey:kNativeVideoPercentageTrackerKey];
                    }
                    if (![duration objectForKey:VideoCompletionTrackerKey] || ![[duration objectForKey:VideoCompletionTrackerKey] isKindOfClass:[NSArray class]] || [[duration objectForKey:VideoCompletionTrackerKey] count] == 0) {
                        
                        LogDebug(@"Video asset doesnt contain completion trackers:%@",videoAssets);
                    } else {
                        [assets setObject:[duration objectForKey:VideoCompletionTrackerKey] forKey:kNativeVideoCompletionTrackerKey];
                    }
                }
                //check if tracking url has impression and view keys
                if (![trackingUrls objectForKey:VideoImpressionTrackerKey] || ![[trackingUrls objectForKey:VideoImpressionTrackerKey] isKindOfClass:[NSArray class]] || [[trackingUrls objectForKey:VideoImpressionTrackerKey] count] == 0) {
                    LogDebug(@"Video asset doesnt contain impression trackers:%@",videoAssets);
                } else {
                    //Add video impression tracker to impression array
                    [assets setObject:[trackingUrls objectForKey:VideoImpressionTrackerKey] forKey:kNativeVideoImpressionTrackerKey];
                }
                if (![trackingUrls objectForKey:VideoPlayTrackerKey] || ![[trackingUrls objectForKey:VideoPlayTrackerKey] isKindOfClass:[NSArray class]] || [[trackingUrls objectForKey:VideoPlayTrackerKey] count] == 0) {
                    LogDebug(@"Video asset doesnt contain play trackers:%@",videoAssets);
                } else {
                    [assets setObject:[trackingUrls objectForKey:VideoPlayTrackerKey] forKey:kNativeVideoPlayTrackerKey];
                }
                //Check for Click Through
                if ([trackingUrls objectForKey:VideoClickThroughTrackerKey] && [[trackingUrls objectForKey:VideoClickThroughTrackerKey] isKindOfClass:[NSArray class]]) {
                    [assets setObject:[trackingUrls objectForKey:VideoClickThroughTrackerKey] forKey:kNativeVideoClickThroughTrackerKey];
                }
            }
            
            
            //The custom event class name for our direct AN Native Video ad demands
            adConfig.customEventClass = [PMNativeVideoCustomEvent class];
            adConfig.customEventClassData = assets;
        }
        
    } else {
        if ([adConfig.adtype isEqualToString:AdTypeBanner]) {
            adConfig.customEventClass = [PMBannerInternalCustomEvent class];
        } else {
            //The custom event class name for our direct AN Native ad demands
            adConfig.customEventClass = [PMNativeCustomEvent class];
        }
        adConfig.customEventClassData = assets;
    }

    //For banner
    //embed url
    if (![adBody objectForKey:EmbedUrlKey] || ![[adBody objectForKey:EmbedUrlKey] isKindOfClass:[NSString class]] || [[adBody objectForKey:EmbedUrlKey] length] == 0) {
        [assets setObject:@"" forKey:kEmbedUrlKey];
    } else {
        [assets setObject:[adBody objectForKey:EmbedUrlKey] forKey:kEmbedUrlKey];
    }
    //html (not really needed). EmbedUrl is used to load banners
    if (![adBody objectForKey:HTMLKey] || ![[adBody objectForKey:HTMLKey] isKindOfClass:[NSString class]] || [[adBody objectForKey:HTMLKey] length] == 0) {
        [assets setObject:@"" forKey:kHtmlKey];
    } else {
        [assets setObject:[adBody objectForKey:HTMLKey] forKey:kHtmlKey];
    }
    
    //privacy link
    [assets setObject:@"" forKey:kNativePrivacyLink];
    [assets setObject:@"" forKey:kNativePrivacyImageUrl];
    if([[adBody objectForKey:PrivacyResponseKey] isKindOfClass:[NSDictionary class]]) {
        //populate privacy data if exists
        NSDictionary *privacyData = [[NSMutableDictionary alloc] initWithDictionary:[adBody objectForKey:PrivacyResponseKey]];
        if([privacyData objectForKey:PrivacyAdvertiserPolicyResponseKey] && [[privacyData objectForKey:PrivacyAdvertiserPolicyResponseKey] isKindOfClass:[NSString class]] && [[privacyData objectForKey:PrivacyAdvertiserPolicyResponseKey] length] > 0) {
            if([privacyData objectForKey:PrivacyIconUrlResponseKey] && [[privacyData objectForKey:PrivacyIconUrlResponseKey] isKindOfClass:[NSString class]] && [[privacyData objectForKey:PrivacyIconUrlResponseKey] length] > 0) {
                //only if both iconUrl and advertiserPolicyUrl exists then populate into assets
                [assets setObject:[privacyData objectForKey:PrivacyAdvertiserPolicyResponseKey] forKey:kNativePrivacyLink];
                [assets setObject:[privacyData objectForKey:PrivacyIconUrlResponseKey] forKey:kNativePrivacyImageUrl];
            }
        }
    }

    //native assets
    if (![adBody objectForKey:CTATitleKey] || ![[adBody objectForKey:CTATitleKey] isKindOfClass:[NSString class]] || [[adBody objectForKey:CTATitleKey] length] == 0) {
        [assets setObject:@"" forKey:kNativeCTATextKey];
    } else {
        [assets setObject:[adBody objectForKey:CTATitleKey] forKey:kNativeCTATextKey];
    }
    
    if (![adBody objectForKey:SummaryKey] || ![[adObject objectForKey:SummaryKey] isKindOfClass:[NSString class]] || [[adObject objectForKey:SummaryKey] length] == 0) {
        [assets setObject:@"" forKey:kNativeTextKey];
    } else {
        [assets setObject:[adBody objectForKey:SummaryKey] forKey:kNativeTextKey];
    }
    
    if (![adObject objectForKey:TitleKey] || ![[adObject objectForKey:TitleKey] isKindOfClass:[NSString class]] || [[adObject objectForKey:TitleKey] length] == 0) {
        [assets setObject:@"" forKey:kNativeTitleKey];
    } else {
        [assets setObject:[adBody objectForKey:TitleKey] forKey:kNativeTitleKey];
    }
    
    //keep a check for icon image key as not all responses will contain it
    if(![adBody objectForKey:IconImageKey] || ![[adBody objectForKey:IconImageKey] isKindOfClass:[NSString class]] || [[adBody objectForKey:IconImageKey] length] == 0) {
        LogInfo(@"Icon image not present in response. Will load ad into backup layout if present.");
        //Setting isBackupRequired to true as image icon is nil.
        [assets setObject:[NSNumber numberWithBool:YES] forKey:kNativeBackUpRequiredKey];
    }
    else {
        [assets setObject:[adBody objectForKey:IconImageKey] forKey:kNativeIconImageKey];
    }
    
    if (![adObject objectForKey:MainImageKey] || ![[adObject objectForKey:MainImageKey] isKindOfClass:[NSString class]] || [[adObject objectForKey:MainImageKey] length] == 0) {
        LogDebug(@"Main Image not present in the ad response");
    } else {
        [assets setObject:[adBody objectForKey:MainImageKey] forKey:kNativeMainImageKey];
    }
    
    if (![adResponseDictionary objectForKey:EcpmKey] || ![[adResponseDictionary objectForKey:EcpmKey] isKindOfClass:[NSNumber class]]) {
        LogDebug(@"Ecpm not present in the ad response");
    } else {
        [assets setObject:[adResponseDictionary objectForKey:EcpmKey] forKey:kNativeEcpmKey];
    }
    
    //    [assets setObject:[adObj objectForKey:StarRatingKey] forKey:kNativeStarRatingKey];//not supported
    
    if ([adBody objectForKey:CustomAssetsKey] != nil)
        [assets setObject:[adBody objectForKey:CustomAssetsKey] forKey:kNativeCustomAssetsKey];
    
    if ([adBody objectForKey:SponsoredByTagKey] && [[adBody objectForKey:SponsoredByTagKey] isKindOfClass:[NSString class]]) {
        [assets setObject:[adBody objectForKey:SponsoredByTagKey] forKey:kNativeSponsoredByTagKey];
    }
    
    if ([adBody objectForKey:SponsoredByKey] && [[adBody objectForKey:SponsoredByKey] isKindOfClass:[NSString class]]) {
        [assets setObject:[adBody objectForKey:SponsoredByKey] forKey:kNativeSponsoredKey];
    }
    
    if (![adBody objectForKey:LandingUrlKey] || ![[adBody objectForKey:LandingUrlKey] isKindOfClass:[NSString class]] || [[adBody objectForKey:LandingUrlKey] length] == 0 ) {
        [assets setObject:@"" forKey:kNativeLandingUrlKey];
    }else {
        [assets setObject:[adBody objectForKey:LandingUrlKey] forKey:kNativeLandingUrlKey];
    }
    
    id trackingObjects = [adBody objectForKey:TrackingUrlKey];
    
    //adding impressions and viewables to the impression tracker list
    [impTrackers addObjectsFromArray:[trackingObjects objectForKey:ImpressionTrackerKey]];
    if ([trackingObjects objectForKey:ViewableImpressionKey] && [[trackingObjects objectForKey:ViewableImpressionKey] isKindOfClass:[NSArray class]] && [[trackingObjects objectForKey:ViewableImpressionKey] count] > 0) {
        [assets setObject:[trackingObjects objectForKey:ViewableImpressionKey] forKey:kNativeViewableImpressionsKey];
    }
    
    [assets setObject:impTrackers forKey:kNativeImpressionsKey];
    [assets setObject:[trackingObjects objectForKey:ClickTrackerKey] forKey:kNativeClicksKey];
    
    //custom actions added directly as a dict of actions and urls
    if ([trackingObjects objectForKey:CustomActionsKey] != nil)
        [assets setObject:[trackingObjects objectForKey:CustomActionsKey] forKey:kNativeCustomActionsKey];
    
    [self.adConfigsSet addObject:adConfig];
    
    return self.adConfigsSet;
}

#pragma mark - parsing and validation
- (void) parseNetworksObject:(id)networksObject error:(NSError **)error
{
    if (networksObject && ![networksObject isKindOfClass:[NSArray class]]) {
        [self safeAssignError:error code:AdResponseJSONHasInvalidNetworkData description:[NSString stringWithFormat:@"Expected object for key \"%@\" to be an array. Actual: %@", NetworkResponseKey, networksObject]];
        return;
    }
}

- (BOOL)validateNetworkObject:(id)networkObject error:(NSError **)error
{
    if (![networkObject isKindOfClass:[NSDictionary class]]) {
        [self safeAssignError:error code:AdResponseIsNotValidJSON description:[NSString stringWithFormat:@"Network object is not a dictionary: %@.", networkObject]];
        return NO;
    }
    
    if (![networkObject objectForKey:NetworkProviderDataKey] || ![[networkObject objectForKey:NetworkProviderDataKey] isKindOfClass:[NSString class]] || [[networkObject objectForKey:NetworkProviderDataKey] length] == 0 ) {
        return NO;
    }
    NSString *providerDataAsString = [networkObject objectForKey:NetworkProviderDataKey];
    NSData *data = [providerDataAsString dataUsingEncoding:NSUTF8StringEncoding];
    
    id providerData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    
    if (![providerData isKindOfClass:[NSDictionary class]]) {
        [self safeAssignError:error code:AdResponseJSONHasInvalidNetworkData description:[NSString stringWithFormat:@"Network object key:%@ is not a dictionary: %@.",NetworkProviderDataKey, networkObject]];
        return NO;
    }
    
    if (![providerData objectForKey:NetworkProviderClassNameKey] || ![[providerData objectForKey:NetworkProviderClassNameKey] isKindOfClass:[NSString class]] || [[providerData objectForKey:NetworkProviderClassNameKey] length] == 0 ) {
        return NO;
    }
    
    if (![[networkObject objectForKey:TrackingUrlKey] isKindOfClass:[NSDictionary class]]) {
        [self safeAssignError:error code:AdResponseJSONHasInvalidNetworkData description:[NSString stringWithFormat:@"Network object key:%@ is not a dictionary: %@.",TrackingUrlKey, networkObject]];
        return NO;
    }
    
    id trackingObjects = [networkObject objectForKey:TrackingUrlKey];
    if ([[trackingObjects objectForKey:ImpressionTrackerKey] count] == 0 || [[trackingObjects objectForKey:ClickTrackerKey] count] == 0) {
        [self safeAssignError:error code:AdResponseJSONHasInvalidNetworkData description:[NSString stringWithFormat:@"Network object key:%@ does not contain valid keys: %@.",TrackingUrlKey, networkObject]];
        return NO;
    }
    
    return YES;
}

- (BOOL) validateAdObject:(id)adObject error:(NSError **)error
{
    if (![adObject isKindOfClass:[NSDictionary class]]) {
        [self safeAssignError:error code:AdResponseIsNotValidJSON description:[NSString stringWithFormat:@"Ad object is not a dictionary."]];
        return NO;
    }
    
    if (![[adObject objectForKey:TrackingUrlKey] isKindOfClass:[NSDictionary class]]) {
        [self safeAssignError:error code:AdResponseIsNotValidJSON description:[NSString stringWithFormat:@"Tracking object key:%@ is not a dictionary.",TrackingUrlKey]];
        return NO;
    }
    
    id trackingObjects = [adObject objectForKey:TrackingUrlKey];
    if ([[trackingObjects objectForKey:ImpressionTrackerKey] count] == 0 || [[trackingObjects objectForKey:ClickTrackerKey] count] == 0) {
        [self safeAssignError:error code:AdResponseJSONHasInvalidNetworkData description:[NSString stringWithFormat:@"Ad object key:%@ does not contain valid keys.",TrackingUrlKey]];
        return NO;
    }
    
    if (![adObject objectForKey:AdTypeKey] || ![[adObject objectForKey:AdTypeKey] isKindOfClass:[NSString class]] || [[adObject objectForKey:AdTypeKey] length] == 0) {
        [self safeAssignError:error code:AdResponseIsNotValidJSON description:[NSString stringWithFormat:@"Ad object does not contain ad type."]];
        LogDebug(@"Ad Object:%@",adObject);
        return NO;
    }
    
    return YES;
}

- (BOOL)validateVideoAdObject:(id)adBody error:(NSError **)error
{
    /* No checks for video experience is done */
    
    //Check if video assets dictionary is present
    if (![adBody objectForKey:VideoAssetsKey] || ![[adBody objectForKey:VideoAssetsKey] isKindOfClass:[NSDictionary class]] || [[adBody objectForKey:VideoAssetsKey] count] == 0) {
        [self safeAssignError:error code:AdResponseIsNotValidJSON description:[NSString stringWithFormat:@"Ad object does not contain video dictionary."]];
        LogDebug(@"Ad Object:%@",adBody);
        return NO;
    }
    
    NSDictionary *videoAssets = (NSDictionary *)[adBody objectForKey:VideoAssetsKey];
    
    //check if video sources is present
    if (![videoAssets objectForKey:VideoSourcesKey] || ![[videoAssets objectForKey:VideoSourcesKey] isKindOfClass:[NSArray class]] || [[videoAssets objectForKey:VideoSourcesKey] count] == 0) {
        [self safeAssignError:error code:AdResponseIsNotValidJSON description:[NSString stringWithFormat:@"Video asset doesnt contain sources."]];
        LogDebug(@"Video Object:%@",videoAssets);
        return NO;
    }
    
    //check if embed type is present
    if (![videoAssets objectForKey:VideoEmbedTypeKey] || ![[videoAssets objectForKey:VideoEmbedTypeKey] isKindOfClass:[NSString class]] || [[videoAssets objectForKey:VideoEmbedTypeKey] length] == 0) {
        [self safeAssignError:error code:AdResponseIsNotValidJSON description:[NSString stringWithFormat:@"Video asset doesnt contain embed type."]];
        LogDebug(@"Video Object:%@",videoAssets);
        return NO;
    }
    //Check if embed type is not iframe or vast
    if ([[videoAssets objectForKey:VideoEmbedTypeKey] isEqualToString:VideoEmbedTypeIframeKey] || [[videoAssets objectForKey:VideoEmbedTypeKey] isEqualToString:VideoEmbedTypeVastKey]) {
        [self safeAssignError:error code:AdResponseIsNotValidJSON description:[NSString stringWithFormat:@"Video embed type is not native or youtube."]];
        LogDebug(@"Video Object:%@",videoAssets);
        return NO;
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

- (void)safeAssignError:(NSError **)error code:(AdResponseDeserializationErrorCode)code userInfo:(NSDictionary *)userInfo
{
    if (error) {
        *error = [self deserializationErrorWithCode:code userInfo:userInfo];
    }
}

- (void)safeAssignError:(NSError **)error code:(AdResponseDeserializationErrorCode)code description:(NSString *)description
{
    [self safeAssignError:error code:code description:description underlyingError:nil];
}

- (void)safeAssignError:(NSError **)error code:(AdResponseDeserializationErrorCode)code description:(NSString *)description underlyingError:(NSError *)underlyingError
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

- (NSError *)deserializationErrorWithCode:(AdResponseDeserializationErrorCode)code userInfo:(NSDictionary *)userInfo
{
    return [NSError errorWithDomain:AdResponseDeserializationErrorDomain
                               code:code
                           userInfo:userInfo];
}

@end
