//
//  TrackingOptionsTest.m
//  Datadive
//

#import <XCTest/XCTest.h>
#import "DDTrackingOptions.h"
#import "DDConstants.h"

@interface TrackingOptionsTests : XCTestCase

@end

@implementation TrackingOptionsTests { }

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testDisableFields {
    DDTrackingOptions *options = [[[[DDTrackingOptions options] disableCity] disableIPAddress] disableLanguage];

    XCTAssertTrue([options shouldTrackCarrier]);
    XCTAssertFalse([options shouldTrackCity]);
    XCTAssertTrue([options shouldTrackCountry]);
    XCTAssertTrue([options shouldTrackDeviceManufacturer]);
    XCTAssertTrue([options shouldTrackDeviceModel]);
    XCTAssertTrue([options shouldTrackDMA]);
    XCTAssertTrue([options shouldTrackIDFA]);
    XCTAssertTrue([options shouldTrackIDFV]);
    XCTAssertFalse([options shouldTrackIPAddress]);
    XCTAssertFalse([options shouldTrackLanguage]);
    XCTAssertTrue([options shouldTrackLatLng]);
    XCTAssertTrue([options shouldTrackOSName]);
    XCTAssertTrue([options shouldTrackOSVersion]);
    XCTAssertTrue([options shouldTrackPlatform]);
    XCTAssertTrue([options shouldTrackRegion]);
    XCTAssertTrue([options shouldTrackVersionName]);
}

- (void)testGetApiPropertiesTrackingOptions {
    DDTrackingOptions *options = [[[[[[DDTrackingOptions options] disableCity] disableIPAddress] disableLanguage] disableCountry] disableLatLng];

    NSMutableDictionary *apiPropertiesTrackingOptions = [options getApiPropertiesTrackingOption];
    XCTAssertEqual([apiPropertiesTrackingOptions count], 4);
    XCTAssertEqual([apiPropertiesTrackingOptions objectForKey:@"city"], [NSNumber numberWithBool:NO]);
    XCTAssertEqual([apiPropertiesTrackingOptions objectForKey:@"country"], [NSNumber numberWithBool:NO]);
    XCTAssertEqual([apiPropertiesTrackingOptions objectForKey:@"ip_address"], [NSNumber numberWithBool:NO]);
    XCTAssertEqual([apiPropertiesTrackingOptions objectForKey:@"lat_lng"], [NSNumber numberWithBool:NO]);
}

- (void)testGetCoppaControlTrackingOptions {
    DDTrackingOptions *options = [DDTrackingOptions forCoppaControl];
    XCTAssertFalse(options.shouldTrackIDFA);
    XCTAssertFalse(options.shouldTrackCity);
    XCTAssertFalse(options.shouldTrackIPAddress);
    XCTAssertFalse(options.shouldTrackLatLng);
}

- (void)testMerging {
    DDTrackingOptions *options1 = [DDTrackingOptions forCoppaControl];
    DDTrackingOptions *options2 = [[[DDTrackingOptions options] disableCountry] disableLanguage];
    [options1 mergeIn:options2];
    
    XCTAssertFalse(options1.shouldTrackIDFA);
    XCTAssertFalse(options1.shouldTrackCity);
    XCTAssertFalse(options1.shouldTrackIPAddress);
    XCTAssertFalse(options1.shouldTrackLatLng);
    
    XCTAssertFalse(options1.shouldTrackCountry);
    XCTAssertFalse(options1.shouldTrackLanguage);
}

- (void)testCopyOf {
    DDTrackingOptions *options = [DDTrackingOptions copyOf:[DDTrackingOptions forCoppaControl]];
    
    XCTAssertFalse(options.shouldTrackIDFA);
    XCTAssertFalse(options.shouldTrackCity);
    XCTAssertFalse(options.shouldTrackIPAddress);
    XCTAssertFalse(options.shouldTrackLatLng);
}

@end
