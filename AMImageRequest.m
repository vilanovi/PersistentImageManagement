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
    return [[AMImageRequest alloc] initWithIdentifier:identifier];
}

- (id)initWithIdentifier:(NSString*)identifier;
{
    self = [super init];
    if (self)
    {
        _identifier = identifier;
        _size = CGSizeZero;
        _scale = [[UIScreen mainScreen] scale];
        _sizeOption = AMImageRequestSizeOptionAnySize;
        _offsetSize = CGSizeZero;
        _similarRatio = 1.0f;
        _restrictOptions = AMImageRequestOptionRestrictDisabled;
        _original = NO;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    AMImageRequest *request = [[AMImageRequest allocWithZone:zone] init];
    
    request->_identifier = [_identifier copy];
    request->_size = _size;
    request->_scale = _scale;
    request->_sizeOption = _sizeOption;
    request->_offsetSize = _offsetSize;
    request->_similarRatio = _similarRatio;
    request->_restrictOptions = _restrictOptions;
    request->_original = _original;
    
    return request;
}

- (NSUInteger)hash
{    
    NSMutableString *string = [NSMutableString string];
    
    if (_identifier)
        [string appendFormat:@"<%@>",_identifier];
    
    [string appendFormat:@"<%f,%f>",_size.width, _size.height];
    [string appendFormat:@"<%f>",_scale];
    [string appendFormat:@"<%d>",_sizeOption];
    [string appendFormat:@"<%f,%f>",_offsetSize.width, _offsetSize.height];
    [string appendFormat:@"<%f>",_similarRatio];
    [string appendFormat:@"<%d>",_restrictOptions];
    [string appendFormat:@"<%d>",_original];
    
    
    return [string hash];
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[AMImageRequest class]])
    {
        AMImageRequest *request = object;
        
        if ([request.identifier isEqual:_identifier] &&
            CGSizeEqualToSize(request.size, _size) &&
            request.scale == _scale &&
            request.sizeOption == _sizeOption &&
            CGSizeEqualToSize(request.offsetSize, _offsetSize) &&
            request.similarRatio == _similarRatio &&
            request.restrictOptions == _restrictOptions &&
            request.original == _original)
        {
            return YES;
        }
    }
    
    return NO;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@: [identifier:%@] [size:%@] [scale:%f] [sizeOption:%d] [offsetSize:%@] [similarRatio:%f] [restrictOptions:%d] [original:%@]", [super description], _identifier, NSStringFromCGSize(_size), _scale, _sizeOption, NSStringFromCGSize(_offsetSize), _similarRatio, _restrictOptions, (_original?@"YES":@"NO")];
}

#pragma mark Properties

- (void)setSize:(CGSize)size
{
    _size = size;
    
    if (CGSizeEqualToSize(size, CGSizeZero) && _sizeOption == AMImageRequestSizeOptionExactSize)
        _sizeOption = AMImageRequestSizeOptionAnySize;
    
    else if (_sizeOption == AMImageRequestSizeOptionAnySize)
        _sizeOption = AMImageRequestSizeOptionExactSize;
}

- (void)setOffsetSize:(CGSize)offsetSize
{
    _offsetSize = offsetSize;
    _sizeOption = AMImageRequestSizeOptionInOffsetSize;
}

- (void)setSimilarRatio:(CGFloat)similarRatio
{
    _similarRatio = similarRatio;
    _sizeOption = AMImageRequestSizeOptionSimilarSize;
}

@end
