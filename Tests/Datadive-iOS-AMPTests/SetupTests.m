//
//  SessionTests.m
//  SessionTests
//
//  Created by Curtis on 9/24/14.
//  Copyright (c) 2014 Datadive. All rights reserved.
//

#import <XCTest/XCTest.h>
//#import <OCMock/OCMock.h>

#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "Datadive.h"
#import "Datadive+Test.h"
#import "BaseTestCase.h"
#import "DDConstants.h"
#import "DDUtils.h"

@interface SetupTests : BaseTestCase

@end

@implementation SetupTests { }

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testApiKeySet {
    [self.datadive initializeApiKey:apiKey];
    XCTAssertEqual(self.datadive.apiKey, apiKey);
}

- (void)testDeviceIdSet {
    [self.datadive initializeApiKey:apiKey];
    [self.datadive flushQueue];
    XCTAssertNotNil([self.datadive deviceId]);
#if !TARGET_OS_OSX
    XCTAssertEqual([self.datadive deviceId].length, 36);
    XCTAssertEqualObjects([self.datadive deviceId], [[[UIDevice currentDevice] identifierForVendor] UUIDString]);
#else
    XCTAssertEqual([self.datadive deviceId].length, 12);
#endif
}

- (void)testUserIdNotSet {
    [self.datadive initializeApiKey:apiKey];
    [self.datadive flushQueue];
    XCTAssertNil([self.datadive userId]);
}

- (void)testUserIdSet {
    [self.datadive initializeApiKey:apiKey userId:userId];
    [self.datadive flushQueue];
    XCTAssertEqualObjects([self.datadive userId], userId);
}

- (void)testInitializedSet {
    [self.datadive initializeApiKey:apiKey];
    XCTAssert([self.datadive initialized]);
}

- (void)testOptOut {
    [self.datadive initializeApiKey:apiKey];

    [self.datadive setOptOut:YES];
    [self.datadive logEvent:@"Opted Out"];
    [self.datadive flushQueue];

    XCTAssert(self.datadive.optOut == YES);
    XCTAssert(![[self.datadive getLastEvent][@"event_type"] isEqualToString:@"Opted Out"]);

    [self.datadive setOptOut:NO];
    [self.datadive logEvent:@"Opted In"];
    [self.datadive flushQueue];

    XCTAssert(self.datadive.optOut == NO);
    XCTAssert([[self.datadive getLastEvent][@"event_type"] isEqualToString:@"Opted In"]);
}

- (void)testUserPropertiesSet {
    [self.datadive initializeApiKey:apiKey];
    DDDatabaseHelper *dbHelper = [DDDatabaseHelper getDatabaseHelper];
    XCTAssertEqual([dbHelper getEventCount], 0);

    NSDictionary *properties = @{
         @"shoeSize": @10,
         @"hatSize":  @5.125,
         @"name": @"John"
    };

    [self.datadive setUserProperties:properties];
    [self.datadive flushQueue];
    XCTAssertEqual([dbHelper getEventCount], 0);
    XCTAssertEqual([dbHelper getIdentifyCount], 1);
    XCTAssertEqual([dbHelper getTotalEventCount], 1);

    NSDictionary *expected = [NSDictionary dictionaryWithObject:properties forKey:AMP_OP_SET];

    NSDictionary *event = [self.datadive getLastIdentify];
    XCTAssertEqualObjects([event objectForKey:@"event_type"], IDENTIFY_EVENT);
    XCTAssertEqualObjects([event objectForKey:@"user_properties"], expected);
    XCTAssertEqualObjects([event objectForKey:@"event_properties"], [NSDictionary dictionary]); // event properties should be empty
    XCTAssertEqual(1, [[event objectForKey:@"sequence_number"] intValue]);
}

- (void)testSetDeviceId {
    DDDatabaseHelper *dbHelper = [DDDatabaseHelper getDatabaseHelper];
    NSString *initialDeviceId = [self.datadive getDeviceId];
    XCTAssertNil(initialDeviceId);  // device id not initialized yet

    [self.datadive initializeApiKey:apiKey];
    [self.datadive flushQueueWithQueue:self.datadive.initializerQueue];
    [self.datadive flushQueue];
    NSString *generatedDeviceId = [self.datadive getDeviceId];
    XCTAssertNotNil(generatedDeviceId);
    XCTAssertNotEqualObjects(initialDeviceId, generatedDeviceId);
#if !TARGET_OS_OSX
    XCTAssertEqual(generatedDeviceId.length, 36);
#else
    XCTAssertEqual(generatedDeviceId.length, 12);
#endif
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    // test setting invalid device ids
    [self.datadive setDeviceId:nil];
    [self.datadive flushQueue];
    XCTAssertEqualObjects([self.datadive getDeviceId], generatedDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    id dict = [NSDictionary dictionary];
    [self.datadive setDeviceId:dict];
    [self.datadive flushQueue];
    XCTAssertEqualObjects([self.datadive getDeviceId], generatedDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    [self.datadive setDeviceId:@"e3f5536a141811db40efd6400f1d0a4e"];
    [self.datadive flushQueue];
    XCTAssertEqualObjects([self.datadive getDeviceId], generatedDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    [self.datadive setDeviceId:@"04bab7ee75b9a58d39b8dc54e8851084"];
    [self.datadive flushQueue];
    XCTAssertEqualObjects([self.datadive getDeviceId], generatedDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    NSString *validDeviceId = [DDUtils generateUUID];
    [self.datadive setDeviceId:validDeviceId];
    [self.datadive flushQueue];
    XCTAssertEqualObjects([self.datadive getDeviceId], validDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], validDeviceId);
}

@end
