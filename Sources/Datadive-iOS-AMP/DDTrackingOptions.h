//
//  DDTrackingOptions.h
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

#import <Foundation/Foundation.h>

@interface DDTrackingOptions : NSObject

@property (nonatomic, strong, readonly) NSMutableSet *disabledFields;

- (DDTrackingOptions *)disableCarrier;
- (DDTrackingOptions *)disableCity;
- (DDTrackingOptions *)disableCountry;
- (DDTrackingOptions *)disableDeviceManufacturer;
- (DDTrackingOptions *)disableDeviceModel;
- (DDTrackingOptions *)disableDMA;
- (DDTrackingOptions *)disableIDFA;
- (DDTrackingOptions *)disableIDFV;
- (DDTrackingOptions *)disableIPAddress;
- (DDTrackingOptions *)disableLanguage;
- (DDTrackingOptions *)disableLatLng;
- (DDTrackingOptions *)disableOSName;
- (DDTrackingOptions *)disableOSVersion;
- (DDTrackingOptions *)disablePlatform;
- (DDTrackingOptions *)disableRegion;
- (DDTrackingOptions *)disableVersionName;

- (BOOL)shouldTrackCarrier;
- (BOOL)shouldTrackCity;
- (BOOL)shouldTrackCountry;
- (BOOL)shouldTrackDeviceManufacturer;
- (BOOL)shouldTrackDeviceModel;
- (BOOL)shouldTrackDMA;
- (BOOL)shouldTrackIDFA;
- (BOOL)shouldTrackIDFV;
- (BOOL)shouldTrackIPAddress;
- (BOOL)shouldTrackLanguage;
- (BOOL)shouldTrackLatLng;
- (BOOL)shouldTrackOSName;
- (BOOL)shouldTrackOSVersion;
- (BOOL)shouldTrackPlatform;
- (BOOL)shouldTrackRegion;
- (BOOL)shouldTrackVersionName;

- (NSMutableDictionary *)getApiPropertiesTrackingOption;
- (DDTrackingOptions *)mergeIn:(DDTrackingOptions *)options;
+ (instancetype)options;
+ (DDTrackingOptions *)forCoppaControl;
+ (DDTrackingOptions *)copyOf:(DDTrackingOptions *)origin;

@end
