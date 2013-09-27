//
//  AMImageCache.m
//
//  Take a look to my repos at http://github.com/vilanovi
//
// Copyright (c) 2013 Joan Martin, vilanovi@gmail.com.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do
// so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE

#import "AMImageCache.h"

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabasePool.h"
#import "FMDatabaseQueue.h"
#import "FMResultSet.h"

#import "AMImageRequest.h"
#import "AMImageResult.h"

NSString * const AMImageCacheDataBaseException = @"AMImageCacheDataBaseException";

#define UpdateException [NSException exceptionWithName:AMImageCacheDataBaseException reason:nil userInfo:nil]

@implementation AMImageCache
{
    FMDatabaseQueue *_dbQueue;
    NSCache *_cacheByKey;
    NSCache *_cacheByRequest;
}

+ (AMImageCache*)cacheAtURL:(NSURL*)url
{
    if (!url)
        return nil;
    
    static NSMutableDictionary *caches = nil;
    
    if (!caches)
        caches = [NSMutableDictionary dictionary];
    
    AMImageCache *cache = [caches objectForKey:url];
    
    if (!cache)
    {
        cache = [[AMImageCache alloc] initWithURL:url];
        [caches setObject:cache forKey:url];
    }
    
    return cache;
}

- (id)initWithURL:(NSURL *)url
{
    if (!url)
        return nil;
    
    self = [super init];
    if (self)
    {
        _url = url;
        
        _cacheByKey = [[NSCache alloc] init];
        _cacheByRequest = [[NSCache alloc] init];
        
        if (url)
        {
            if ([[NSFileManager defaultManager] fileExistsAtPath:[url path]])
            {
                _dbQueue = [FMDatabaseQueue databaseQueueWithPath:[url path]];
            }
            else
            {
                _dbQueue = [FMDatabaseQueue databaseQueueWithPath:[url path]];
                [self _createTables];
            }
        }
    }
    return self;
}

#pragma mark Public Methods

- (UIImage*)executeRequestInDynamicCache:(AMImageRequest*)request
{
    UIImage *image = [_cacheByRequest objectForKey:request];
    if (image)
        return image;
    
    return nil;
}

- (UIImage*)executeRequest:(AMImageRequest*)request
{
    UIImage *image = [self executeRequestInDynamicCache:request];
    if (image)
        return image;
    
    NSInteger key = NSNotFound;
    
    NSArray *results = [self _resultsForImageRequest:request];
    
    if (request.sizeOption == AMImageRequestSizeOptionAnySize)
    {
        AMImageResult *result = [results lastObject];
        if (result)
            key = result.key;
    }
    else
    {
        // Searching the result with the minimal offset
        CGFloat minDist = CGFLOAT_MAX;
        
        for (AMImageResult *result in results)
        {
            CGSize offset = CGSizeMake((result.size.width - request.size.width), (result.size.height - request.size.height));
            
            // Using euclidian distance to mesure the smaller offset
            CGFloat distance = sqrtf(offset.width*offset.width + offset.height*offset.height);
            
            if (distance < minDist)
            {
                minDist = distance;
                key = result.key;
                
                if (minDist == 0.0f)
                    break;
            }
        }
    }

    if (key != NSNotFound)
    {
        UIImage *image = [self _imageForKey:key];
        [self _updateAccessForImageWithKey:key];
        
        [_cacheByRequest setObject:image forKey:request];
        
        return image;
    }
    
    return nil;
}

- (void)executeRequest:(AMImageRequest*)request completion:(void (^)(UIImage *image))completionBlock
{
    if (!completionBlock)
        return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = [self executeRequest:request];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(image);
        });
    });
}

- (void)storeImage:(UIImage*)image forIdentifier:(NSString*)identifier
{
    [self storeImage:image forIdentifier:identifier isOriginal:NO];
}

- (void)storeImage:(UIImage*)image forIdentifier:(NSString*)identifier isOriginal:(BOOL)isOriginal
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [_dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            @try
            {
            if(![db executeUpdate:@"INSERT INTO Images (identifier, creationDate, original, width, height, scale) values (?, ?, ?, ?, ?, ?)",
             identifier,
             @([[NSDate date] timeIntervalSince1970]),
             @(isOriginal),
             @(image.size.width),
             @(image.size.height),
             @(image.scale)
             ])
                @throw UpdateException;
            
            sqlite_int64 key = db.lastInsertRowId;
            
            if (![db executeUpdate:@"INSERT INTO Data (key, data , scale) values (?, ?, ?)",
             @(key),
             UIImagePNGRepresentation(image),
             @(image.scale)
             ])
                @throw UpdateException;
            }
            @catch (NSException *exception)
            {
                if ([exception.name isEqualToString:AMImageCacheDataBaseException])
                    *rollback = YES;
                else
                    @throw exception;
            }
        }];
    });
}

- (void)storeImage:(UIImage*)image forRequest:(AMImageRequest*)request
{
    [_cacheByRequest setObject:image forKey:request];
    [self storeImage:image forIdentifier:request.identifier isOriginal:request.original];
}

- (void)cleanCacheUsingAccessDate:(NSTimeInterval)accessDate completion:(void (^)())completionBlock
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [_dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            @try
            {
                NSString *query1 = [NSString stringWithFormat:@"DELETE FROM Data WHERE key IN (SELECT Images.key FROM Images WHERE Images.accessDate < %f)", accessDate];
                NSString *query2 = [NSString stringWithFormat:@"DELETE FROM Images WHERE accessDate < %f", accessDate];
                
                if(![db executeUpdate:query1])
                    @throw UpdateException;
                
                if (![db executeUpdate:query2])
                    @throw UpdateException;
            }
            @catch (NSException *exception)
            {
                if ([exception.name isEqualToString:AMImageCacheDataBaseException])
                    *rollback = YES;
                else
                    @throw exception;
            }
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock)
                completionBlock();
        });
    });
}

#pragma mark Private Methods

- (void)_createTables
{
    [_dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        @try
        {
            [db executeUpdate:@"DROP TABLE Images"];
            [db executeUpdate:@"DROP TABLE Data"];
            [db executeUpdate:@"CREATE TABLE Images (key INTEGER PRIMARY KEY AUTOINCREMENT, identifier TEXT, creationDate DOUBLE, accessDate DOUBLE, original BOOLEAN, width INTEGER, height INTEGER, scale FLOAT)"];
            [db executeUpdate:@"CREATE TABLE Data (key INTEGER PRIMARY KEY, data BLOB, scale FLOAT)"];
        }
        @catch (NSException *exception)
        {
            if ([exception.name isEqualToString:AMImageCacheDataBaseException])
                *rollback = YES;
            else
                @throw exception;
        }
    }];
}

- (void)_updateAccessForImageWithKey:(NSInteger)key
{
    if (!key)
        return;
    
    [_dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        @try
        {
            if (![db executeUpdate:@"UPDATE Images SET accessDate = ? WHERE key = ?", [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]], @(key)])
                @throw UpdateException;
        }
        @catch (NSException *exception)
        {
            if ([exception.name isEqualToString:AMImageCacheDataBaseException])
                *rollback = YES;
            else
                @throw exception;
        }
    }];
}

- (UIImage*)_imageForKey:(NSInteger)key
{
    __block UIImage *image = [_cacheByKey objectForKey:@(key)];
    
    if (image)
        return image;
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *resultSet = [db executeQueryWithFormat:@"SELECT data, scale FROM Data WHERE Data.key = %d", key];
        
        if ([resultSet next])
        {
            NSData *data = [resultSet dataForColumnIndex:0];
            CGFloat scale = [resultSet doubleForColumnIndex:1];
            
            image = [[UIImage alloc] initWithData:data scale:scale];
            
            [resultSet close];
        }
    }];
    
    if (image)
        [_cacheByKey setObject:image forKey:@(key)];
    
    return image;
}

- (NSArray*)_resultsForImageRequest:(AMImageRequest*)request
{
    NSMutableArray *array = [NSMutableArray array];
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        
        NSString *sqlQuery = [self _sqlQueryFromImageRequest:request];
        
        FMResultSet *resultSet = [db executeQuery:sqlQuery];
        
        if ([resultSet next])
        {
            AMImageResult *result = [AMImageResult new];

            result.key = [resultSet intForColumnIndex:0];
            result.identifier = [resultSet objectForColumnIndex:1];
            result.creationDate = [resultSet doubleForColumnIndex:2];
            result.accessDate = [resultSet doubleForColumnIndex:3];
            result.original = [[resultSet objectForColumnIndex:4] boolValue];
            result.size = CGSizeMake([resultSet doubleForColumnIndex:5], [resultSet doubleForColumnIndex:6]);
            result.scale = [resultSet doubleForColumnIndex:7];
            
            [array addObject:result];
            
            [resultSet close];
        }
    }];
    
    return array;
}

- (NSString*)_sqlQueryFromImageRequest:(AMImageRequest*)imageRequest
{
    NSMutableString *query = [NSMutableString string];
    
    [query appendString:@"SELECT key, identifier, creationDate, accessDate, original, width, height, scale FROM Images"];    
    
    NSMutableString *conditions = [NSMutableString string];
    
    if (imageRequest.identifier)
        [conditions appendFormat:@" identifier = '%@'", imageRequest.identifier];
    
    AMImageRequestSizeOptions sizeOption = imageRequest.sizeOption;
    
    if (imageRequest.original)
    {
        [conditions appendFormat:@" AND original = 1"];
    }
    else
    {
        [conditions appendFormat:@" AND original = 0"];
        
        if (sizeOption == AMImageRequestSizeOptionAnySize)
        {
            // Nothing to do
        }
        else if (sizeOption == AMImageRequestSizeOptionExactSize)
        {
            CGSize size = imageRequest.size;
            [conditions appendFormat:@" AND width = %d AND height = %d", (int)size.width, (int)size.height];
        }
        else
        {
            CGSize size = imageRequest.size;
            CGFloat ratio = imageRequest.similarRatio;
            
            CGSize offsetSize;
            
            if (sizeOption == AMImageRequestSizeOptionInOffsetSize)
                offsetSize = imageRequest.offsetSize;
            else if (sizeOption == AMImageRequestSizeOptionSimilarSize)
                offsetSize = CGSizeMake(size.width*(1.0f - ratio), size.height*(1.0f - ratio));
            
            AMImageRequestRestrictionOptions restrictOption = imageRequest.restrictOptions;
            
            if (restrictOption == AMImageRequestOptionRestrictDisabled)
            {
                [conditions appendFormat:@" AND (width >= %d AND width <= %d)",(int)(size.width - offsetSize.width), (int)(size.width + offsetSize.width)];
                [conditions appendFormat:@" AND (height >= %d AND height <= %d)", (int)(size.height - offsetSize.height), (int)(size.height + offsetSize.height)];
            }
            else if (restrictOption == AMImageRequestOptionRestrictSmaller)
            {
                [conditions appendFormat:@" AND (width >= %d AND width <= %d)",(int)(size.width), (int)(size.width + offsetSize.width)];
                [conditions appendFormat:@" AND (height >= %d AND height <= %d)", (int)(size.height), (int)(size.height + offsetSize.height)];
            }
            else if (restrictOption == AMImageRequestOptionRestrictBigger)
            {
                [conditions appendFormat:@" AND (width >= %d AND width <= %d)",(int)(size.width - offsetSize.width), (int)(size.width)];
                [conditions appendFormat:@" AND (height >= %d AND height <= %d)", (int)(size.height - offsetSize.height), (int)(size.height)];
            }
        }
    }

    if (conditions.length > 0)
        [query appendFormat:@" WHERE%@", conditions];
    
    return query;
}

@end

