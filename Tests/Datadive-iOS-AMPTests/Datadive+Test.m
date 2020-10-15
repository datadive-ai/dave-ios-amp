//
//  Datadive+Test.m
//  Datadive
//
//  Created by Allan on 3/11/15.
//  Copyright (c) 2015 Datadive. All rights reserved.
//

#import "Datadive.h"
#import "Datadive+Test.h"
#import "DDDatabaseHelper.h"

@implementation Datadive (Test)

@dynamic backgroundQueue;
@dynamic initializerQueue;
@dynamic eventsData;
@dynamic initialized;
@dynamic sessionId;
@dynamic lastEventTime;
@dynamic backoffUpload;
@dynamic backoffUploadBatchSize;
@dynamic sslPinningEnabled;

- (void)flushQueue {
    [self flushQueueWithQueue:[self backgroundQueue]];
}

- (void)flushQueueWithQueue:(NSOperationQueue*) queue {
    [queue waitUntilAllOperationsAreFinished];
}

- (NSDictionary *)getEvent:(NSInteger) fromEnd {
    NSArray *events = [[DDDatabaseHelper getDatabaseHelper] getEvents:-1 limit:-1];
    return [events objectAtIndex:[events count] - fromEnd - 1];
}

- (NSDictionary *)getLastEventFromInstanceName:(NSString *)instanceName {
    NSArray *events = [[DDDatabaseHelper getDatabaseHelper: instanceName] getEvents:-1 limit:-1];
    return [events lastObject];
}

- (NSDictionary *)getLastEvent {
    NSArray *events = [[DDDatabaseHelper getDatabaseHelper] getEvents:-1 limit:-1];
    return [events lastObject];
}

- (NSDictionary *)getLastIdentify {
    NSArray *identifys = [[DDDatabaseHelper getDatabaseHelper] getIdentifys:-1 limit:-1];
    return [identifys lastObject];
}

- (NSUInteger)queuedEventCount {
    return [[DDDatabaseHelper getDatabaseHelper] getEventCount];
}

- (void)flushUploads:(void (^)(void))handler {
    [self performSelector:@selector(uploadEvents)];
    [self flushQueue];

    // Wait a second for the upload response to get into the queue.
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        [self flushQueue];
        handler();
    });
}

@end

