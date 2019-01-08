//
//  PMBannerInternalCustomEvent.m
//
//  Created by Arvind Bharadwaj on 16/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PMBannerInternalCustomEvent.h"
#import "PMWebView.h"
#import "Logging.h"
#import "AdConfigs.h"
#import "InstanceProvider.h"
#import "AdAssets.h"

@interface PMBannerInternalCustomEvent ()

@property (nonatomic, strong) PMAdWebViewAgent *bannerAgent;

@property (nonatomic, strong) NSString *ecpm;
@property (nonatomic, strong) NSString *xhtml;

@end

@implementation PMBannerInternalCustomEvent

@synthesize bannerAgent = _bannerAgent;

- (BOOL)enableAutomaticImpressionAndClickTracking
{
    return NO;
}

- (void)requestAdWithSize:(CGSize)size customEventInfo:(NSDictionary *)info
{
    CGRect adWebViewFrame = CGRectMake(0, 0, size.width, size.height);
    NSString *urlString = [info objectForKey:kEmbedUrlKey];
    
    self.bannerAgent = [[PMAdWebViewAgent alloc] initWithAdWebViewFrame:adWebViewFrame delegate:self];
    
    BOOL isDelayedRequest = [[info objectForKey:@"isDelayedRequest"] isEqualToString:@"YES"];
    
    if (isDelayedRequest) {
        LogDebug(@"Loading banner without rendering into webview");
        //Conditionally delay loading ad into webview
        [self.bannerAgent delayLoadingRequest:[NSURL URLWithString:urlString]];
    } else {
        LogDebug(@"Loading banner");
        [self.bannerAgent loadRequest:[NSURL URLWithString:urlString]];
    }
}

- (void)dealloc
{
    self.bannerAgent.delegate = nil;
}

- (void)rotateToOrientation:(UIInterfaceOrientation)newOrientation
{
    [self.bannerAgent rotateToOrientation:newOrientation];
}

#pragma mark - PMAdWebViewAgentDelegate

- (UIViewController *)viewControllerForPresentingModalView
{
    return [self.delegate viewControllerForPresentingModalView];
}

- (void)adDidFinishLoadingAd:(PMWebView *)ad
{
    LogDebug(@"Polymorph banner did load");
    [self.delegate bannerCustomEvent:self didLoadAd:ad];
}

- (void)adDidFailToLoadAd:(PMWebView *)ad withError:(NSError *)error
{
    LogDebug(@"Polymorph banner did fail");
    [self.delegate bannerCustomEvent:self didFailToLoadAdWithError:error];
}

- (void)adDidClose:(PMWebView *)ad
{
    //don't care
}

- (void)adActionWillBegin:(PMWebView *)ad
{
//    LogInfo(@"Polymorph banner will begin action");
//    [self.delegate bannerCustomEventWillBeginAction:self];
}

- (void)adActionDidFinish:(PMWebView *)ad
{
//    LogInfo(@"Polymorph banner did finish action");
//    [self.delegate bannerCustomEventDidFinishAction:self];
}

- (void)adActionWillLeaveApplication:(PMWebView *)ad
{
    LogDebug(@"Polymorph banner will leave application");
    [self.delegate bannerCustomEventWillLeaveApplication:self];
}


@end
