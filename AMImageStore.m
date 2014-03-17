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

#import "AMImageStore.h"

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabasePool.h"
#import "FMDatabaseQueue.h"
#import "FMResultSet.h"

#import "AMImageRequest.h"
#import "AMImageResult.h"

NSString * const AMImageCacheDataBaseException = @"AMImageCacheDataBaseException";

#define UpdateException [NSException exceptionWithName:AMImageCacheDataBaseException reason:nil userInfo:nil]

/*
 * SQLite Table Overview:
 *
 * Table IMAGES:
 * +-----------------------+-------+--------------+------------+---------+---------+---------+
 * |          id           |  key  | creationDate | accessDate | options |  width  | height  |
 * +-----------------------+-------+--------------+------------+---------+---------+---------+
 * | INTEGER (PRIMARY KEY) | TEXT  | INTEGER      | INTEGER    | TEXT    | INTEGER | INTEGER |
 * +-----------------------+-------+--------------+------------+---------+---------+---------+
 *
 * Table DATA:
 * +--------------------------------------------------------+------+
 * |                           id                           | data |
 * +--------------------------------------------------------+------+
 * | INTEGER (PRIMARY KEY FOREIGN KEY REFERENCES IMAGES.id) | BLOB |
 * +--------------------------------------------------------+------+
 */

// Table name
static NSString * const TABLE_IMAGES = @"Images";
static NSString * const TABLE_DATA = @"Data";

// Image Table Columns names
static NSString * const IMAGES_COLUMN_ID = @"id";
static NSString * const IMAGES_COLUMN_KEY = @"key";
static NSString * const IMAGES_COLUMN_CREATION_DATE = @"creationDate";
static NSString * const IMAGES_COLUMN_ACCESS_DATE = @"accessDate";
static NSString * const IMAGES_COLUMN_OPTIONS = @"options";
static NSString * const IMAGES_COLUMN_WIDTH = @"width";
static NSString * const IMAGES_COLUMN_HEIGHT = @"height";

// Data Table Columns names
static NSString * const DATA_COLUMN_ID = @"id";
static NSString * const DATA_COLUMN_DATA = @"data";

@implementation AMImageStore
{
    FMDatabaseQueue *_dbQueue;
}

+ (AMImageStore*)cacheAtURL:(NSURL*)url
{
    if (!url)
        return nil;
    
    static NSMutableDictionary *caches = nil;
    
    if (!caches)
        caches = [NSMutableDictionary dictionary];
    
    AMImageStore *cache = [caches objectForKey:url];
    
    if (!cache)
    {
        cache = [[AMImageStore alloc] initWithURL:url];
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

- (NSArray*)executeRequest:(AMImageRequest*)request
{
    NSArray *results = [self _select:request];
    
    if (!results)
        return nil;
    
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:results.count];
    
    for (AMImageResult *result in results)
    {
        UIImage *image = [[UIImage alloc] initWithData:result.data scale:request.scale];
        if (image)
            [images addObject:image];
    }
    
    return images;
}

- (void)executeRequest:(AMImageRequest*)request completion:(void (^)(NSArray*))completionBlock
{
    if (!completionBlock)
        return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *images = [self executeRequest:request];
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(images);
        });
    });
}

- (BOOL)storeImage:(UIImage*)image forIdentifier:(NSString*)identifier options:(NSString*)options
{
    return [self _insert:image identifier:identifier options:options];
}

- (void)storeImage:(UIImage *)image forIdentifier:(NSString *)identifier options:(NSString *)options completionBlock:(void(^)(BOOL succeed))completionBlock
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL succeed = [self _insert:image identifier:identifier options:options];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock)
                completionBlock(succeed);
        });
    });
}


- (BOOL)executeDelete:(AMImageRequest*)request
{
    return [self _delete:request];
}

- (void)executeDelete:(AMImageRequest*)request completion:(void (^)(BOOL succeed))completionBlock
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL succeed = [self executeDelete:request];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock)
                completionBlock(succeed);
        });
    });
}

#pragma mark Private Methods

- (void)_createTables
{
    [_dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        @try
        {
            NSString *dropImagesTable = [NSString stringWithFormat:@"DROP TABLE %@", TABLE_IMAGES];
            NSString *dropDataTable = [NSString stringWithFormat:@"DROP TABLE %@", TABLE_DATA];
            
            NSMutableString *createImagesTable = [NSMutableString string];
            NSMutableString *createDataTable = [NSMutableString string];
            
            [createImagesTable appendFormat:@"CREATE TABLE %@ (", TABLE_IMAGES];
            [createImagesTable appendFormat:@"%@ INTEGER PRIMARY KEY AUTOINCREMENT, ", IMAGES_COLUMN_ID];
            [createImagesTable appendFormat:@"%@ TEXT, ", IMAGES_COLUMN_KEY];
            [createImagesTable appendFormat:@"%@ INTEGER, ", IMAGES_COLUMN_CREATION_DATE];
            [createImagesTable appendFormat:@"%@ INTEGER, ", IMAGES_COLUMN_ACCESS_DATE];
            [createImagesTable appendFormat:@"%@ TEXT, ", IMAGES_COLUMN_OPTIONS];
            [createImagesTable appendFormat:@"%@ INTEGER, ", IMAGES_COLUMN_WIDTH];
            [createImagesTable appendFormat:@"%@ INTEGER)", IMAGES_COLUMN_HEIGHT];

            [createDataTable appendFormat:@"CREATE TABLE %@ (", TABLE_DATA];
            [createDataTable appendFormat:@"%@ INTEGER PRIMARY KEY, ", DATA_COLUMN_ID];
            [createDataTable appendFormat:@"%@ BLOB, ", DATA_COLUMN_DATA];
            [createDataTable appendFormat:@"FOREIGN KEY(%@) REFERENCES %@(%@))", DATA_COLUMN_ID, TABLE_IMAGES, IMAGES_COLUMN_ID];
            
            [db executeUpdate:dropDataTable];
            [db executeUpdate:dropImagesTable];
            [db executeUpdate:createImagesTable];
            [db executeUpdate:createDataTable];
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

- (BOOL)_insert:(UIImage*)image identifier:(NSString*)identifier options:(NSString*)options
{
    // If no image or no identifier, do nothing.
    if (image == nil || identifier == nil)
        return NO;
    
    // Flag if the insertion process is successful
    __block BOOL successful = false;
    
    // Getting the data of the image
    NSData *imageData = UIImagePNGRepresentation(image);
    
    // If inavlid image data, return false
    if (!imageData)
        return NO;
    
    // Perform the insertion
    [_dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        @try
        {
            NSMutableString *imagesQuery = [NSMutableString string];
            
            [imagesQuery appendFormat:@"INSERT INTO %@ (", TABLE_IMAGES];
            [imagesQuery appendFormat:@"%@, ", IMAGES_COLUMN_KEY];
            [imagesQuery appendFormat:@"%@, ", IMAGES_COLUMN_CREATION_DATE];
            [imagesQuery appendFormat:@"%@, ", IMAGES_COLUMN_ACCESS_DATE];
            [imagesQuery appendFormat:@"%@, ", IMAGES_COLUMN_OPTIONS];
            [imagesQuery appendFormat:@"%@, ", IMAGES_COLUMN_WIDTH];
            [imagesQuery appendFormat:@"%@) ", IMAGES_COLUMN_HEIGHT];
            [imagesQuery appendFormat:@"VALUES (?, ?, ?, ?, ?, ?)"];

            NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
            
            if(![db executeUpdate:imagesQuery,
                 identifier,
                 @((int)timeStamp),
                 @((int)timeStamp),
                 options,
                 @((int)(image.size.width*image.scale)),
                 @((int)(image.size.height*image.scale))
                 ])
                @throw UpdateException;
            
            sqlite_int64 dbID = db.lastInsertRowId;
            
            NSMutableString *dataQuery = [NSMutableString string];
            
            [dataQuery appendFormat:@"INSERT INTO %@ (", TABLE_DATA];
            [dataQuery appendFormat:@"%@, ", DATA_COLUMN_ID];
            [dataQuery appendFormat:@"%@) ", DATA_COLUMN_DATA];
            [dataQuery appendFormat:@"VALUES (?, ?)"];
            
            if (![db executeUpdate:dataQuery,
                  @(dbID),
                  imageData
                  ])
                @throw UpdateException;
            
            successful = YES;
        }
        @catch (NSException *exception)
        {
            if ([exception.name isEqualToString:AMImageCacheDataBaseException])
                *rollback = YES;
            else
                @throw exception;
        }
    }];
    
    return successful;
}

- (NSArray*)_select:(AMImageRequest*)request
{
    if (request == nil)
        return nil;
    
    NSString *whereStatement = [self _generateWhereStatementFromRequest:request];
    if (!whereStatement)
        return nil;
    
    NSMutableArray *results = [NSMutableArray array];
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        
        NSMutableString *query = [NSMutableString string];
        
        [query appendFormat:@"SELECT "];
        [query appendFormat:@"%@.%@, ", TABLE_IMAGES, IMAGES_COLUMN_ID];
        [query appendFormat:@"%@.%@, ", TABLE_IMAGES, IMAGES_COLUMN_KEY];
        [query appendFormat:@"%@.%@, ", TABLE_IMAGES, IMAGES_COLUMN_CREATION_DATE];
        [query appendFormat:@"%@.%@, ", TABLE_IMAGES, IMAGES_COLUMN_ACCESS_DATE];
        [query appendFormat:@"%@.%@, ", TABLE_IMAGES, IMAGES_COLUMN_OPTIONS];
        [query appendFormat:@"%@.%@, ", TABLE_IMAGES, IMAGES_COLUMN_WIDTH];
        [query appendFormat:@"%@.%@, ", TABLE_IMAGES, IMAGES_COLUMN_HEIGHT];
        [query appendFormat:@"%@.%@ ", TABLE_DATA, DATA_COLUMN_DATA];
        [query appendFormat:@"FROM "];
        [query appendFormat:@"%@ JOIN %@ ON ", TABLE_IMAGES, TABLE_DATA];
        [query appendFormat:@"%@.%@ = %@.%@ ", TABLE_IMAGES, IMAGES_COLUMN_ID, TABLE_DATA, DATA_COLUMN_ID];
        [query appendFormat:@"WHERE %@", whereStatement];

        FMResultSet *resultSet = [db executeQuery:query];
        
        if ([resultSet next])
        {
            AMImageResult *result = [AMImageResult resultWithDbID:[resultSet intForColumnIndex:0]];
            
            result.identifier = [resultSet stringForColumnIndex:1];
            result.creationDate = [resultSet longForColumnIndex:2];
            result.accessDate = [resultSet longForColumnIndex:3];
            result.options = [resultSet stringForColumnIndex:4];
            result.size = CGSizeMake([resultSet intForColumnIndex:5], [resultSet intForColumnIndex:6]);
            result.data = [resultSet dataForColumnIndex:7];
            
            [results addObject:result];
        }
        [resultSet close];
    }];
    
    // Mark the access!
    for (AMImageResult *result in results)
        [self _updateAccessForImageWithKey:result.dbID];
    
    return results;
}

- (void)_updateAccessForImageWithKey:(NSInteger)key
{
    if (!key)
        return;
    
    [_dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        @try
        {
            NSMutableString *query = [NSMutableString string];
            
            [query appendFormat:@"UPDATE %@ ", TABLE_IMAGES];
            [query appendFormat:@"SET %@ = ? ", IMAGES_COLUMN_ACCESS_DATE];
            [query appendFormat:@"WHERE %@ = ?", IMAGES_COLUMN_KEY];
            
            if (![db executeUpdate:query, @([[NSDate date] timeIntervalSince1970]), @(key)])
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

- (BOOL)_delete:(AMImageRequest*)request
{
    if (request == nil)
        return NO;
    
    // If no where statement, do nothing
    NSString *whereStatement = [self _generateWhereStatementFromRequest:request];
    if (!whereStatement)
        return NO;

    __block BOOL succeed = NO;
    
    [_dbQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        @try
        {
            // Getting the images table "WHERE" statement.
			NSString *imagesWhereStatement = whereStatement;
			
			// Creating the data table "WHERE" statement.
			NSMutableString *dataWhereStatement = [NSMutableString string];
            
            [dataWhereStatement appendFormat:@"%@ IN (", DATA_COLUMN_ID];
            [dataWhereStatement appendFormat:@"SELECT %@.%@ ", TABLE_IMAGES, IMAGES_COLUMN_ID];
            [dataWhereStatement appendFormat:@"FROM %@ ", TABLE_IMAGES];
            [dataWhereStatement appendFormat:@"WHERE %@)", imagesWhereStatement];
            
            // Creating the delete queries
            NSString *dataQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@", TABLE_DATA, dataWhereStatement];
            NSString *imagesQuery = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@", TABLE_IMAGES, imagesWhereStatement];

            if(![db executeUpdate:dataQuery])
                @throw UpdateException;

            if (![db executeUpdate:imagesQuery])
                @throw UpdateException;
            
            succeed = YES;
        }
        @catch (NSException *exception)
        {
            if ([exception.name isEqualToString:AMImageCacheDataBaseException])
                *rollback = YES;
            else
                @throw exception;
        }
    }];
    
    return succeed;
}

- (NSString*)_generateWhereStatementFromRequest:(AMImageRequest*)request
{
    // First, build the where statement regarding size
    NSMutableString *sizeWhere = [NSMutableString string];
    
    switch (request.sizeOptions)
    {
		case AMImageRequestSizeOptionAnySize:
			break;
			
		case AMImageRequestSizeOptionExactSize:
            [sizeWhere appendFormat:@"%@.%@=%d AND ", TABLE_IMAGES, IMAGES_COLUMN_WIDTH, (int)(request.size.width*request.scale)];
            [sizeWhere appendFormat:@"%@.%@=%d", TABLE_IMAGES, IMAGES_COLUMN_HEIGHT, (int)(request.size.height*request.scale)];
			break;
    }
    
    // Creating the full where statement depending on the request type.
    NSMutableString *where = [NSMutableString string];
    
    switch (request.type)
    {
		case AMImageRequestTypeIdentifier:
            [where appendFormat:@"%@.%@=\"%@\"",TABLE_IMAGES, IMAGES_COLUMN_KEY, request.identifier];
			break;
            
		case AMImageRequestTypeIdentifierOptions:
            [where appendFormat:@"%@.%@=\"%@\" AND ",TABLE_IMAGES, IMAGES_COLUMN_KEY, request.identifier];
            [where appendFormat:@"%@.%@=\"%@\"",TABLE_IMAGES, IMAGES_COLUMN_OPTIONS, request.options];
			break;
			
		case AMImageRequestTypeOlderThanAccessDate:
            [where appendFormat:@"%@.%@<%d",TABLE_IMAGES, IMAGES_COLUMN_ACCESS_DATE, (int)request.accessDate];
			break;
            
		case AMImageRequestTypeNewerThanAccessDate:
            [where appendFormat:@"%@.%@>%d",TABLE_IMAGES, IMAGES_COLUMN_ACCESS_DATE, (int)request.accessDate];
			break;
			
		case AMImageRequestTypeUndefined:
		default:
			break;
    }
    
    // Concatenate the "WHERE" statement with the size "WHERE" sub-statement, if needed
    if ((where.length > 0) && (sizeWhere.length > 0))
        [where appendFormat:@" AND %@", sizeWhere];
    
    return where;
}

@end

