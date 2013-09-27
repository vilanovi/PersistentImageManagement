//
//  AMImageCache.h
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

#import <Foundation/Foundation.h>

#import "AMImageRequest.h"

extern NSString * const AMImageCacheDataBaseException;

@interface AMImageCache : NSObject

+ (AMImageCache*)cacheAtURL:(NSURL*)url;

- (id)initWithURL:(NSURL *)url;

@property (nonatomic, strong) NSURL *url;

- (UIImage*)executeRequest:(AMImageRequest*)request;
- (void)executeRequest:(AMImageRequest*)request completion:(void (^)(UIImage *image))completionBlock;
- (UIImage*)executeRequestInDynamicCache:(AMImageRequest*)request;

- (void)storeImage:(UIImage*)image;
- (void)storeImage:(UIImage*)image forIdentifier:(NSString*)identifier;
- (void)storeImage:(UIImage*)image forIdentifier:(NSString*)identifier isOriginal:(BOOL)isOriginal;
- (void)storeImage:(UIImage*)image forRequest:(AMImageRequest*)request;

- (void)cleanCacheUsingAccessDate:(NSTimeInterval)accessDate completion:(void (^)())completionBlock;

@end
