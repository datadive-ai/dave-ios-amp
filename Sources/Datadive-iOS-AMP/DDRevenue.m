//
//  DDRevenue.m
//  Copyright (c) 2020 Datadive Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#ifndef DATADIVE_DEBUG
#define DATADIVE_DEBUG 0
#endif

#ifndef DATADIVE_LOG
#if DATADIVE_DEBUG
#   define DATADIVE_LOG(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
#   define DATADIVE_LOG(...)
#endif
#endif

#import "DDRevenue.h"
#import "DDConstants.h"
#import "DDUtils.h"

@interface DDRevenue()

@end

@implementation DDRevenue{}

- (instancetype)init {
    if ((self = [super init])) {
        _quantity = 1;
    }
    return self;
}

/*
 * Create an DDRevenue object
 */
+ (instancetype)revenue {
    return [[self alloc] init];
}

- (BOOL)isValidRevenue {
    if (_price == nil) {
        DATADIVE_LOG(@"Invalid revenue, need to set price field");
        return NO;
    }
    return YES;
}

- (DDRevenue*)setProductIdentifier:(NSString *) productIdentifier {
    if ([DDUtils isEmptyString:productIdentifier]) {
        DATADIVE_LOG(@"Invalid empty productIdentifier");
        return self;
    }

    _productId = productIdentifier;
    return self;
}

- (DDRevenue*)setQuantity:(NSInteger)quantity {
    _quantity = quantity;
    return self;
}

- (DDRevenue*)setPrice:(NSNumber *)price {
    _price = price;
    return self;
}

- (DDRevenue*)setRevenueType:(NSString*)revenueType {
    _revenueType = revenueType;
    return self;
}

- (DDRevenue*)setReceipt:(NSData*)receipt {
    _receipt = receipt;
    return self;
}

- (DDRevenue*)setEventProperties:(NSDictionary*)eventProperties {
    eventProperties = [eventProperties copy];
    _properties = eventProperties;
    return self;
}

- (NSDictionary*)toNSDictionary {
    NSMutableDictionary *dict;
    if (_properties == nil) {
        dict = [[NSMutableDictionary alloc] init];
    } else {
        dict = [_properties mutableCopy];
    }

    [dict setValue:_productId forKey:AMP_REVENUE_PRODUCT_ID];
    [dict setValue:[NSNumber numberWithInteger:_quantity] forKey:AMP_REVENUE_QUANTITY];
    [dict setValue:_price forKey:AMP_REVENUE_PRICE];
    [dict setValue:_revenueType forKey:AMP_REVENUE_REVENUE_TYPE];

    if ([_receipt respondsToSelector:@selector(base64EncodedStringWithOptions:)]) {
        [dict setValue:[_receipt base64EncodedStringWithOptions:0] forKey:AMP_REVENUE_RECEIPT];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
        [dict setValue:[_receipt base64Encoding] forKey:AMP_REVENUE_RECEIPT];
#pragma clang diagnostic pop
    }

    return dict;
}

@end
