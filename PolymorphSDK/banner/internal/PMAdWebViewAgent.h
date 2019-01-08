//
//  PMAdWebViewAgent.h
//
//  Created by Arvind Bharadwaj on 16/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AdDestinationDisplayAgent.h"
#import "PMWebView.h"

enum {
    PMAdWebViewEventAdDidAppear     = 0,
    PMAdWebViewEventAdDidDisappear  = 1
};
typedef NSUInteger PMAdWebViewEvent;

@protocol PMAdWebViewAgentDelegate;

//@class AdConfigs;
@class CLLocation;

@interface PMAdWebViewAgent : NSObject <PMWebViewDelegate, AdDestinationDisplayAgentDelegate>

@property (nonatomic, strong) PMWebView *view;
@property (nonatomic, weak) id<PMAdWebViewAgentDelegate> delegate;

- (id)initWithAdWebViewFrame:(CGRect)frame delegate:(id<PMAdWebViewAgentDelegate>)delegate;
- (void)loadString:(NSString *)htmlString;
- (void)loadRequest:(NSURL *)url;
- (void)delayLoadingRequest:(NSURL *)url;
- (void)rotateToOrientation:(UIInterfaceOrientation)orientation;
- (void)invokeJavaScriptForEvent:(PMAdWebViewEvent)event;
- (void)forceRedraw;

- (void)enableRequestHandling;
- (void)disableRequestHandling;

@end

@protocol PMAdWebViewAgentDelegate <NSObject>

- (UIViewController *)viewControllerForPresentingModalView;
- (void)adDidClose:(PMWebView *)ad;
- (void)adDidFinishLoadingAd:(PMWebView *)ad;
- (void)adDidFailToLoadAd:(PMWebView *)ad withError:(NSError *)error;
- (void)adActionWillBegin:(PMWebView *)ad;
- (void)adActionWillLeaveApplication:(PMWebView *)ad;
- (void)adActionDidFinish:(PMWebView *)ad;

@end

