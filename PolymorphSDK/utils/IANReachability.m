//
//  IANReachability.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 01/10/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "IANReachability.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>

#import <CoreFoundation/CoreFoundation.h>

static void PrintReachabilityFlags(SCNetworkReachabilityFlags    flags, const char* comment)
{
#if kShouldPrintReachabilityFlags
    
    NSLog(@"IANReachability Flag Status: %c%c %c%c%c%c%c%c%c %s\n",
          (flags & kSCNetworkReachabilityFlagsIsWWAN)				  ? 'W' : '-',
          (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
          
          (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
          (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
          (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
          (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-',
          comment
          );
#endif
}

@implementation IANReachability

static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
#pragma unused (target, flags)
    NSCAssert(info != NULL, @"info was NULL in IANReachabilityCallback");
    NSCAssert([(NSObject*) CFBridgingRelease(info) isKindOfClass: [IANReachability class]], @"info was wrong class in IANReachabilityCallback");
    
    IANReachability* noteObject = (__bridge IANReachability*) info;
    // Post a notification to notify the client that the network Reachability changed.
    [[NSNotificationCenter defaultCenter] postNotificationName: kReachabilityChangedNotification object: noteObject];
    
}

- (BOOL) startNotifier
{
    BOOL retVal = NO;
    SCNetworkReachabilityContext	context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    if(SCNetworkReachabilitySetCallback(reachabilityRef, ReachabilityCallback, &context))
    {
        if(SCNetworkReachabilityScheduleWithRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode))
        {
            retVal = YES;
        }
    }
    return retVal;
}

- (void) stopNotifier
{
    if(reachabilityRef!= NULL)
    {
        SCNetworkReachabilityUnscheduleFromRunLoop(reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    }
}

- (void) dealloc
{
    [self stopNotifier];
    if(reachabilityRef!= NULL)
    {
        CFRelease(reachabilityRef);
    }
}

+ (IANReachability*) reachabilityWithHostName: (NSString*) hostName;
{
    IANReachability* retVal = NULL;
    SCNetworkReachabilityRef Reachability = SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);
    if(Reachability!= NULL)
    {
        retVal= [[self alloc] init];
        if(retVal!= NULL)
        {
            retVal->reachabilityRef = Reachability;
            retVal->localWiFiRef = NO;
        }
    }
    return retVal;
}

+ (IANReachability*) reachabilityWithAddress: (const struct sockaddr_in*) hostAddress;
{
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)hostAddress);
    IANReachability* retVal = NULL;
    
    if(reachability!= NULL)
    {
        retVal= [[self alloc] init];
        if(retVal!= NULL)
        {
            retVal->reachabilityRef = reachability;
            retVal->localWiFiRef = NO;
        }
    }
    return retVal;
}

+ (IANReachability*) reachabilityForInternetConnection;
{
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    return [self reachabilityWithAddress: &zeroAddress];
}

+ (IANReachability*) reachabilityForLocalWiFi;
{
    struct sockaddr_in localWifiAddress;
    bzero(&localWifiAddress, sizeof(localWifiAddress));
    localWifiAddress.sin_len = sizeof(localWifiAddress);
    localWifiAddress.sin_family = AF_INET;
    // IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0
    localWifiAddress.sin_addr.s_addr = htonl(IN_LINKLOCALNETNUM);
    IANReachability* retVal = [self reachabilityWithAddress: &localWifiAddress];
    if(retVal!= NULL)
    {
        retVal->localWiFiRef = YES;
    }
    return retVal;
}

#pragma mark Network Flag Handling

- (NetworkStatus) localWiFiStatusForFlags: (SCNetworkReachabilityFlags) flags
{
    PrintReachabilityFlags(flags, "localWiFiStatusForFlags");
    
    BOOL retVal = NotReachable;
    if((flags & kSCNetworkReachabilityFlagsReachable) && (flags & kSCNetworkReachabilityFlagsIsDirect))
    {
        retVal = ReachableViaWiFi;
    }
    return retVal;
}

- (NetworkStatus) networkStatusForFlags: (SCNetworkReachabilityFlags) flags
{
    PrintReachabilityFlags(flags, "networkStatusForFlags");
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
    {
        // if target host is not reachable
        return NotReachable;
    }
    
    BOOL retVal = NotReachable;
    
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
    {
        // if target host is reachable and no connection is required
        //  then we'll assume (for now) that your on Wi-Fi
        retVal = ReachableViaWiFi;
    }
    
    
    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
         (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
    {
        // ... and the connection is on-demand (or on-traffic) if the
        //     calling application is using the CFSocketStream or higher APIs
        
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
        {
            // ... and no [user] intervention is needed
            retVal = ReachableViaWiFi;
        }
    }
    
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
    {
        // ... but WWAN connections are OK if the calling application
        //     is using the CFNetwork (CFSocketStream?) APIs.
        retVal = ReachableViaWWAN;
    }
    return retVal;
}

- (BOOL) connectionRequired;
{
    NSAssert(reachabilityRef != NULL, @"connectionRequired called with NULL ReachabilityRef");
    SCNetworkReachabilityFlags flags;
    if (SCNetworkReachabilityGetFlags(reachabilityRef, &flags))
    {
        return (flags & kSCNetworkReachabilityFlagsConnectionRequired);
    }
    return NO;
}

- (NetworkStatus) currentReachabilityStatus
{
    NSAssert(reachabilityRef != NULL, @"currentNetworkStatus called with NULL ReachabilityRef");
    NetworkStatus retVal = NotReachable;
    SCNetworkReachabilityFlags flags;
    if (SCNetworkReachabilityGetFlags(reachabilityRef, &flags))
    {
        if(localWiFiRef)
        {
            retVal = [self localWiFiStatusForFlags: flags];
        }
        else
        {
            retVal = [self networkStatusForFlags: flags];
        }
    }
    return retVal;
}
@end
