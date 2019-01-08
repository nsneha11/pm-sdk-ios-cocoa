//
//  DiskLRUCache.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 23/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "DiskLRUCache.h"
#import "Logging.h"

// cached files that have not been access since kCacheFileMaxAge ago will be evicted
#define kCacheFileMaxAge (7 * 24 * 60 * 60) // 1 week

// once the cache hits this size AND we've added at least kCacheBytesStoredBeforeSizeCheck bytes,
// cached files will be evicted (LRU) until the total size drops below this limit
#define kCacheSoftMaxSize (100 * 1024 * 1024) // 100 MB

#define kCacheBytesStoredBeforeSizeCheck (kCacheSoftMaxSize / 10) // 10% of kCacheSoftMaxSize

//SHA
typedef uint32_t CC_LONG;       /* 32 bit unsigned integer */

#define CC_SHA1_DIGEST_LENGTH   20          /* digest length in bytes */
#define CC_SHA1_BLOCK_BYTES     64          /* block size in bytes */
#define CC_SHA1_BLOCK_LONG      (CC_SHA1_BLOCK_BYTES / sizeof(CC_LONG))

typedef struct CC_SHA1state_st
{
    CC_LONG h0,h1,h2,h3,h4;
    CC_LONG Nl,Nh;
    CC_LONG data[CC_SHA1_BLOCK_LONG];
    int num;
} CC_SHA1_CTX;
extern unsigned char *CC_SHA1(const void *data, CC_LONG len, unsigned char *md)
__OSX_AVAILABLE_STARTING(__MAC_10_4, __IPHONE_2_0);

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
@interface DiskLRUCacheFile : NSObject

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, assign) NSTimeInterval lastModTimestamp;
@property (nonatomic, assign) uint64_t fileSize;

@end

@implementation DiskLRUCacheFile
@end
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DiskLRUCache ()

#if !OS_OBJECT_USE_OBJC
@property (nonatomic, assign) dispatch_queue_t diskIOQueue;
#else
@property (nonatomic, strong) dispatch_queue_t diskIOQueue;
#endif
@property (nonatomic, copy) NSString *diskCachePath;
@property (atomic, assign) uint64_t numBytesStoredForSizeCheck;

@end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation DiskLRUCache

+ (DiskLRUCache *)sharedDiskCache
{
    static dispatch_once_t once;
    static DiskLRUCache *sharedDiskCache;
    dispatch_once(&once, ^{
        sharedDiskCache = [self new];
    });
    return sharedDiskCache;
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        _diskIOQueue = dispatch_queue_create("com.adsnative.diskCacheIOQueue", DISPATCH_QUEUE_SERIAL);
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        if (paths.count > 0) {
            _diskCachePath = [[[paths objectAtIndex:0] stringByAppendingPathComponent:@"com.adsnative.diskCache"] copy];
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if (![fileManager fileExistsAtPath:_diskCachePath]) {
                [fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:nil];
            }
        }
        
        // check cache size on startup
        [self ensureCacheSizeLimit];
    }
    
    return self;
}

- (void)dealloc
{
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_diskIOQueue);
#endif
}

#pragma mark Public

- (void)removeAllCachedFiles
{
    dispatch_sync(self.diskIOQueue, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSArray *allFiles = [self cacheFilesSortedByModDate];
        for (DiskLRUCacheFile *file in allFiles) {
            [fileManager removeItemAtPath:file.filePath error:nil];
        }
    });
}

- (BOOL)cachedDataExistsForKey:(NSString *)key
{
    __block BOOL result = NO;
    
    dispatch_sync(self.diskIOQueue, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        result = [fileManager fileExistsAtPath:[self cacheFilePathForKey:key]];
    });
    
    return result;
}

- (NSData *)retrieveDataForKey:(NSString *)key
{
    __block NSData *data = nil;
    
    dispatch_sync(self.diskIOQueue, ^{
        NSString *cachedFilePath = [self cacheFilePathForKey:key];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL isDirectory = NO;
        if ([fileManager fileExistsAtPath:cachedFilePath isDirectory:&isDirectory]) {
            data = [NSData dataWithContentsOfFile:cachedFilePath];
            
            // "touch" file to mark access since NSFileManager doesn't return a last accessed date
            [fileManager setAttributes:[NSDictionary dictionaryWithObject:[NSDate date] forKey:NSFileModificationDate] ofItemAtPath:cachedFilePath error:nil];
        }
    });
    
    return data;
}

- (void)storeData:(NSData *)data forKey:(NSString *)key
{
    dispatch_sync(self.diskIOQueue, ^{
        NSString *cacheFilePath = [self cacheFilePathForKey:key];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        if (![fileManager fileExistsAtPath:cacheFilePath]) {
            [fileManager createFileAtPath:cacheFilePath contents:data attributes:nil];
        } else {
            // overwrite existing file
            [data writeToFile:cacheFilePath atomically:YES];
        }
    });
    
    self.numBytesStoredForSizeCheck += data.length;
    
    if (self.numBytesStoredForSizeCheck >= kCacheBytesStoredBeforeSizeCheck) {
        [self ensureCacheSizeLimit];
        self.numBytesStoredForSizeCheck = 0;
    }
}

#pragma mark Private

- (void)ensureCacheSizeLimit
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        LogDebug(@"Checking cache size...");
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSMutableArray *cacheFilesSortedByModDate = [self cacheFilesSortedByModDate];
        
        dispatch_async(self.diskIOQueue, ^{
            @autoreleasepool {
                // verify age
                NSArray *expiredFiles = [self expiredCachedFilesInArray:cacheFilesSortedByModDate];
                for (DiskLRUCacheFile *file in expiredFiles) {
                    LogDebug(@"Trying to remove %@ from cache due to expiration", file.filePath);
                    
                    [fileManager removeItemAtPath:file.filePath error:nil];
                    [cacheFilesSortedByModDate removeObject:file];
                }
                
                // verify size
                while ([self sizeOfCacheFilesInArray:cacheFilesSortedByModDate] >= kCacheSoftMaxSize && cacheFilesSortedByModDate.count > 0) {
                    NSString *oldestFilePath = ((DiskLRUCacheFile *)[cacheFilesSortedByModDate objectAtIndex:0]).filePath;
                    
                    LogDebug(@"Trying to remove %@ from cache due to size", oldestFilePath);
                    
                    [fileManager removeItemAtPath:oldestFilePath error:nil];
                    [cacheFilesSortedByModDate removeObjectAtIndex:0];
                }
            }
        });
    });
}

- (NSArray *)expiredCachedFilesInArray:(NSArray *)cachedFiles
{
    NSMutableArray *result = [NSMutableArray array];
    
    NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
    
    for (DiskLRUCacheFile *file in cachedFiles) {
        if (now - file.lastModTimestamp >= kCacheFileMaxAge) {
            [result addObject:file];
        }
    }
    
    return result;
}

- (NSMutableArray *)cacheFilesSortedByModDate
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray *cachedFiles = [fileManager contentsOfDirectoryAtPath:self.diskCachePath error:nil];
    NSArray *sortedFiles = [cachedFiles sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSString *fileName1 = [self.diskCachePath stringByAppendingPathComponent:(NSString *)obj1];
        NSString *fileName2 = [self.diskCachePath stringByAppendingPathComponent:(NSString *)obj2];
        
        NSDictionary *fileAttrs1 = [fileManager attributesOfItemAtPath:fileName1 error:nil];
        NSDictionary *fileAttrs2 = [fileManager attributesOfItemAtPath:fileName2 error:nil];
        
        NSDate *lastModDate1 = [fileAttrs1 fileModificationDate];
        NSDate *lastModDate2 = [fileAttrs2 fileModificationDate];
        
        return [lastModDate1 compare:lastModDate2];
    }];
    
    NSMutableArray *result = [NSMutableArray array];
    
    for (NSString *fileName in sortedFiles) {
        if ([fileName hasPrefix:@"."]) {
            continue;
        }
        
        DiskLRUCacheFile *cacheFile = [[DiskLRUCacheFile alloc] init];
        cacheFile.filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
        
        NSDictionary *fileAttrs = [fileManager attributesOfItemAtPath:cacheFile.filePath error:nil];
        cacheFile.fileSize = [fileAttrs fileSize];
        cacheFile.lastModTimestamp = [[fileAttrs fileModificationDate] timeIntervalSinceReferenceDate];
        
        [result addObject:cacheFile];
    }
    
    return result;
}

- (uint64_t)sizeOfCacheFilesInArray:(NSArray *)files
{
    uint64_t currentSize = 0;
    
    for (DiskLRUCacheFile *file in files) {
        currentSize += file.fileSize;
    }
    
    LogDebug(@"Current cache size %qu bytes", currentSize);
    
    return currentSize;
}

- (NSString *)cacheFilePathForKey:(NSString *)key
{
    NSString *hashedKey = [self SHA1DigestWithKey:key];
    NSString *cachedFilePath = [self.diskCachePath stringByAppendingPathComponent:hashedKey];
    return cachedFilePath;
}

- (NSString *)SHA1DigestWithKey:(NSString *)string
{
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    NSData *data = [string dataUsingEncoding:NSASCIIStringEncoding];
    CC_SHA1([data bytes], (CC_LONG)[data length], digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    return output;
}
@end
