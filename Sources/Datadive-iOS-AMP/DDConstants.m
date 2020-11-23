//
//  DDConstants.m
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

#import "DDConstants.h"

NSString *const kDDLibrary = @"datadive-ios";
NSString *const kDDVersion = @"1.2.1";
NSString *const kDDUnknownLibrary = @"unknown-library";
NSString *const kDDUnknownVersion = @"unknown-version";
NSString *const kDDEventLogDomain = @"source.datadive.ai";
NSString *const kDDEventLogUrl = @"https://source.datadive.ai/event/";
NSString *const kDDDyanmicConfigUrl = @"https://regionconfig.datadive.ai/";
NSString *const kDDDefaultInstance = @"$default_instance";
const int kDDApiVersion = 3;
const int kDDDBVersion = 3;
const int kDDDBFirstVersion = 2; // to detect if DB exists yet

#if TARGET_OS_OSX
    const int kDDEventUploadThreshold = 30;
    const int kDDEventMaxCount = 1000;
    NSString *const kDDPlatform = @"macOS";
    NSString *const kDDOSName = @"macos";
#elif TARGET_OS_TV // For tvOS, upload events immediately, don't save too many events locally.
    const int kDDEventUploadThreshold = 1;
    const int kDDEventMaxCount = 100;
    NSString *const kDDPlatform = @"tvOS";
    NSString *const kDDOSName = @"tvos";
#elif TARGET_OS_MACCATALYST // This is when iPad app runs on mac.
    const int kDDEventUploadThreshold = 30;
    const int kDDEventMaxCount = 1000;
    NSString *const kDDPlatform = @"macOS";
    NSString *const kDDOSName = @"macos";
#else // iOS, simulator, etc.
    const int kDDEventUploadThreshold = 30;
    const int kDDEventMaxCount = 1000;
    NSString *const kDDPlatform = @"iOS";
    NSString *const kDDOSName = @"ios";
#endif

const int kDDEventUploadMaxBatchSize = 100;
const int kDDEventRemoveBatchSize = 20;
const int kDDEventUploadPeriodSeconds = 30; // 30 seconds
const long kDDMinTimeBetweenSessionsMillis = 5 * 60 * 1000; // 5 minutes
const int kDDMaxStringLength = 1024;
const int kDDMaxPropertyKeys = 1000;

NSString *const DD_IDENTIFY_EVENT = @"$identify";
NSString *const DD_GROUP_IDENTIFY_EVENT = @"$groupidentify";
NSString *const DD_OP_ADD = @"$add";
NSString *const DD_OP_APPEND = @"$append";
NSString *const DD_OP_CLEAR_ALL = @"$clearAll";
NSString *const DD_OP_PREPEND = @"$prepend";
NSString *const DD_OP_SET = @"$set";
NSString *const DD_OP_SET_ONCE = @"$setOnce";
NSString *const DD_OP_UNSET = @"$unset";

NSString *const DD_REVENUE_PRODUCT_ID = @"$productId";
NSString *const DD_REVENUE_QUANTITY = @"$quantity";
NSString *const DD_REVENUE_PRICE = @"$price";
NSString *const DD_REVENUE_REVENUE_TYPE = @"$revenueType";
NSString *const DD_REVENUE_RECEIPT = @"$receipt";

NSString *const DD_TRACKING_OPTION_CARRIER = @"carrier";
NSString *const DD_TRACKING_OPTION_CITY = @"city";
NSString *const DD_TRACKING_OPTION_COUNTRY = @"country";
NSString *const DD_TRACKING_OPTION_DEVICE_MANUFACTURER = @"device_manufacturer";
NSString *const DD_TRACKING_OPTION_DEVICE_MODEL = @"device_model";
NSString *const DD_TRACKING_OPTION_DMA = @"dma";
NSString *const DD_TRACKING_OPTION_IDFA = @"idfa";
NSString *const DD_TRACKING_OPTION_IDFV = @"idfv";
NSString *const DD_TRACKING_OPTION_IP_ADDRESS = @"ip_address";
NSString *const DD_TRACKING_OPTION_LANGUAGE = @"language";
NSString *const DD_TRACKING_OPTION_LAT_LNG = @"lat_lng";
NSString *const DD_TRACKING_OPTION_OS_NAME = @"os_name";
NSString *const DD_TRACKING_OPTION_OS_VERSION = @"os_version";
NSString *const DD_TRACKING_OPTION_PLATFORM = @"platform";
NSString *const DD_TRACKING_OPTION_REGION = @"region";
NSString *const DD_TRACKING_OPTION_VERSION_NAME = @"version_name";
