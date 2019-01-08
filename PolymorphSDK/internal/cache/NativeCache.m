//
//  NativeCache.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "NativeCache.h"
#import "DiskLRUCache.h"
#import "Logging.h"

typedef enum {
    NativeCacheMethodDisk = 0,
    NativeCacheMethodDiskAndMemory = 1 << 0
} NativeCacheMethod;

@interface NativeCache () <NSCacheDelegate>

@property (nonatomic, strong) NSCache *memoryCache;
@property (nonatomic, strong) DiskLRUCache *diskCache;
@property (nonatomic, assign) NativeCacheMethod cacheMethod;

- (BOOL)cachedDataExistsForKey:(NSString *)key withCacheMethod:(NativeCacheMethod)cacheMethod;
- (NSData *)retrieveDataForKey:(NSString *)key withCacheMethod:(NativeCacheMethod)cacheMethod;
- (void)storeData:(id)data forKey:(NSString *)key withCacheMethod:(NativeCacheMethod)cacheMethod;
- (void)removeAllDataFromMemory;
- (void)removeAllDataFromDisk;

@end


@implementation NativeCache

+ (instancetype)sharedCache;
{
    static dispatch_once_t once;
    static NativeCache *sharedCache;
    dispatch_once(&once, ^{
        sharedCache = [[self alloc] init];
    });
    return sharedCache;
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        _memoryCache = [[NSCache alloc] init];
        _memoryCache.delegate = self;
        
        _diskCache = [[DiskLRUCache alloc] init];
        
        _cacheMethod = NativeCacheMethodDiskAndMemory;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:[UIApplication sharedApplication]];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

#pragma mark - Public Cache Interactions

- (void)setInMemoryCacheEnabled:(BOOL)enabled
{
    if (enabled) {
        self.cacheMethod = NativeCacheMethodDiskAndMemory;
    } else {
        self.cacheMethod = NativeCacheMethodDisk;
        [self.memoryCache removeAllObjects];
    }
}

- (BOOL)cachedDataExistsForKey:(NSString *)key
{
    return [self cachedDataExistsForKey:key withCacheMethod:self.cacheMethod];
}

- (NSData *)retrieveDataForKey:(NSString *)key
{
    return [self retrieveDataForKey:key withCacheMethod:self.cacheMethod];
}

- (void)storeData:(NSData *)data forKey:(NSString *)key
{
    [self storeData:data forKey:key withCacheMethod:self.cacheMethod];
}

- (void)removeAllDataFromCache
{
    [self removeAllDataFromMemory];
    [self removeAllDataFromDisk];
}

#pragma mark - Private Cache Implementation

- (BOOL)cachedDataExistsForKey:(NSString *)key withCacheMethod:(NativeCacheMethod)cacheMethod
{
    BOOL dataExists = NO;
    if (cacheMethod & NativeCacheMethodDiskAndMemory) {
        dataExists = [self.memoryCache objectForKey:key] != nil;
    }
    
    if (!dataExists) {
        dataExists = [self.diskCache cachedDataExistsForKey:key];
    }
    
    return dataExists;
}

- (id)retrieveDataForKey:(NSString *)key withCacheMethod:(NativeCacheMethod)cacheMethod
{
    id data = nil;
    
    if (cacheMethod & NativeCacheMethodDiskAndMemory) {
        data = [self.memoryCache objectForKey:key];
    }
    
    if (data) {
        LogDebug(@"RETRIEVE FROM MEMORY: %@", key);
    }
    
    
    if (data == nil) {
        data = [self.diskCache retrieveDataForKey:key];
        
        if (data && cacheMethod & NativeCacheMethodDiskAndMemory) {
            LogDebug(@"RETRIEVE FROM DISK: %@", key);
            
            [self.memoryCache setObject:data forKey:key];
            LogDebug(@"STORED IN MEMORY: %@", key);
        }
    }
    
    if (data == nil) {
        LogDebug(@"RETRIEVE FAILED: %@", key);
    }
    
    return data;
}

- (void)storeData:(id)data forKey:(NSString *)key withCacheMethod:(NativeCacheMethod)cacheMethod
{
    if (data == nil) {
        return;
    }
    
    if (cacheMethod & NativeCacheMethodDiskAndMemory) {
        [self.memoryCache setObject:data forKey:key];
        LogDebug(@"STORED IN MEMORY: %@", key);
    }
    
    [self.diskCache storeData:data forKey:key];
    LogDebug(@"STORED ON DISK: %@", key);
}

- (void)removeAllDataFromMemory
{
    [self.memoryCache removeAllObjects];
}

- (void)removeAllDataFromDisk
{
    [self.diskCache removeAllCachedFiles];
}

#pragma mark - Notifications

- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
    [self.memoryCache removeAllObjects];
}

#pragma mark - NSCacheDelegate

- (void)cache:(NSCache *)cache willEvictObject:(id)obj
{
    LogDebug(@"Evicting Object");
}

@end
