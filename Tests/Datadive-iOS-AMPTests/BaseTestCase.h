//
//  BaseTestCase.h
//  Datadive
//

#import <XCTest/XCTest.h>
#import "DDDatabaseHelper.h"
#if TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#else
#import <UIKit/UIKit.h>
#endif

extern NSString *const apiKey;
extern NSString *const userId;

@interface BaseTestCase : XCTestCase

@property (nonatomic, strong) Datadive *datadive;
@property (nonatomic, strong) DDDatabaseHelper *databaseHelper;

- (BOOL) archive:(id)rootObject toFile:(NSString *)path;
- (id) unarchive:(NSString *)path;

@end
