//
//  PMNativeAdAdapter.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 30/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "PMNativeAdAdapter.h"
#import "AdDestinationDisplayAgent.h"
#import "InstanceProvider.h"
#import "AdErrors.h"
#import "PMAdChoicesView.h"
#import "AdAssets.h"

#define kImpressionTrackerURLsKey   @"impressions"
#define kViewabilityTrackerURLsKey  @"viewability"
#define kDefaultClickThroughURLKey  @"landingUrl"
#define kClickTrackerURLsKey        @"clicks"
#define kIsBackupClassRequiredKey   @"isBackupClassRequired"

@interface PMNativeAdAdapter () <AdDestinationDisplayAgentDelegate>

@property (nonatomic, readonly, strong) AdDestinationDisplayAgent *destinationDisplayAgent;
@property (nonatomic, weak) UIViewController *rootViewController;
@property (nonatomic, copy) void (^actionCompletionBlock)(BOOL, NSError *);

@end

@implementation PMNativeAdAdapter

@synthesize nativeAssets = _nativeAssets;
@synthesize defaultClickThroughURL = _defaultClickThroughURL;
@synthesize isBackupClassRequired = _isBackupClassRequired;

- (instancetype)initWithAdProperties:(NSMutableDictionary *)assets
{
    if (self = [super init]) {
        BOOL valid = YES;
        
        NSArray *impressionTrackers = [assets objectForKey:kImpressionTrackerURLsKey];
        if (![impressionTrackers isKindOfClass:[NSArray class]] || [impressionTrackers count] < 1) {
            valid = NO;
        } else {
            _impressionTrackers = impressionTrackers;
        }
        
        NSArray *viewabilityTrackers = [assets objectForKey:kViewabilityTrackerURLsKey];
        if ([viewabilityTrackers isKindOfClass:[NSArray class]] && [viewabilityTrackers count] > 0) {
            _viewabililityTrackers = viewabilityTrackers;
        }

        NSArray *clickTrackers = [assets objectForKey:kClickTrackerURLsKey];
        if (![clickTrackers isKindOfClass:[NSArray class]] || [clickTrackers count] < 1) {
            valid = NO;
        } else {
            _clickTrackers = clickTrackers;
        }
        
        _defaultClickThroughURL = [NSURL URLWithString:[assets objectForKey:kDefaultClickThroughURLKey]];

        _isBackupClassRequired = [[assets objectForKey:kIsBackupClassRequiredKey] boolValue];
        
//        [assets removeObjectsForKeys:[NSArray arrayWithObjects:kImpressionTrackerURLsKey, kClickTrackerURLsKey, kDefaultClickThroughURLKey,kIsBackupClassRequiredKey, nil]];

        PMAdChoicesView *adChoicesView = [[PMAdChoicesView alloc] initWithPrivacyInfo:assets];
        if ([adChoicesView getPMAdChoicesView] != nil) {
            [assets setObject:[adChoicesView getPMAdChoicesView] forKey:kNativeAdChoicesKey];
        }

        _nativeAssets = assets;
        
        if (!valid) {
            return nil;
        }
        
        _destinationDisplayAgent = [[InstanceProvider sharedProvider] buildAdDestinationDisplayAgentWithDelegate:self];
    }
    
    return self;
}

- (void)dealloc
{
    [_destinationDisplayAgent cancel];
    [_destinationDisplayAgent setDelegate:nil];
}

- (void)displayContentForURL:(NSURL *)URL rootViewController:(UIViewController *)controller
                  completion:(void (^)(BOOL success, NSError *error))completionBlock
{
    NSError *error = nil;
    
    if (!controller) {
        error = AdNSErrorForContentDisplayErrorMissingRootController();
    }
    
    if (!URL || ![URL isKindOfClass:[NSURL class]] || ![URL.absoluteString length]) {
        error = AdNSErrorForContentDisplayErrorInvalidURL();
    }
    
    if (error) {
        
        if (completionBlock) {
            completionBlock(NO, error);
        }
        
        return;
    }
    
    self.actionCompletionBlock = completionBlock;
    [self.destinationDisplayAgent displayDestinationForURL:URL];
}

#pragma mark - <AdAdapter>
- (BOOL)canOverrideClick
{
    return YES;
}

#pragma mark - <AdDestinationDisplayAgent>

- (UIViewController *)viewControllerToPresentModalView
{
    return [self.delegate viewControllerToPresentModalView];
}

- (void)displayAgentWillPresentModal
{
    
}

- (void)displayAgentWillLeaveApplication
{
    if (self.actionCompletionBlock) {
        self.actionCompletionBlock(YES, nil);
        self.actionCompletionBlock = nil;
    }
    
}

- (void)displayAgentDidDismissModal
{
    if (self.actionCompletionBlock) {
        self.actionCompletionBlock(YES, nil);
        self.actionCompletionBlock = nil;
    }
    
    self.rootViewController = nil;
}

@end
