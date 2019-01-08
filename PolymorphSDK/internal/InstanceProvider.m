//
//  InstanceProvider.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 22/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "InstanceProvider.h"
#import "AdServerPinger.h"
#import "CustomEvent.h"
#import "Logging.h"
#import "AdSource.h"
#import "AdSourceDelegate.h"
#import "StreamAdPlacementData.h"
#import "PMAdPositions.h"
#import "StreamAdPlacer.h"
#import "GeoLocationProvider.h"
#import "AdDestinationDisplayAgent.h"
#import "URLResolver.h"
#import "PMBannerCustomEvent.h"
#import "PMBannerAdManager.h"
#import "PMBannerCustomEventDelegate.h"
#import "PMBannerAdManagerDelegate.h"
#import "IANAdServerURLBuilder.h"
@interface InstanceProvider ()

@property (nonatomic, copy) NSString *userAgent;
@property (nonatomic, strong) NSMutableDictionary *singletons;

@end


@implementation InstanceProvider

@synthesize userAgent = _userAgent;
@synthesize singletons = _singletons;

static InstanceProvider *sharedProvider = nil;

+ (instancetype)sharedProvider
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedProvider = [[self alloc] init];
    });
    
    return sharedProvider;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.singletons = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id)singletonForClass:(Class)klass provider:(SingletonProviderBlock)provider
{
    id singleton = [self.singletons objectForKey:klass];
    if (!singleton) {
        singleton = provider();
        [self.singletons setObject:singleton forKey:(id<NSCopying>)klass];
    }
    return singleton;
}

#pragma mark - utils

- (GeoLocationProvider *)sharedGeoLocationProvider
{
    return [self singletonForClass:[GeoLocationProvider class] provider:^id{
        return [GeoLocationProvider sharedProvider];
    }];
}

#pragma mark - Fetching Ads
- (NSMutableURLRequest *)buildConfiguredURLRequestWithURL:(NSURL *)URL
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [request setHTTPShouldHandleCookies:YES];
    [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
//    IANAdServerURLBuilder *serverBuilder = [[IANAdServerURLBuilder alloc] init];
    
    return request;
}

- (NSString *)userAgent
{
    if (!_userAgent) {
        self.userAgent = [[[UIWebView alloc] init] stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    }
    
    return _userAgent;
}

- (AdServerPinger *)buildAdServerPingerWithDelegate:(id<AdServerPingerDelegate>)delegate
{
    return [(AdServerPinger *)[AdServerPinger alloc] initWithDelegate:delegate];
}

#pragma mark - URL Handling

- (URLResolver *)buildURLResolverWithURL:(NSURL *)URL completion:(URLResolverCompletionBlock)completion;
{
    return [URLResolver resolverWithURL:URL completion:completion];
}

- (AdDestinationDisplayAgent *)buildAdDestinationDisplayAgentWithDelegate:(id<AdDestinationDisplayAgentDelegate>)delegate
{
    return [AdDestinationDisplayAgent agentWithDelegate:delegate];
}

#pragma mark - Native

- (CustomEvent *)buildNativeCustomEventFromCustomClass:(Class)customClass
                                                      delegate:(id<CustomEventDelegate>)delegate
{
    CustomEvent *customEvent = [[customClass alloc] init];
    if (![customEvent isKindOfClass:[CustomEvent class]]) {
        LogError(@"**** Custom Event Class: %@ does not extend CustomEvent ****", NSStringFromClass(customClass));
        return nil;
    }
    customEvent.delegate = delegate;
    return customEvent;
}

- (AdSource *)buildNativeAdSourceWithDelegate:(id<AdSourceDelegate>)delegate
{
    AdSource *source = [AdSource source];
    source.delegate = delegate;
    return source;
}

- (StreamAdPlacementData *)buildStreamAdPlacementDataWithPositioning:(PMAdPositions *)positioning
{
    StreamAdPlacementData *placementData = [[StreamAdPlacementData alloc] initWithPositioning:positioning];
    return placementData;
}


- (StreamAdPlacer *)buildStreamAdPlacerWithViewController:(UIViewController *)controller adPositioning:(PMAdPositions *)positioning defaultAdRenderingClass:defaultAdRenderingClass
{
    return [StreamAdPlacer placerWithViewController:controller adPositions:positioning defaultAdRenderingClass:defaultAdRenderingClass];
}

#pragma mark - Banners

//- (PMBannerAdManager *)buildPMBannerAdManagerWithDelegate:(id<PMBannerAdManagerDelegate>)delegate
//{
//    return [(PMBannerAdManager *)[PMBannerAdManager alloc] initWithDelegate:delegate];
//}
//
//- (PMBaseBannerAdapter *)buildBannerAdapterForConfiguration:(AdConfiguration *)configuration
//                                                   delegate:(id<PMBannerAdapterDelegate>)delegate
//{
//    if (configuration.customEventClass) {
//        return [(PMBannerCustomEventAdapter *)[PMBannerCustomEventAdapter alloc] initWithDelegate:delegate];
//    }
//    
//    return nil;
//}

- (PMBannerCustomEvent *)buildBannerCustomEventFromCustomClass:(Class)customClass
                                                      delegate:(id<PMBannerCustomEventDelegate>)delegate
{
    PMBannerCustomEvent *customEvent = [[customClass alloc] init];
    if (![customEvent isKindOfClass:[PMBannerCustomEvent class]]) {
        LogError(@"**** Custom Event Class: %@ does not extend PMBannerCustomEvent ****", NSStringFromClass(customClass));
        return nil;
    }
    customEvent.delegate = delegate;
    return customEvent;
}
@end
