//
//  DDConstants.h
//  Copyright (c) 2014 Datadive Inc.
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

#import <Foundation/Foundation.h>

extern NSString *const kDDLibrary;
extern NSString *const kDDVersion;
extern NSString *const kDDUnknownLibrary;
extern NSString *const kDDUnknownVersion;
extern NSString *const kDDPlatform;
extern NSString *const kDDOSName;
extern NSString *const kDDEventLogDomain;
extern NSString *const kDDEventLogUrl;
extern NSString *const kDDDyanmicConfigUrl;
extern NSString *const kDDDefaultInstance;
extern const int kDDApiVersion;
extern const int kDDDBVersion;
extern const int kDDDBFirstVersion;
extern const int kDDEventUploadThreshold;
extern const int kDDEventUploadMaxBatchSize;
extern const int kDDEventMaxCount;
extern const int kDDEventRemoveBatchSize;
extern const int kDDEventUploadPeriodSeconds;
extern const long kDDMinTimeBetweenSessionsMillis;
extern const int kDDMaxStringLength;
extern const int kDDMaxPropertyKeys;

extern NSString *const IDENTIFY_EVENT;
extern NSString *const GROUP_IDENTIFY_EVENT;
extern NSString *const DD_OP_ADD;
extern NSString *const DD_OP_APPEND;
extern NSString *const DD_OP_CLEAR_ALL;
extern NSString *const DD_OP_PREPEND;
extern NSString *const DD_OP_SET;
extern NSString *const DD_OP_SET_ONCE;
extern NSString *const DD_OP_UNSET;

// Revenue
extern NSString *const DD_REVENUE_PRODUCT_ID;
extern NSString *const DD_REVENUE_QUANTITY;
extern NSString *const DD_REVENUE_PRICE;
extern NSString *const DD_REVENUE_REVENUE_TYPE;
extern NSString *const DD_REVENUE_RECEIPT;

// Options
extern NSString *const DD_TRACKING_OPTION_CARRIER;
extern NSString *const DD_TRACKING_OPTION_CITY;
extern NSString *const DD_TRACKING_OPTION_COUNTRY;
extern NSString *const DD_TRACKING_OPTION_DEVICE_MANUFACTURER;
extern NSString *const DD_TRACKING_OPTION_DEVICE_MODEL;
extern NSString *const DD_TRACKING_OPTION_DMA;
extern NSString *const DD_TRACKING_OPTION_IDFA;
extern NSString *const DD_TRACKING_OPTION_IDFV;
extern NSString *const DD_TRACKING_OPTION_IP_ADDRESS;
extern NSString *const DD_TRACKING_OPTION_LANGUAGE;
extern NSString *const DD_TRACKING_OPTION_LAT_LNG;
extern NSString *const DD_TRACKING_OPTION_OS_NAME;
extern NSString *const DD_TRACKING_OPTION_OS_VERSION;
extern NSString *const DD_TRACKING_OPTION_PLATFORM;
extern NSString *const DD_TRACKING_OPTION_REGION;
extern NSString *const DD_TRACKING_OPTION_VERSION_NAME;
