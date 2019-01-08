//
//  AdDestinationDisplayAgent.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 06/10/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "AdDestinationDisplayAgent.h"
#import "URLResolver.h"
#import "URLActionInfo.h"
#import "InstanceProvider.h"
#import "LastResortDelegate.h"
#import "Constants.h"

static NSString * const kDisplayAgentErrorDomain = @"com.adsnative.displayagent";

@interface AdDestinationDisplayAgent ()

@property (nonatomic, strong) URLResolver *resolver;
@property (nonatomic, assign) BOOL isLoadingDestination;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= AN_IOS_6_0
@property (nonatomic, strong) SKStoreProductViewController *storeKitController;
#endif

- (void)presentStoreKitControllerWithItemIdentifier:(NSString *)identifier fallbackURL:(NSURL *)URL;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////


@implementation AdDestinationDisplayAgent

+ (AdDestinationDisplayAgent *)agentWithDelegate:(id<AdDestinationDisplayAgentDelegate>)delegate
{
    AdDestinationDisplayAgent *agent = [[AdDestinationDisplayAgent alloc] init];
    agent.delegate = delegate;
    return agent;
}

- (void)dealloc
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= AN_IOS_6_0
    // XXX: If this display agent is deallocated while a StoreKit controller is still on-screen,
    // nil-ing out the controller's delegate would leave us with no way to dismiss the controller
    // in the future. Therefore, we change the controller's delegate to a singleton object which
    // implements SKStoreProductViewControllerDelegate and is always around.
    
    self.storeKitController.delegate = [LastResortDelegate sharedDelegate];
#endif
    
}

- (void)displayDestinationForURL:(NSURL *)URL
{
    if (self.isLoadingDestination) return;
    self.isLoadingDestination = YES;
    
    [self.delegate displayAgentWillPresentModal];
//    [self.overlayView show];
    
    [self.resolver cancel];
//    [self.enhancedDeeplinkFallbackResolver cancel];
    
    __weak typeof(self) weakSelf = self;
    self.resolver = [[InstanceProvider sharedProvider] buildURLResolverWithURL:URL completion:^(URLActionInfo *suggestedAction, NSError *error) {
        typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            if (error) {
                [strongSelf failedToResolveURLWithError:error];
            } else {
                [strongSelf handleSuggestedURLAction:suggestedAction isResolvingEnhancedDeeplink:NO];
            }
        }
    }];
    
    [self.resolver start];
}

- (void)cancel
{
    if (self.isLoadingDestination) {
        self.isLoadingDestination = NO;
        [self.resolver cancel];

//        [self hideOverlay];
        [self.delegate displayAgentDidDismissModal];
    }
}

- (BOOL)handleSuggestedURLAction:(URLActionInfo *)actionInfo isResolvingEnhancedDeeplink:(BOOL)isResolvingEnhancedDeeplink
{
    if (actionInfo == nil) {
        [self failedToResolveURLWithError:[NSError errorWithDomain:kDisplayAgentErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL action"}]];
        return NO;
    }
    
    BOOL success = YES;
    
    switch (actionInfo.actionType) {
        case URLActionTypeStoreKit:
            [self showStoreKitProductWithParameter:actionInfo.iTunesItemIdentifier
                                       fallbackURL:actionInfo.iTunesStoreFallbackURL];
            break;
        case URLActionTypeOpenInSafari:
            [self openURLInApplication:actionInfo.safariDestinationURL];
            break;
        case URLActionTypeOpenInWebView:
//            [self showWebViewWithHTMLString:actionInfo.HTTPResponseString
//                                    baseURL:actionInfo.webViewBaseURL];
            break;
        default:
            [self failedToResolveURLWithError:[NSError errorWithDomain:kDisplayAgentErrorDomain code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Unrecognized URL action type."}]];
            success = NO;
            break;
    }
    
    return success;
}

- (void)showStoreKitProductWithParameter:(NSString *)parameter fallbackURL:(NSURL *)URL
{
    if ([PMStoreKitProvider deviceHasStoreKit]) {
        [self presentStoreKitControllerWithItemIdentifier:parameter fallbackURL:URL];
    } else {
        [self openURLInApplication:URL];
    }
}

- (void)openURLInApplication:(NSURL *)URL
{
        BOOL didOpenSuccessfully = [[UIApplication sharedApplication] openURL:URL];
        if (didOpenSuccessfully) {
            [self.delegate displayAgentWillLeaveApplication];
        } else {
            [self.delegate displayAgentDidDismissModal];
        }
        self.isLoadingDestination = NO;

}

- (void)failedToResolveURLWithError:(NSError *)error
{
    self.isLoadingDestination = NO;
    [self.delegate displayAgentDidDismissModal];
}

- (void)presentStoreKitControllerWithItemIdentifier:(NSString *)identifier fallbackURL:(NSURL *)URL
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= AN_IOS_6_0
    self.storeKitController = [PMStoreKitProvider buildController];
    self.storeKitController.delegate = self;
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:identifier
                                                           forKey:SKStoreProductParameterITunesItemIdentifier];
    [self.storeKitController loadProductWithParameters:parameters completionBlock:nil];
    
//    [self hideOverlay];
    [[self.delegate viewControllerToPresentModalView] presentViewController:self.storeKitController animated:YES completion:nil];
#endif
}

#pragma mark - <ANSKStoreProductViewControllerDelegate>

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController
{
    self.isLoadingDestination = NO;
    [self hideModalAndNotifyDelegate];
}

#pragma mark - Convenience Methods

- (void)hideModalAndNotifyDelegate
{
    [[self.delegate viewControllerToPresentModalView] dismissViewControllerAnimated:YES completion:^{
        [self.delegate displayAgentDidDismissModal];
    }];
}
@end
