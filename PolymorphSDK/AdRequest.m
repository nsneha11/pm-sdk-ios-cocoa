//
//  AdRequest.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "AdRequest.h"
#import "CustomEventDelegate.h"
#import "AdServerPinger.h"
#import "InstanceProvider.h"
#import "IANAdServerURLBuilder.h"
#import "CustomEvent.h"
#import "PMAdRequestTargeting.h"
#import "Logging.h"
#import "AdConfigs.h"
#import "AdErrors.h"
#import "PMNativeAd+Internal.h"
#import "PMNativeCustomEvent.h"
#import "PMAdResponse.h"
#import "PMNativeAd.h"
#import "PMBannerCustomEvent.h"
#import "PMCommonAdDelegate.h"
#import "PMNativeVideoCustomEvent.h"
#import "SDKConfigs.h"
#import "PMWebView.h"

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface AdRequest () <CustomEventDelegate, AdServerPingerDelegate, PMBannerCustomEventDelegate>

@property (nonatomic, copy) NSString *adUnitIdentifier;
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) NSDictionary *postDict;
@property (nonatomic, strong) AdServerPinger *pinger;
@property (nonatomic, copy) AdRequestHandler completionHandler;
@property (nonatomic, strong) CustomEvent *nativeCustomEvent;
@property (nonatomic, strong) PMBannerCustomEvent *bannerCustomEvent;
@property (nonatomic, strong) NSMutableDictionary *bannerCustomEventData;
@property (nonatomic, strong) AdConfigs *adConfiguration;
@property (nonatomic, strong) NSMutableOrderedSet *adConfigurationSet;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) int customEventPosition;
@property (nonatomic, assign) int requestType;

@end
static NSString * const ANDirectAdProviderName = @"adsnative";
static NSString * const ANS2SAdProviderName = @"s2s";
static NSString * const customEventPositionKey = @"customEventPosition";
static NSString * const apiAdRequestObjectKey = @"apiAdRequestObject";
static NSString * const viewContollerObjectKey = @"viewController";

@implementation AdRequest

- (instancetype)initWithAdUnitIdentifier:(NSString *)identifier requestType:(PM_REQUEST_TYPE)requestType
{
    self = [super init];
    if (self) {
        _adUnitIdentifier = [identifier copy];
        _pinger = [[InstanceProvider sharedProvider] buildAdServerPingerWithDelegate:self];
        _requestType = requestType;
    }
    return self;
}

- (void)dealloc
{
    [_pinger cancel];
    [_pinger setDelegate:nil];
    [_nativeCustomEvent setDelegate:nil];
    _viewController = nil;
}

#pragma mark - Public

+ (AdRequest *)requestWithAdUnitIdentifier:(NSString *)identifier requestType:(PM_REQUEST_TYPE)requestType
{
    return [[self alloc] initWithAdUnitIdentifier:identifier requestType:requestType];
}

- (void)startWithCompletionHandler:(AdRequestHandler)handler
{
    if (handler) {
        self.URL = [IANAdServerURLBuilder URLWithAdUnitID:self.adUnitIdentifier
                                                keywords:self.targeting.keywords
                                                desiredAssets:nil
                                                location:self.targeting.location
                                                testing:NO];
        
        [self assignCompletionHandler:handler];
        
        [self loadAdWithURL:self.URL];
    } else {
        LogWarn(@"Native Ad Request did not start - requires completion handler block.");
    }
}

- (void)startForAdSequence:(NSInteger)adSequence withCompletionHandler:(AdRequestHandler)handler
{
    if (handler) {
        //removed adsequence in the url builder call. Didn't see the need for it
        self.URL = [IANAdServerURLBuilder URLWithAdUnitID:self.adUnitIdentifier
                                              keywords:self.targeting.keywords
                                         desiredAssets:nil
                                              location:self.targeting.location
                                                 testing:NO];
        
        [self assignCompletionHandler:handler];
        
        [self loadAdWithURL:self.URL];
    } else {
        LogWarn(@"Native Ad Request did not start - requires completion handler block.");
    }
}

#pragma mark - Private

- (void)assignCompletionHandler:(AdRequestHandler)handler
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    // we explicitly create a block retain cycle here to prevent self from being deallocated if the developer
    // removes his strong reference to the request. This retain cycle is broken in
    // - (void)completeAdRequestWithAdObject:(NativeAd *)adObject error:(NSError *)error
    // when self.completionHandler is set to nil.
    self.completionHandler = ^(AdRequest *request, PMAdResponse *response, NSError *error) {
        handler(self, response, error);
    };
#pragma clang diagnostic pop
}

- (void)loadAdWithURL:(NSURL *)URL
{
    if (self.loading) {
        LogWarn(@"Ad request is already loading an ad. Wait for previous load to finish.");
        return;
    }
    
    LogInfo(@"Requesting for an ad");
    LogDebug(@"Ad Request URL:%@",self.URL);
    
    self.loading = YES;
    [self.pinger loadURL:URL];
}

- (void)getAdWithConfiguration:(AdConfigs *)configuration
{
    //Increment the customEventPosition for the next configuration object
    self.customEventPosition = self.customEventPosition + 1;
    
    if (configuration.customEventClass) {
        LogInfo(@"Looking for custom event class named %@.", configuration.customEventClass);
    }
    NSError *error = nil;
    if (![self validateResponseType:configuration.adtype]) {
        switch (self.requestType) {
            case PM_REQUEST_TYPE_BANNER:
                error = [NSError errorWithDomain:@"com.adsnative.iossdk.ad" code:204 userInfo:[NSDictionary dictionaryWithObject:@"Got a native ad for a banner request" forKey:NSLocalizedDescriptionKey]];
                [self completeBannerAdRequestWithAdView:nil error:error];
                return;
            default:
                error = [NSError errorWithDomain:@"com.adsnative.iossdk.ad" code:204 userInfo:[NSDictionary dictionaryWithObject:@"Got a banner ad for a native request" forKey:NSLocalizedDescriptionKey]];
                [self completeAdRequestWithAdObject:nil error:error];
                return;
        }
    }
    if ([configuration.adtype isEqualToString:@"banner"]) {
        self.bannerCustomEvent = [[InstanceProvider sharedProvider] buildBannerCustomEventFromCustomClass:configuration.customEventClass delegate:self];
    } else {
        self.nativeCustomEvent = [[InstanceProvider sharedProvider] buildNativeCustomEventFromCustomClass:configuration.customEventClass delegate:self];
    }

    if (self.nativeCustomEvent) {
        //Passing customEventPosition along with the customEventClassData to the adapter
        NSMutableDictionary *customEventData = [[NSMutableDictionary alloc] initWithDictionary:configuration.customEventClassData];
        
        [customEventData setObject:[NSString stringWithFormat:@"%d",self.customEventPosition] forKey:customEventPositionKey];
        
        if (self.viewController) {
            [customEventData setObject:self.viewController forKey:viewContollerObjectKey];
        }
        
        
        [self.nativeCustomEvent requestAdWithCustomEventInfo:customEventData];
    } else if (self.bannerCustomEvent) {
        NSMutableDictionary *customEventData = [[NSMutableDictionary alloc] initWithDictionary:configuration.customEventClassData];
        
        [customEventData setObject:[NSString stringWithFormat:@"%d", self.customEventPosition] forKey:customEventPositionKey];
        
        if (self.requestDelayedAd) {
            [customEventData setObject:@"YES" forKey:@"isDelayedRequest"];
        } else {
            [customEventData setObject:@"NO" forKey:@"isDelayedRequest"];
        }

        self.bannerCustomEventData = [[NSMutableDictionary alloc] initWithDictionary:customEventData];
        [self.bannerCustomEvent requestAdWithSize:[self.delegate containerSize] customEventInfo:customEventData];
    } else {
        LogInfo(@"Moving to the next ad response object returned.");
        //waterfall through the remaining configuration objects
        if ([self.adConfigurationSet count] >= 1) {
            
            self.adConfiguration = [self.adConfigurationSet objectAtIndex:0];
            [self.adConfigurationSet removeObjectAtIndex:0];
            
            [self getAdWithConfiguration:self.adConfiguration];
        } else {
            switch (_requestType) {
                case PM_REQUEST_TYPE_BANNER:
                    [self completeBannerAdRequestWithAdView:nil error:AdNSErrorForNoFill()];
                    break;
                default:
                    //This will be reached only when AN direct ad is empty
                    [self completeAdRequestWithAdObject:nil error:AdNSErrorForNoFill()];
            }
            
        }
    }
}

//For native/native video ads
- (void)completeAdRequestWithAdObject:(PMNativeAd *)adObject error:(NSError *)error
{
    self.loading = NO;
    
    if (!error) {
        LogInfo(@"Successfully loaded native ad.");
    } else {
        LogError(@"Ad failed to load with error: %@", error);
    }
    
    if (self.completionHandler) {
        if (self.nativeAd != nil) {
            SDKConfigs *configs = [self.delegate getSDKConfigs];
            if (configs != nil) {
                if (configs.renderingClass != nil) {
                    adObject.renderingClass = configs.renderingClass;
                }
                adObject.biddingInterval = configs.biddingInterval;
            }
            
            if (self.nativeAd) {
                adObject.adUnitID = self.nativeAd.adUnitID;
                adObject.delegate = self.nativeAd.delegate;
                adObject.internalDelegate = self.nativeAd.internalDelegate;
            }
        }
        PMAdResponse *response = [[PMAdResponse alloc] initWithAdType:@"native"];
        [response setPMNativeAdResponse:adObject];
        self.completionHandler(self, response, error);
//        self.completionHandler(self, adObject, error);
        self.completionHandler = nil;
    }
}

//For banner ads
- (void)completeBannerAdRequestWithAdView:(UIView *)bannerView error:(NSError *)error
{
    if (!error) {
        LogInfo(@"Successfully loaded banner ad.");
    } else {
        LogError(@"Banner ad failed to load with error: %@", error);
    }
    
    if (self.completionHandler == nil && [bannerView isKindOfClass:[PMWebView class]]) {
        if ([self.delegate respondsToSelector:@selector(isRenderedPMAd:)]) {
            [self.delegate isRenderedPMAd:bannerView];
        }
    }

    if (self.completionHandler) {
        PMAdResponse *response = [[PMAdResponse alloc] initWithAdType:@"banner"];
        [response setPMBannerAdResponse:bannerView];
        if (self.bannerCustomEventData != nil)
            [response setCustomEventData:self.bannerCustomEventData];
        self.completionHandler(self, response, error);
        self.completionHandler = nil;
    }
}

#pragma mark - <AdServerPingerDelegate>

- (void)pingerDidReceiveAdConfiguration:(NSMutableOrderedSet *)adConfigurations withNetworksList:(NSDictionary *)networksList
{
    //resetting customEventPositions
    self.customEventPosition = -1;
    
    self.adConfigurationSet = adConfigurations;
    
    if ([self.adConfigurationSet count] == 0) {
        LogInfo(@"Error: Failed to receive ad from any network or direct demand.");
        switch (self.requestType) {
            case PM_REQUEST_TYPE_BANNER:
                [self completeBannerAdRequestWithAdView:nil error:AdNSErrorForNoFill()];
                break;
            default:
                [self completeAdRequestWithAdObject:nil error:AdNSErrorForNoFill()];
                break;
        }
        return;
    }
    
    self.adConfiguration = [self.adConfigurationSet objectAtIndex:0];
    
    if(self.adConfiguration !=nil) {
        [self.adConfigurationSet removeObjectAtIndex:0];
    } else {
        LogInfo(@"Error: Failed to receive ad from any network or direct demand.");
        switch (self.requestType) {
            case PM_REQUEST_TYPE_BANNER:
                [self completeBannerAdRequestWithAdView:nil error:AdNSErrorForNoFill()];
                break;
            default:
                [self completeAdRequestWithAdObject:nil error:AdNSErrorForNoFill()];
                break;
        }
        return;
    }

    
    LogInfo(@"Received data from Polymorph to construct ad.\n");
    [self getAdWithConfiguration:self.adConfiguration];
}

- (void)pingerDidFailWithError:(NSError *)error
{
    LogDebug(@"Error: Couldn't retrieve an ad from Polymorph. Message: %@", error);
    switch (self.requestType) {
        case PM_REQUEST_TYPE_BANNER:
            [self completeBannerAdRequestWithAdView:nil error:AdNSErrorForNoFill()];
            break;
        default:
            [self completeAdRequestWithAdObject:nil error:AdNSErrorForNoFill()];
            break;
    }
}

#pragma mark - <CustomEventDelegate>

- (void)nativeCustomEvent:(CustomEvent *)event didLoadAd:(PMNativeAd *)adObject
{
    // Take the click trackers from the ad response to our set (only for third party network objects, the trackers have to be added).
    if (self.adConfiguration.clickTrackers.count >= 1) {
        [adObject.clickTrackers addObjectsFromArray:self.adConfiguration.clickTrackers];
    }
    
    // Add the impression trackers from the ad response to our set (only for third party network objects, the trackers have to be added).
    if (self.adConfiguration.impressionTrackers.count >= 1) {
        [adObject.impressionTrackers addObjectsFromArray:self.adConfiguration.impressionTrackers];
    }
    
    // Add the viewable impression trackers from the ad response to our set (only for third party network objects, the trackers have to be added).
    if (self.adConfiguration.viewabilityTrackers.count >= 1) {
        [adObject.viewabilityTrackers addObjectsFromArray:self.adConfiguration.viewabilityTrackers];
    }

    // Error if we don't have click trackers or impression trackers.
    if (adObject.clickTrackers.count < 1 || adObject.impressionTrackers.count < 1) {
        [self completeAdRequestWithAdObject:nil error:AdNSErrorForInvalidAdServerResponse(@"Invalid ad trackers")];
    } else {
        //adding provider name to the native ad object
        adObject.providerName = NSStringFromClass(event.class);
        if (event.class == [PMNativeVideoCustomEvent class] || event.class == [PMNativeCustomEvent class]) {
            adObject.providerName = ANDirectAdProviderName;
        }
        
        [self completeAdRequestWithAdObject:adObject error:nil];
    }
}

- (void)nativeCustomEvent:(CustomEvent *)event didFailToLoadAdWithError:(NSError *)error
{
    //Failure ping for no-fill
    if (self.adConfiguration.noFillTrackers) {
        LogInfo(@"No fill occurred for %@",NSStringFromClass(event.class));
        
        LogDebug(@"Firing %lu no fill trackers for %@",[self.adConfiguration.noFillTrackers count],NSStringFromClass(event.class));
        
        for (NSString *URL in self.adConfiguration.noFillTrackers) {
            LogDebug(@"Firing no fill tracker with url:%@",URL);
            [self trackMetricForURL:[NSURL URLWithString:URL]];
        }
    }

    
    if ([self.adConfigurationSet count] >= 1) {
        LogDebug(@"Error Loading ad. Loading the next response object");
        
        self.adConfiguration = [self.adConfigurationSet objectAtIndex:0];
        [self.adConfigurationSet removeObjectAtIndex:0];
        
        [self getAdWithConfiguration:self.adConfiguration];
    } else {
        //all networks and direct demand have returned a no-fill or network timed out.
        [self completeAdRequestWithAdObject:nil error:error];
    }
    
}

#pragma mark - <PMBannerCustomEventDelegate>
- (void)bannerCustomEvent:(PMBannerCustomEvent *)event didLoadAd:(UIView *)ad
{
    [self completeBannerAdRequestWithAdView:ad error:nil];
}

- (void)bannerCustomEvent:(PMBannerCustomEvent *)event didFailToLoadAdWithError:(NSError *)error
{
    [self completeBannerAdRequestWithAdView:nil error:error];
}

- (UIViewController *)viewControllerForPresentingModalView
{
    return self.viewController;
}


- (void)bannerCustomEventWillLeaveApplication:(PMBannerCustomEvent *)event
{
    if ([self.delegate respondsToSelector:@selector(userWillLeaveApplication)]) {
        [self.delegate userWillLeaveApplication];
    }
}

- (void)rotateToOrientation:(UIInterfaceOrientation)orientation
{
    if (self.bannerCustomEvent != nil && [self.bannerCustomEvent respondsToSelector:@selector(rotateToOrientation:)]) {
        [self.bannerCustomEvent rotateToOrientation:orientation];
    }
}

#pragma mark - Internal
- (void)trackMetricForURL:(NSURL *)URL
{
    NSMutableURLRequest *request = [[InstanceProvider sharedProvider] buildConfiguredURLRequestWithURL:URL];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    [NSURLConnection connectionWithRequest:request delegate:nil];
}

- (BOOL)validateResponseType:(NSString *)responseType
{
    if ([responseType isEqualToString:@"banner"]) {
        switch (self.requestType) {
            case PM_REQUEST_TYPE_BANNER:
                return true;
            case PM_REQUEST_TYPE_ALL:
                return true;
            default:
                return false;
        }
    } else {
        switch (self.requestType) {
            case PM_REQUEST_TYPE_BANNER:
                return false;
            default:
                return true;
        }
    }
}
@end
