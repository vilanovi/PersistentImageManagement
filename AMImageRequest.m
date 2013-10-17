//
//  AMImageRequest.m
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

#import "AMImageRequest.h"

@implementation AMImageRequest

+ (AMImageRequest*)requestWithIdentifier:(NSString*)identifier
{
    AMImageRequest *request = [[AMImageRequest alloc] init];
    request.identifier = identifier;
    request.type = AMImageRequestTypeIdentifier;
    return request;
}

+ (AMImageRequest*)requestWithIdentifier:(NSString*)identifier options:(NSString*)options
{
    AMImageRequest *request = [[AMImageRequest alloc] init];
    request.identifier = identifier;
    request.options = options;
    request.type = AMImageRequestTypeIdentifierOptions;
    return request;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _type = AMImageRequestTypeUndefined;
        _scale = 1.0f;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    AMImageRequest *request = [[AMImageRequest allocWithZone:zone] init];
    
    request->_type = _type;
    request->_identifier = [_identifier copy];
    request->_options = [_options copy];
    request->_accessDate = _accessDate;
    request->_sizeOptions = _sizeOptions;
    request->_size = _size;
    request->_scale = _scale;
    
    return request;
}

- (NSUInteger)hash
{    
    NSMutableString *string = [NSMutableString string];
    
    [string appendFormat:@"<%d>",_type];
    [string appendFormat:@"<%@>",_identifier];
    [string appendFormat:@"<%@>",_options];
    [string appendFormat:@"<%f>",_accessDate];
    [string appendFormat:@"<%d>",_sizeOptions];
    [string appendFormat:@"<%f,%f>",_size.width, _size.height];
    [string appendFormat:@"<%f>",_scale];
    
    return [string hash];
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[AMImageRequest class]])
    {
        AMImageRequest *request = object;
        
        if (request.type == _type &&
            [request.identifier isEqual:_identifier] &&
            [request.options isEqual:_options] &&
            request.accessDate == _accessDate &&
            request.sizeOptions == _sizeOptions &&
            CGSizeEqualToSize(request.size, _size) &&
            request.scale == _scale)
        {
            return YES;
        }
    }
    
    return NO;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@: [type:%d] [identifier:%@] [options:%@] [accessDate:%f] [sizeOptions:%d] [size:%@] [scale:%f]", [super description], _type, _identifier, _options, _accessDate, _sizeOptions, NSStringFromCGSize(_size), _scale];
}

@end
