//
//  DDTrackingOptions.m
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

#import "DDTrackingOptions.h"
#import "DDConstants.h"

@interface DDTrackingOptions ()

@property (nonatomic, strong, readwrite) NSMutableSet *disabledFields;

@end

@implementation DDTrackingOptions

- (instancetype)init {
    if ((self = [super init])) {
        self.disabledFields = [[NSMutableSet alloc] init];
    }
    return self;
}

+ (instancetype)options {
    return [[self alloc] init];
}

- (DDTrackingOptions *)disableCarrier {
    [self disableTrackingField:DD_TRACKING_OPTION_CARRIER];
    return self;
}

- (BOOL)shouldTrackCarrier {
    return [self shouldTrackField:DD_TRACKING_OPTION_CARRIER];
}

- (DDTrackingOptions *)disableCity {
    [self disableTrackingField:DD_TRACKING_OPTION_CITY];
    return self;
}

- (BOOL)shouldTrackCity {
    return [self shouldTrackField:DD_TRACKING_OPTION_CITY];
}

- (DDTrackingOptions *)disableCountry {
    [self disableTrackingField:DD_TRACKING_OPTION_COUNTRY];
    return self;
}

- (BOOL)shouldTrackCountry {
    return [self shouldTrackField:DD_TRACKING_OPTION_COUNTRY];
}

- (DDTrackingOptions *)disableDeviceManufacturer {
    [self disableTrackingField:DD_TRACKING_OPTION_DEVICE_MANUFACTURER];
    return self;
}

- (BOOL)shouldTrackDeviceManufacturer {
    return [self shouldTrackField:DD_TRACKING_OPTION_DEVICE_MANUFACTURER];
}

- (DDTrackingOptions *)disableDeviceModel {
    [self disableTrackingField:DD_TRACKING_OPTION_DEVICE_MODEL];
    return self;
}

- (BOOL)shouldTrackDeviceModel {
    return [self shouldTrackField:DD_TRACKING_OPTION_DEVICE_MODEL];
}

- (DDTrackingOptions *)disableDMA {
    [self disableTrackingField:DD_TRACKING_OPTION_DMA];
    return self;
}

- (BOOL)shouldTrackDMA {
    return [self shouldTrackField:DD_TRACKING_OPTION_DMA];
}

- (DDTrackingOptions *)disableIDFA {
    [self disableTrackingField:DD_TRACKING_OPTION_IDFA];
    return self;
}

- (BOOL)shouldTrackIDFA {
    return [self shouldTrackField:DD_TRACKING_OPTION_IDFA];
}

- (DDTrackingOptions *)disableIDFV
{
    [self disableTrackingField:DD_TRACKING_OPTION_IDFV];
    return self;
}

- (BOOL)shouldTrackIDFV {
    return [self shouldTrackField:DD_TRACKING_OPTION_IDFV];
}

- (DDTrackingOptions *)disableIPAddress {
    [self disableTrackingField:DD_TRACKING_OPTION_IP_ADDRESS];
    return self;
}

- (BOOL)shouldTrackIPAddress {
    return [self shouldTrackField:DD_TRACKING_OPTION_IP_ADDRESS];
}

- (DDTrackingOptions *)disableLanguage
{
    [self disableTrackingField:DD_TRACKING_OPTION_LANGUAGE];
    return self;
}

- (BOOL)shouldTrackLanguage {
    return [self shouldTrackField:DD_TRACKING_OPTION_LANGUAGE];
}

- (DDTrackingOptions *)disableLatLng {
    [self disableTrackingField:DD_TRACKING_OPTION_LAT_LNG];
    return self;
}

- (BOOL)shouldTrackLatLng {
    return [self shouldTrackField:DD_TRACKING_OPTION_LAT_LNG];
}

- (DDTrackingOptions *)disableOSName {
    [self disableTrackingField:DD_TRACKING_OPTION_OS_NAME];
    return self;
}

- (BOOL)shouldTrackOSName {
    return [self shouldTrackField:DD_TRACKING_OPTION_OS_NAME];
}

- (DDTrackingOptions *)disableOSVersion {
    [self disableTrackingField:DD_TRACKING_OPTION_OS_VERSION];
    return self;
}

- (BOOL)shouldTrackOSVersion {
    return [self shouldTrackField:DD_TRACKING_OPTION_OS_VERSION];
}

- (DDTrackingOptions *)disablePlatform {
    [self disableTrackingField:DD_TRACKING_OPTION_PLATFORM];
    return self;
}

- (BOOL)shouldTrackPlatform {
    return [self shouldTrackField:DD_TRACKING_OPTION_PLATFORM];
}

- (DDTrackingOptions *)disableRegion {
    [self disableTrackingField:DD_TRACKING_OPTION_REGION];
    return self;
}

- (BOOL)shouldTrackRegion {
    return [self shouldTrackField:DD_TRACKING_OPTION_REGION];
}

- (DDTrackingOptions *)disableVersionName {
    [self disableTrackingField:DD_TRACKING_OPTION_VERSION_NAME];
    return self;
}

- (BOOL)shouldTrackVersionName {
    return [self shouldTrackField:DD_TRACKING_OPTION_VERSION_NAME];
}

- (void) disableTrackingField:(NSString *)field {
    [self.disabledFields addObject:field];
}

- (BOOL) shouldTrackField:(NSString *)field {
    return ![self.disabledFields containsObject:field];
}

- (NSMutableDictionary *)getApiPropertiesTrackingOption {
    NSMutableDictionary *apiPropertiesTrackingOptions = [[NSMutableDictionary alloc] init];
    if (self.disabledFields.count == 0) {
        return apiPropertiesTrackingOptions;
    }
    
    NSArray *serverSideOptions =  @[DD_TRACKING_OPTION_CITY,
                                    DD_TRACKING_OPTION_COUNTRY,
                                    DD_TRACKING_OPTION_DMA,
                                    DD_TRACKING_OPTION_IP_ADDRESS,
                                    DD_TRACKING_OPTION_LAT_LNG,
                                    DD_TRACKING_OPTION_REGION];

    for (id key in serverSideOptions) {
        if ([self.disabledFields containsObject:key]) {
            [apiPropertiesTrackingOptions setObject:[NSNumber numberWithBool:NO] forKey:key];
        }
    }

    return apiPropertiesTrackingOptions;
}

- (DDTrackingOptions *)mergeIn:(DDTrackingOptions *)other {
    for (NSString *field in other.disabledFields) {
        [self disableTrackingField:field];
    }
    
    return self;
}

+ (DDTrackingOptions *)forCoppaControl {
    NSArray *coppaControlOptions = @[DD_TRACKING_OPTION_IDFA,
                                     DD_TRACKING_OPTION_IDFV,
                                     DD_TRACKING_OPTION_CITY,
                                     DD_TRACKING_OPTION_IP_ADDRESS,
                                     DD_TRACKING_OPTION_LAT_LNG];
    
    DDTrackingOptions *options = [[DDTrackingOptions alloc] init];
    for (NSString *field in coppaControlOptions) {
        [options disableTrackingField:field];
    }
    return options;
}

+ (DDTrackingOptions *)copyOf:(DDTrackingOptions *)origin {
    DDTrackingOptions *options = [[DDTrackingOptions alloc] init];
    for (NSString *field in origin.disabledFields) {
        [options disableTrackingField:field];
    }
    
    return options;
}

@end
