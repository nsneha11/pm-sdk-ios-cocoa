//
//  NSJSONSerialization+Additions.m
//  AdsNative-iOS-SDK
//
//  Created by Arvind Bharadwaj on 28/09/15.
//  Copyright (c) 2015 AdsNative. All rights reserved.
//

#import "NSJSONSerialization+Additions.h"

@interface NSMutableDictionary (RemoveNullObjects)

- (void)pm_removeNullsRecursively;

@end

@interface NSMutableArray (RemoveNullObjects)

- (void)pm_removeNullsRecursively;

@end

@implementation NSJSONSerialization (Additions)

+ (id)pm_JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt clearNullObjects:(BOOL)clearNulls error:(NSError **)error
{
    if (clearNulls) {
        opt |= NSJSONReadingMutableContainers;
    }
    
    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:opt error:error];
    
    if (error || !clearNulls) {
        return JSONObject;
    }
    
    [JSONObject pm_removeNullsRecursively];
    
    return JSONObject;
}

@end

@implementation NSMutableDictionary (RemovingNulls)

-(void)pm_removeNullsRecursively
{
    // First, filter out directly stored nulls
    NSMutableArray *nullKeys = [NSMutableArray array];
    NSMutableArray *arrayKeys = [NSMutableArray array];
    NSMutableArray *dictionaryKeys = [NSMutableArray array];
    
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if ([obj isEqual:[NSNull null]]) {
            [nullKeys addObject:key];
        } else if ([obj isKindOfClass:[NSDictionary  class]]) {
            [dictionaryKeys addObject:key];
        } else if ([obj isKindOfClass:[NSArray class]]) {
            [arrayKeys addObject:key];
        }
    }];
    
    // Remove all the nulls
    [self removeObjectsForKeys:nullKeys];
    
    // Cascade down the dictionaries
    for (id dictionaryKey in dictionaryKeys) {
        NSMutableDictionary *dictionary = [self objectForKey:dictionaryKey];
        [dictionary pm_removeNullsRecursively];
    }
    
    // Recursively remove nulls from arrays
    for (id arrayKey in arrayKeys) {
        NSMutableArray *array = [self objectForKey:arrayKey];
        [array pm_removeNullsRecursively];
    }
}

@end

@implementation NSMutableArray (RemovingNulls)

-(void)pm_removeNullsRecursively
{
    [self removeObjectIdenticalTo:[NSNull null]];
    
    for (id object in self) {
        if ([object respondsToSelector:@selector(pm_removeNullsRecursively)]) {
            [(NSMutableDictionary *)object pm_removeNullsRecursively];
        }
    }
}

@end

