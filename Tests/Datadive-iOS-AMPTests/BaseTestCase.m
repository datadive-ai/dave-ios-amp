//
//  BaseTestCase.m
//  Datadive
//

#import <XCTest/XCTest.h>
//#import <OCMock/OCMock.h>
#import "Datadive+SSLPinning.h"
#import "Datadive+Test.h"
#import "BaseTestCase.h"
#import "DDDatabaseHelper.h"

NSString *const apiKey = @"000000";
NSString *const userId = @"userId";

@implementation BaseTestCase {
    id _archivedObj;
}

- (void)setUp {
    [super setUp];
    self.datadive = [Datadive alloc];
    self.databaseHelper = [DDDatabaseHelper getDatabaseHelper];
    XCTAssertTrue([self.databaseHelper resetDB:NO]);

    [self.datadive init];
    DDTrackingOptions *opts = [DDTrackingOptions options];
    XCTAssertTrue([opts shouldTrackIDFA]);
    [self.datadive setTrackingOptions:opts];
    self.datadive.sslPinningEnabled = NO;
}

- (void)tearDown {
    // Ensure all background operations are done
    [self.datadive flushQueueWithQueue:self.datadive.initializerQueue];
    [self.datadive flushQueue];
    [super tearDown];
}

- (BOOL)archive:(id)rootObject toFile:(NSString *)path {
    _archivedObj = rootObject;
    return YES;
}

- (id)unarchive:(NSString *)path {
    return _archivedObj;
}

@end
