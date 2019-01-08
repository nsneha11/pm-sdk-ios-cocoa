//
//  URLActionInfo.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 06/10/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "URLActionInfo.h"

@interface URLActionInfo ()

@property (nonatomic, readwrite) URLActionType actionType;
@property (nonatomic, readwrite, copy) NSURL *originalURL;
@property (nonatomic, readwrite, copy) NSString *iTunesItemIdentifier;
@property (nonatomic, readwrite, copy) NSURL *iTunesStoreFallbackURL;
@property (nonatomic, readwrite, copy) NSURL *safariDestinationURL;
@property (nonatomic, readwrite, copy) NSString *HTTPResponseString;
@property (nonatomic, readwrite, copy) NSURL *webViewBaseURL;

@end


@implementation URLActionInfo

+ (instancetype)infoWithURL:(NSURL *)URL iTunesItemIdentifier:(NSString *)identifier iTunesStoreFallbackURL:(NSURL *)fallbackURL
{
    URLActionInfo *info = [[[self class] alloc] init];
    info.actionType = URLActionTypeStoreKit;
    info.originalURL = URL;
    info.iTunesItemIdentifier = identifier;
    info.iTunesStoreFallbackURL = fallbackURL;
    return info;
}

+ (instancetype)infoWithURL:(NSURL *)URL safariDestinationURL:(NSURL *)safariDestinationURL
{
    URLActionInfo *info = [[[self class] alloc] init];
    info.actionType = URLActionTypeOpenInSafari;
    info.originalURL = URL;
    info.safariDestinationURL = safariDestinationURL;
    return info;
}

+ (instancetype)infoWithURL:(NSURL *)URL HTTPResponseString:(NSString *)responseString webViewBaseURL:(NSURL *)baseURL
{
    URLActionInfo *info = [[[self class] alloc] init];
    info.actionType = URLActionTypeOpenInWebView;
    info.originalURL = URL;
    info.HTTPResponseString = responseString;
    info.webViewBaseURL = baseURL;
    return info;
}
@end
