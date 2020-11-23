//
//  DeviceInfoTests.m
//  Datadive
//

#import <XCTest/XCTest.h>
//#import <OCMock/OCMock.h>

#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "DDConstants.h"
#import "DDDeviceInfo.h"

@interface DeviceInfoTests : XCTestCase

@end

@implementation DeviceInfoTests {
    DDDeviceInfo *_deviceInfo;
}

- (void)setUp {
    [super setUp];
    _deviceInfo = [[DDDeviceInfo alloc] init];
}

- (void)tearDown {
    [super tearDown];
}

//- (void)testAppVersion {
//    id mockBundle = [OCMockObject niceMockForClass:[NSBundle class]];
//    [[[mockBundle stub] andReturn:mockBundle] mainBundle];
//    NSDictionary *mockDictionary = @{
//        @"CFBundleShortVersionString": kDDVersion
//    };
//    OCMStub([mockBundle infoDictionary]).andReturn(mockDictionary);
//
//    XCTAssertEqualObjects(kDDVersion, _deviceInfo.appVersion);
//    [mockBundle stopMocking];
//}

- (void)testOsName {
#if TARGET_OS_MACCATALYST || TARGET_OS_OSX
    XCTAssertEqualObjects(@"macos", _deviceInfo.osName);
#elif TARGET_OS_IOS
    XCTAssertEqualObjects(@"ios", _deviceInfo.osName);
#elif TARGET_OS_TV
    XCTAssertEqualObjects(@"tvos", _deviceInfo.osName);
#endif
}

- (void)testOsVersion {
#if !TARGET_OS_OSX
    XCTAssertEqualObjects([[UIDevice currentDevice] systemVersion], _deviceInfo.osVersion);
#else
    XCTAssertTrue([[[NSProcessInfo processInfo] operatingSystemVersionString] containsString: _deviceInfo.osVersion]);
#endif
}

- (void)testManufacturer {
    XCTAssertEqualObjects(@"Apple", _deviceInfo.manufacturer);
}

- (void)testModel {
#if !TARGET_OS_OSX
    XCTAssertEqualObjects(@"Simulator", _deviceInfo.model);
#else
    XCTAssertTrue([_deviceInfo.model containsString:@"Mac"]);
#endif
}

- (void)testCountry {
    XCTAssertEqualObjects(@"South Korea", _deviceInfo.country);
}

- (void)testLanguage {
    XCTAssertEqualObjects(@"English", _deviceInfo.language);
}


#if TARGET_OS_IPHONE
- (void)testVendorID {
    XCTAssertEqualObjects(_deviceInfo.vendorID, [[[UIDevice currentDevice] identifierForVendor] UUIDString]);
}
#endif

- (void)testGenerateUUID {
    NSString *a = [DDDeviceInfo generateUUID];
    NSString *b = [DDDeviceInfo generateUUID];
    XCTAssertNotNil(a);
    XCTAssertNotNil(b);
    XCTAssertNotEqual(a, b);
    XCTAssertNotEqual(a, b);
}

@end
