//
//  PMAdWebViewAgent.m
//
//  Created by Arvind Bharadwaj on 16/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//


#import "PMAdWebViewAgent.h"
#import "Logging.h"
#import "AdDestinationDisplayAgent.h"
#import "PMWebView.h"
#import "InstanceProvider.h"

#ifndef NSFoundationVersionNumber_iOS_6_1
#define NSFoundationVersionNumber_iOS_6_1 993.00
#endif

#define MPOffscreenWebViewNeedsRenderingWorkaround() (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1)

@interface PMAdWebViewAgent () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) AdDestinationDisplayAgent *destinationDisplayAgent;
@property (nonatomic, assign) BOOL shouldHandleRequests;
@property (nonatomic, assign) BOOL userInteractedWithWebView;
@property (nonatomic, strong) UITapGestureRecognizer *userInteractionRecognizer;
@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) BOOL hasPerformedInitialLoad;

- (BOOL)shouldIntercept:(NSURL *)URL navigationType:(UIWebViewNavigationType)navigationType;
- (void)interceptURL:(NSURL *)URL;

@property (nonatomic, strong) UIWebView *webView;
@end

@implementation PMAdWebViewAgent

@synthesize delegate = _delegate;
@synthesize destinationDisplayAgent = _destinationDisplayAgent;
@synthesize shouldHandleRequests = _shouldHandleRequests;
@synthesize view = _view;
@synthesize userInteractedWithWebView = _userInteractedWithWebView;
@synthesize userInteractionRecognizer = _userInteractionRecognizer;

- (id)initWithAdWebViewFrame:(CGRect)frame delegate:(id<PMAdWebViewAgentDelegate>)delegate;
{
    self = [super init];
    if (self) {
        _frame = frame;
        
        self.destinationDisplayAgent = [[InstanceProvider sharedProvider] buildAdDestinationDisplayAgentWithDelegate:self];
        self.delegate = delegate;
        self.shouldHandleRequests = YES;

        self.userInteractionRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleInteraction:)];
        self.userInteractionRecognizer.cancelsTouchesInView = NO;
        self.userInteractionRecognizer.delegate = self;
        
    }
    return self;
}

- (void)dealloc
{
    self.userInteractionRecognizer.delegate = nil;
    [self.userInteractionRecognizer removeTarget:self action:nil];
    [self.destinationDisplayAgent cancel];
    [self.destinationDisplayAgent setDelegate:nil];
    self.view.delegate = nil;
}

- (void)handleInteraction:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        self.userInteractedWithWebView = YES;
    }
}

#pragma mark - <UIGestureRecognizerDelegate>

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
{
    return YES;
}


#pragma mark - Public

- (void)loadString:(NSString *)htmlString
{
    // Initialize web view
    if (self.view != nil) {
        self.view.delegate = nil;
        [self.view removeFromSuperview];
        self.view = nil;
    }
    self.view = [[PMWebView alloc] initWithFrame:self.frame forceUIWebView:NO];
    self.view.delegate = self;
    [self.view addGestureRecognizer:self.userInteractionRecognizer];
    
//    [self.view pm_setScrollable:configuration.scrollable];
    
    
    [self.view disableJavaScriptDialogs];
    
    [self.view loadHTMLString:htmlString baseURL:nil];
    
}

- (void)initializePMWebView
{
    // Initialize web view
    if (self.view != nil) {
        self.view.delegate = nil;
        [self.view removeFromSuperview];
        self.view = nil;
    }
    self.view = [[PMWebView alloc] initWithFrame:self.frame forceUIWebView:NO];
    self.view.delegate = self;
    [self.view addGestureRecognizer:self.userInteractionRecognizer];
    [self.view disableJavaScriptDialogs];
}

- (void)loadRequest:(NSURL *)url
{
    [self initializePMWebView];
    [self.view loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)delayLoadingRequest:(NSURL *)url
{
    [self initializePMWebView];

    [self.view saveRequestForDelayedLoad:[NSURLRequest requestWithURL:url]];
    //Fake a callback without actually loading the ad
    [self pmWebViewDidFinishLoad:self.view];
}

- (void)invokeJavaScriptForEvent:(PMAdWebViewEvent)event
{
    switch (event) {
        case PMAdWebViewEventAdDidAppear:
            [self.view stringByEvaluatingJavaScriptFromString:@"webviewDidAppear();"];
            break;
        case PMAdWebViewEventAdDidDisappear:
            [self.view stringByEvaluatingJavaScriptFromString:@"webviewDidClose();"];
            break;
        default:
            break;
    }
}

- (void)disableRequestHandling
{
    self.shouldHandleRequests = NO;
    [self.destinationDisplayAgent cancel];
}

- (void)enableRequestHandling
{
    self.shouldHandleRequests = YES;
}

#pragma mark - <AdDestinationDisplayAgentDelegate>

- (UIViewController *)viewControllerToPresentModalView
{
    return [self.delegate viewControllerForPresentingModalView];
}

- (void)displayAgentWillPresentModal
{
    [self.delegate adActionWillBegin:self.view];
}

- (void)displayAgentWillLeaveApplication
{
    [self.delegate adActionWillLeaveApplication:self.view];
}

- (void)displayAgentDidDismissModal
{
    [self.delegate adActionDidFinish:self.view];
}


#pragma mark - <PMWebViewDelegate>

- (BOOL)pmWebView:(PMWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{
//    return YES;
//    if (!self.shouldHandleRequests) {
//        return NO;
//    }
    
    NSURL *URL = [request URL];
    if ([self shouldIntercept:URL navigationType:navigationType]) {
        
        // Disable intercept without user interaction
        if (!self.userInteractedWithWebView) {
            LogInfo(@"Redirect without user interaction detected");
            return NO;
        }
        
        [self interceptURL:URL];
        return NO;
    }
//    else {
//        // don't handle any deep links without user interaction
//        return self.userInteractedWithWebView;
//    }
    return YES;
}

- (void)pmWebViewDidStartLoad:(PMWebView *)webView
{
    [self.view disableJavaScriptDialogs];
}

- (void)pmWebViewDidFinishLoad:(PMWebView *)webView
{
    if (!self.hasPerformedInitialLoad) {
        self.hasPerformedInitialLoad = YES;
    }
    
    if ([self.delegate respondsToSelector:@selector(adDidFinishLoadingAd:)]) {
        [self.delegate adDidFinishLoadingAd:webView];
    }
}

- (void)pmWebView:(PMWebView *)webView didFailLoadWithError:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(adDidFailToLoadAd:withError:)]) {
        [self.delegate adDidFailToLoadAd:webView withError:error];
    }
}


#pragma mark - URL Interception
- (BOOL)shouldIntercept:(NSURL *)URL navigationType:(UIWebViewNavigationType)navigationType
{
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        return YES;
    } else if (navigationType == UIWebViewNavigationTypeOther && self.userInteractedWithWebView) {
        return YES;
    } else {
        return NO;
    }
}

- (void)interceptURL:(NSURL *)URL
{
    NSURL *redirectedURL = URL;
    [self.destinationDisplayAgent displayDestinationForURL:redirectedURL];
}

#pragma mark - Utility

- (void)rotateToOrientation:(UIInterfaceOrientation)orientation
{
    [self forceRedraw];
}

- (void)forceRedraw
{
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    int angle = -1;
    switch (orientation) {
        case UIInterfaceOrientationPortrait: angle = 0; break;
        case UIInterfaceOrientationLandscapeLeft: angle = 90; break;
        case UIInterfaceOrientationLandscapeRight: angle = -90; break;
        case UIInterfaceOrientationPortraitUpsideDown: angle = 180; break;
        default: break;
    }
    
    if (angle == -1) return;
    
    // UIWebView doesn't seem to fire the 'orientationchange' event upon rotation, so we do it here.
    NSString *orientationEventScript = [NSString stringWithFormat:
                                        @"window.__defineGetter__('orientation',function(){return %d;});"
                                        @"(function(){ var evt = document.createEvent('Events');"
                                        @"evt.initEvent('orientationchange',true,true);window.dispatchEvent(evt);})();",
                                        angle];
    [self.view stringByEvaluatingJavaScriptFromString:orientationEventScript];
    
    // XXX: If the UIWebView is rotated off-screen (which may happen with interstitials), its
    // content may render off-center upon display. We compensate by setting the viewport meta tag's
    // 'width' attribute to be the size of the webview.
    NSString *viewportUpdateScript = [NSString stringWithFormat:
                                      @"document.querySelector('meta[name=viewport]')"
                                      @".setAttribute('content', 'width=%f;', false);",
                                      self.view.frame.size.width];
    [self.view stringByEvaluatingJavaScriptFromString:viewportUpdateScript];
    
    // XXX: In iOS 7, off-screen UIWebViews will fail to render certain image creatives.
    // Specifically, creatives that only contain an <img> tag whose src attribute uses a 302
    // redirect will not be rendered at all. One workaround is to temporarily change the web view's
    // internal contentInset property; this seems to force the web view to re-draw.
    if (MPOffscreenWebViewNeedsRenderingWorkaround()) {
        if ([self.view respondsToSelector:@selector(scrollView)]) {
            UIScrollView *scrollView = self.view.scrollView;
            UIEdgeInsets originalInsets = scrollView.contentInset;
            UIEdgeInsets newInsets = UIEdgeInsetsMake(originalInsets.top + 1,
                                                      originalInsets.left,
                                                      originalInsets.bottom,
                                                      originalInsets.right);
            scrollView.contentInset = newInsets;
            scrollView.contentInset = originalInsets;
        }
    }
}

@end

