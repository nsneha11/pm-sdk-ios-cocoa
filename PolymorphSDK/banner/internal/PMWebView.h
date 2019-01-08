//
//  PMWebView.h
//
//  Created by Arvind Bharadwaj on 16/11/17.
//  Copyright © 2017 AdsNative. All rights reserved.
//


/***
 * PMWebView
 * This class is a wrapper class for WKWebView and UIWebView. Internally, it utilizes WKWebView when possible, and
 * falls back on UIWebView only when WKWebView isn't available (i.e., in iOS 7). PMWebView's interface is meant to
 * imitate UIWebView, and, in many cases, PMWebView can act as a drop-in replacement for UIWebView. PMWebView also
 * blocks all JavaScript text boxes from appearing.
 *
 * While `stringByEvaluatingJavaScriptFromString:` does exist for UIWebView compatibility reasons, it's highly
 * recommended that the caller uses `evaluateJavaScript:completionHandler:` whenever code can be reworked
 * to make use of completion blocks to keep the advantages of asynchronicity. It solely fires off the javascript
 * execution within WKWebView and does not wait or return.
 *
 * PMWebView currently does not support a few other features of UIWebView -- such as pagination -- as WKWebView also
 * does not contain support.
 ***/

#import <UIKit/UIKit.h>
#import "PMCommonAdDelegate.h"
@class PMWebView;

@protocol PMWebViewDelegate <NSObject>

@optional

- (BOOL)pmWebView:(PMWebView *)webView
shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType;

- (void)pmWebViewDidStartLoad:(PMWebView *)webView;

- (void)pmWebViewDidFinishLoad:(PMWebView *)webView;

- (void)pmWebView:(PMWebView *)webView
didFailLoadWithError:(NSError *)error;

@end

typedef void (^PMWebViewJavascriptEvaluationCompletionHandler)(id result, NSError *error);

@interface PMWebView : UIView

// If you -need- UIWebView for some reason, use this method to init and send `YES` to `forceUIWebView` to be sure
// you're using UIWebView regardless of OS. If any other `init` method is used, or if `NO` is used as the forceUIWebView
// parameter, WKWebView will be used when available.
- (instancetype)initWithFrame:(CGRect)frame forceUIWebView:(BOOL)forceUIWebView;

@property (weak, nonatomic) id<PMWebViewDelegate> delegate;

@property (nonatomic, readonly, getter=isLoading) BOOL loading;

// These methods and properties are non-functional below iOS 9. If you call or try to set them, they'll do nothing.
// For the properties, if you try to access them, you'll get `NO` 100% of the time. They are entirely hidden when
// compiling with iOS 8 SDK or below.
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
- (void)loadData:(NSData *)data
        MIMEType:(NSString *)MIMEType
textEncodingName:(NSString *)encodingName
         baseURL:(NSURL *)baseURL;

@property (nonatomic) BOOL allowsLinkPreview;
@property (nonatomic, readonly) BOOL allowsPictureInPictureMediaPlayback;
#endif

/*
 * Tells us if the PMWebView returned has webview loaded or not.
 */
@property (nonatomic, assign) BOOL isViewLoaded;

/*
 * Tells us if the request being made is a delayed one where the webview doesn't get loaded until
 * `loadDelayedRequest` is called
 */
@property (nonatomic, assign) BOOL isDelayedRequest;

/*
 * In case you want to delay the load of banner into webview (in cases where the ad is being cached),
 * then you call the following two methods to ensure that impressions aren't prematurely tracked, which
 * might happen as soon as the ad is loaded into the webview.
 */
- (void)saveRequestForDelayedLoad:(NSURLRequest *)request;
- (void)loadDelayedRequest;

- (void)loadHTMLString:(NSString *)string
               baseURL:(NSURL *)baseURL;

- (void)loadRequest:(NSURLRequest *)request;
- (void)stopLoading;
- (void)reload;

@property (nonatomic, readonly) BOOL canGoBack;
@property (nonatomic, readonly) BOOL canGoForward;
- (void)goBack;
- (void)goForward;

@property (nonatomic) BOOL scalesPageToFit;
@property (nonatomic, readonly) UIScrollView *scrollView;

- (void)evaluateJavaScript:(NSString *)javaScriptString
         completionHandler:(PMWebViewJavascriptEvaluationCompletionHandler)completionHandler;

// When using WKWebView, always returns @"" and solely fires the javascript execution without waiting on it.
// If you need a guaranteed return value from `stringByEvaluatingJavaScriptFromString:`, please use
// `evaluateJavaScript:completionHandler:` instead.
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)javaScriptString;

@property (nonatomic, readonly) BOOL allowsInlineMediaPlayback;
@property (nonatomic, readonly) BOOL mediaPlaybackRequiresUserAction;
@property (nonatomic, readonly) BOOL mediaPlaybackAllowsAirPlay;

// UIWebView+PMAdditions methods
- (void)pm_setScrollable:(BOOL)scrollable;
- (void)disableJavaScriptDialogs;

@end

