//
//  Datadive.m
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

#ifndef DATADIVE_LOG_ERRORS
#define DATADIVE_LOG_ERRORS 1
#endif

#ifndef DATADIVE_ERROR
#if DATADIVE_LOG_ERRORS
#   define DATADIVE_ERROR(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
#   define DATADIVE_ERROR(...)
#endif
#endif


#import "Datadive.h"
#import "DatadivePrivate.h"
#import "DDConstants.h"
#import "DDConfigManager.h"
#import "DDDeviceInfo.h"
#import "DDURLConnection.h"
#import "DDURLSession.h"
#import "DDDatabaseHelper.h"
#import "DDUtils.h"
#import "DDIdentify.h"
#import "DDRevenue.h"
#import "DDTrackingOptions.h"
#import <math.h>
#import <CommonCrypto/CommonDigest.h>

#import <net/if.h>
#import <net/if_dl.h>
#import <sys/socket.h>
#import <sys/sysctl.h>
#import <sys/types.h>

#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

@interface Datadive ()

@property (nonatomic, strong) NSOperationQueue *backgroundQueue;
@property (nonatomic, strong) NSOperationQueue *initializerQueue;
@property (nonatomic, strong) DDDatabaseHelper *dbHelper;
@property (nonatomic, assign) BOOL initialized;
@property (nonatomic, assign) BOOL sslPinningEnabled;
@property (nonatomic, assign) long long sessionId;
@property (nonatomic, assign) BOOL backoffUpload;
@property (nonatomic, assign) int backoffUploadBatchSize;
@end

NSString *const kDDSessionStartEvent = @"session_start";
NSString *const kDDSessionEndEvent = @"session_end";
NSString *const kDDRevenueEvent = @"revenue_amount";

static NSString *const BACKGROUND_QUEUE_NAME = @"BACKGROUND";
static NSString *const DATABASE_VERSION = @"database_version";
static NSString *const DEVICE_ID = @"device_id";
static NSString *const EVENTS = @"events";
static NSString *const EVENT_ID = @"event_id";
static NSString *const PREVIOUS_SESSION_ID = @"previous_session_id";
static NSString *const PREVIOUS_SESSION_TIME = @"previous_session_time";
static NSString *const MAX_EVENT_ID = @"max_event_id";
static NSString *const MAX_IDENTIFY_ID = @"max_identify_id";
static NSString *const OPT_OUT = @"opt_out";
static NSString *const USER_ID = @"user_id";
static NSString *const SEQUENCE_NUMBER = @"sequence_number";


@implementation Datadive {
    NSString *_eventsDataPath;
    NSMutableDictionary *_propertyList;

    BOOL _updateScheduled;
    BOOL _updatingCurrently;
    
#if !TARGET_OS_OSX
    UIBackgroundTaskIdentifier _uploadTaskID;
#endif

    DDDeviceInfo *_deviceInfo;
    BOOL _useAdvertisingIdForDeviceId;

    DDTrackingOptions *_inputTrackingOptions;
    DDTrackingOptions *_appliedTrackingOptions;
    NSDictionary *_apiPropertiesTrackingOptions;
    BOOL _coppaControlEnabled;
    
    BOOL _inForeground;
    BOOL _offline;

    NSString *_serverUrl;
    NSString *_token;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma mark - Static methods

+ (Datadive *)instance {
    return [Datadive instanceWithName:nil];
}

+ (Datadive *)instanceWithName:(NSString *)instanceName {
    static NSMutableDictionary *_instances = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instances = [[NSMutableDictionary alloc] init];
    });

    // compiler wants explicit key nil check even though DDUtils isEmptyString already has one
    if (instanceName == nil || [DDUtils isEmptyString:instanceName]) {
        instanceName = kDDDefaultInstance;
    }
    instanceName = [instanceName lowercaseString];

    Datadive *client = nil;
    @synchronized(_instances) {
        client = [_instances objectForKey:instanceName];
        if (client == nil) {
            client = [[self alloc] initWithInstanceName:instanceName];
            [_instances setObject:client forKey:instanceName];
        }
    }

    return client;
}

#pragma mark - Main class methods
- (instancetype)init {
    return [self initWithInstanceName:nil];
}

- (instancetype)initWithInstanceName:(NSString*)instanceName {
    if ([DDUtils isEmptyString:instanceName]) {
        instanceName = kDDDefaultInstance;
    }
    instanceName = [instanceName lowercaseString];

    if ((self = [super init])) {

#if DATADIVE_SSL_PINNING
        _sslPinningEnabled = YES;
#else
        _sslPinningEnabled = NO;
#endif

        _initialized = NO;
        _sessionId = -1;
        _updateScheduled = NO;
        _updatingCurrently = NO;
        _useAdvertisingIdForDeviceId = NO;
        _backoffUpload = NO;
        _offline = NO;
        _serverUrl = kDDEventLogUrl;
        self.libraryName = kDDLibrary;
        self.libraryVersion = kDDVersion;
        _inputTrackingOptions = [DDTrackingOptions options];
        _appliedTrackingOptions = [DDTrackingOptions copyOf:_inputTrackingOptions];
        _apiPropertiesTrackingOptions = [NSDictionary dictionary];
        _coppaControlEnabled = NO;
        self.instanceName = instanceName;
        _dbHelper = [DDDatabaseHelper getDatabaseHelper:instanceName];

        self.eventUploadThreshold = kDDEventUploadThreshold;
        self.eventMaxCount = kDDEventMaxCount;
        self.eventUploadMaxBatchSize = kDDEventUploadMaxBatchSize;
        self.eventUploadPeriodSeconds = kDDEventUploadPeriodSeconds;
        self.minTimeBetweenSessionsMillis = kDDMinTimeBetweenSessionsMillis;
        _backoffUploadBatchSize = self.eventUploadMaxBatchSize;

        _initializerQueue = [[NSOperationQueue alloc] init];
        _backgroundQueue = [[NSOperationQueue alloc] init];
        // Force method calls to happen in FIFO order by only allowing 1 concurrent operation
        [_backgroundQueue setMaxConcurrentOperationCount:1];
        // Ensure initialize finishes running asynchronously before other calls are run
        [_backgroundQueue setSuspended:YES];
        // Name the queue so runOnBackgroundQueue can tell which queue an operation is running
        _backgroundQueue.name = BACKGROUND_QUEUE_NAME;
        
        [_initializerQueue addOperationWithBlock:^{

        #if !TARGET_OS_OSX
            self->_uploadTaskID = UIBackgroundTaskInvalid;
        #endif
            
            NSString *eventsDataDirectory = [DDUtils platformDataDirectory];
            NSString *propertyListPath = [eventsDataDirectory stringByAppendingPathComponent:@"ai.datadive.plist"];
            if (![self.instanceName isEqualToString:kDDDefaultInstance]) {
                propertyListPath = [NSString stringWithFormat:@"%@_%@", propertyListPath, self.instanceName]; // namespace pList with instance name
            }
            self->_propertyListPath = propertyListPath;
            self->_eventsDataPath = [eventsDataDirectory stringByAppendingPathComponent:@"ai.datadive.archiveDict"];
            [self upgradePrefs];

            // Load propertyList object
            self->_propertyList = [self deserializePList:self->_propertyListPath];
            if (!self->_propertyList) {
                self->_propertyList = [NSMutableDictionary dictionary];
                [self->_propertyList setObject:[NSNumber numberWithInt:1] forKey:DATABASE_VERSION];
                BOOL success = [self savePropertyList];
                if (!success) {
                    DATADIVE_ERROR(@"ERROR: Unable to save propertyList to file on initialization");
                }
            } else {
                DATADIVE_LOG(@"Loaded from %@", _propertyListPath);
            }

            // update database if necessary
            int oldDBVersion = 1;
            NSNumber *oldDBVersionSaved = [self->_propertyList objectForKey:DATABASE_VERSION];
            if (oldDBVersionSaved != nil) {
                oldDBVersion = [oldDBVersionSaved intValue];
            }

            // update the database
            if (oldDBVersion < kDDDBVersion) {
                if ([self.dbHelper upgrade:oldDBVersion newVersion:kDDDBVersion]) {
                    [self->_propertyList setObject:[NSNumber numberWithInt:kDDDBVersion] forKey:DATABASE_VERSION];
                    [self savePropertyList];
                }
            }

            // only on default instance, migrate all of old _eventsData object to database store if database just created
            if ([self.instanceName isEqualToString:kDDDefaultInstance] && oldDBVersion < kDDDBFirstVersion) {
                if ([self migrateEventsDataToDB]) {
                    // delete events data so don't need to migrate next time
                    if ([[NSFileManager defaultManager] fileExistsAtPath:self->_eventsDataPath]) {
                        [[NSFileManager defaultManager] removeItemAtPath:self->_eventsDataPath error:NULL];
                    }
                }
            }

            // try to restore previous session
            long long previousSessionId = [self previousSessionId];
            if (previousSessionId >= 0) {
                self->_sessionId = previousSessionId;
            }

            [self->_backgroundQueue setSuspended:NO];
        }];

        [self addObservers];
    }
    return self;
}

// maintain backwards compatibility on default instance
- (BOOL)migrateEventsDataToDB {
    NSDictionary *eventsData = [self unarchive:_eventsDataPath];
    if (eventsData == nil) {
        return NO;
    }

    DDDatabaseHelper *defaultDbHelper = [DDDatabaseHelper getDatabaseHelper];
    BOOL success = YES;

    // migrate events
    NSArray *events = [eventsData objectForKey:EVENTS];
    for (id event in events) {
        NSError *error = nil;
        NSData *jsonData = nil;
        jsonData = [NSJSONSerialization dataWithJSONObject:[DDUtils makeJSONSerializable:event] options:0 error:&error];
        if (error != nil) {
            DATADIVE_ERROR(@"ERROR: NSJSONSerialization error: %@", error);
            continue;
        }
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        if ([DDUtils isEmptyString:jsonString]) {
            DATADIVE_ERROR(@"ERROR: NSJSONSerialization resulted in a null string, skipping this event");
            continue;
        }
        success &= [defaultDbHelper addEvent:jsonString];
    }

    // migrate remaining properties
    NSString *userId = [eventsData objectForKey:USER_ID];
    if (userId != nil) {
        success &= [defaultDbHelper insertOrReplaceKeyValue:USER_ID value:userId];
    }
    NSNumber *optOut = [eventsData objectForKey:OPT_OUT];
    if (optOut != nil) {
        success &= [defaultDbHelper insertOrReplaceKeyLongValue:OPT_OUT value:optOut];
    }
    NSString *deviceId = [eventsData objectForKey:DEVICE_ID];
    if (deviceId != nil) {
        success &= [defaultDbHelper insertOrReplaceKeyValue:DEVICE_ID value:deviceId];
    }
    NSNumber *previousSessionId = [eventsData objectForKey:PREVIOUS_SESSION_ID];
    if (previousSessionId != nil) {
        success &= [defaultDbHelper insertOrReplaceKeyLongValue:PREVIOUS_SESSION_ID value:previousSessionId];
    }
    NSNumber *previousSessionTime = [eventsData objectForKey:PREVIOUS_SESSION_TIME];
    if (previousSessionTime != nil) {
        success &= [defaultDbHelper insertOrReplaceKeyLongValue:PREVIOUS_SESSION_TIME value:previousSessionTime];
    }

    return success;
}

- (void)addObservers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
#if !TARGET_OS_OSX
    [center addObserver:self
               selector:@selector(enterForeground)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(enterBackground)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
#else
    [center addObserver:self
               selector:@selector(enterForeground)
                   name:NSApplicationDidBecomeActiveNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(enterBackground)
                   name:NSApplicationDidResignActiveNotification
                 object:nil];
#endif
}

- (void)removeObservers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
#if !TARGET_OS_OSX
    [center removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [center removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
#else
    [center removeObserver:self name:NSApplicationDidBecomeActiveNotification object:nil];
    [center removeObserver:self name:NSApplicationDidResignActiveNotification object:nil];
#endif
}

- (void)dealloc {
    [self removeObservers];
}

- (void)initializeApiKey:(NSString *)apiKey {
    [self initializeApiKey:apiKey userId:nil setUserId: NO];
}

/**
 * Initialize Datadive with a given apiKey and userId.
 */
- (void)initializeApiKey:(NSString *)apiKey
                  userId:(NSString *)userId {
    [self initializeApiKey:apiKey userId:userId setUserId: YES];
}

/**
 * SetUserId: client explicitly initialized with a userId (can be nil).
 * If setUserId is NO, then attempt to load userId from saved eventsData.
 */
- (void)initializeApiKey:(NSString *)apiKey
                  userId:(NSString *)userId
               setUserId:(BOOL)setUserId {
    if (apiKey == nil) {
        DATADIVE_ERROR(@"ERROR: apiKey cannot be nil in initializeApiKey:");
        return;
    }

    if (![self isArgument:apiKey validType:[NSString class] methodName:@"initializeApiKey:"]) {
        return;
    }
    if (userId != nil && ![self isArgument:userId validType:[NSString class] methodName:@"initializeApiKey:"]) {
        return;
    }

    if ([apiKey length] == 0) {
        DATADIVE_ERROR(@"ERROR: apiKey cannot be blank in initializeApiKey:");
        return;
    }

    if (!_initialized) {
        self.apiKey = apiKey;

        [self runOnBackgroundQueue:^{
            self->_deviceInfo = [[DDDeviceInfo alloc] init];
            [self initializeDeviceId];
            if (setUserId) {
                [self setUserId:userId];
            } else {
                self.userId = [self.dbHelper getValue:USER_ID];
            }
        }];

        // Normally _inForeground is set by the enterForeground callback, but initializeWithApiKey will be called after the app's enterForeground
        // notification is already triggered, so we need to manually check and set it now.
        // UIApplication methods are only allowed on the main thread so need to dispatch this synchronously to the main thread.
        void (^checkInForeground)(void) = ^{
        #if !TARGET_OS_OSX
            UIApplication *app = [DDUtils getSharedApplication];
            if (app != nil) {
                UIApplicationState state = app.applicationState;
                if (state != UIApplicationStateBackground) {
                    [self runOnBackgroundQueue:^{
        #endif
                        // The earliest time to fetch dynamic config
                        [self refreshDynamicConfig];
                        
                        NSNumber *now = [NSNumber numberWithLongLong:[[self currentTime] timeIntervalSince1970] * 1000];
                        [self startOrContinueSessionNSNumber:now];
                        self->_inForeground = YES;
        #if !TARGET_OS_OSX
                    }];

                }
            }
        #endif
        };
        [self runSynchronouslyOnMainQueue:checkInForeground];
        _initialized = YES;
    }
}

/**
 * Run a block in the background. If already in the background, run immediately.
 */
- (BOOL)runOnBackgroundQueue:(void (^)(void))block {
    if ([[NSOperationQueue currentQueue].name isEqualToString:BACKGROUND_QUEUE_NAME]) {
        DATADIVE_LOG(@"Already running in the background.");
        block();
        return NO;
    } else {
        [_backgroundQueue addOperationWithBlock:block];
        return YES;
    }
}

/**
 * Run a block on the main thread. If already on the main thread, run immediately.
 */
- (void)runSynchronouslyOnMainQueue:(void (^)(void))block {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

#pragma mark - logEvent

- (void)logEvent:(NSString *)eventType {
    [self logEvent:eventType withEventProperties:nil];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties {
    [self logEvent:eventType withEventProperties:eventProperties withGroups:nil];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties outOfSession:(BOOL)outOfSession {
    [self logEvent:eventType withEventProperties:eventProperties withGroups:nil outOfSession:outOfSession];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withGroups:(NSDictionary *)groups {
    [self logEvent:eventType withEventProperties:eventProperties withGroups:groups outOfSession:NO];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withGroups:(NSDictionary *)groups outOfSession:(BOOL)outOfSession {
    [self logEvent:eventType withEventProperties:eventProperties withApiProperties:nil withUserProperties:nil withGroups:groups withGroupProperties:nil withTimestamp:nil outOfSession:outOfSession];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withGroups:(NSDictionary *)groups withLongLongTimestamp:(long long) timestamp outOfSession:(BOOL)outOfSession {
    [self logEvent:eventType withEventProperties:eventProperties withApiProperties:nil withUserProperties:nil withGroups:groups withGroupProperties:nil withTimestamp:[NSNumber numberWithLongLong:timestamp] outOfSession:outOfSession];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withGroups:(NSDictionary *)groups withTimestamp:(NSNumber *)timestamp outOfSession:(BOOL)outOfSession {
    [self logEvent:eventType withEventProperties:eventProperties withApiProperties:nil withUserProperties:nil withGroups:groups withGroupProperties:nil withTimestamp:timestamp outOfSession:outOfSession];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withApiProperties:(NSDictionary *)apiProperties withUserProperties:(NSDictionary *)userProperties withGroups:(NSDictionary *)groups withGroupProperties:(NSDictionary *)groupProperties withTimestamp:(NSNumber *)timestamp outOfSession:(BOOL)outOfSession {
    if (self.apiKey == nil) {
        DATADIVE_ERROR(@"ERROR: apiKey cannot be nil or empty, set apiKey with initializeApiKey: before calling logEvent");
        return;
    }

    if (![self isArgument:eventType validType:[NSString class] methodName:@"logEvent"]) {
        DATADIVE_ERROR(@"ERROR: eventType must be an NSString");
        return;
    }
    if (eventProperties != nil && ![self isArgument:eventProperties validType:[NSDictionary class] methodName:@"logEvent"]) {
        DATADIVE_ERROR(@"ERROR: eventProperties must by a NSDictionary");
        return;
    }

    if (timestamp == nil) {
        timestamp = [NSNumber numberWithLongLong:[[self currentTime] timeIntervalSince1970] * 1000];
    }

    // Create snapshot of all event json objects, to prevent deallocation crash
    eventProperties = [eventProperties copy];
    apiProperties = [apiProperties mutableCopy];
    userProperties = [userProperties copy];
    groups = [groups copy];
    groupProperties = [groupProperties copy];
    
    [self runOnBackgroundQueue:^{
        // Respect the opt-out setting by not sending or storing any events.
        if ([self optOut]) {
            DATADIVE_LOG(@"User has opted out of tracking. Event %@ not logged.", eventType);
            return;
        }

        // skip session check if logging start_session or end_session events
        BOOL loggingSessionEvent = self->_trackingSessionEvents && ([eventType isEqualToString:kDDSessionStartEvent] || [eventType isEqualToString:kDDSessionEndEvent]);
        if (!loggingSessionEvent && !outOfSession) {
            [self startOrContinueSessionNSNumber:timestamp];
        }

        NSMutableDictionary *event = [NSMutableDictionary dictionary];
        [event setValue:eventType forKey:@"event_type"];
        [event setValue:[self truncate:[DDUtils makeJSONSerializable:[self replaceWithEmptyJSON:eventProperties]]] forKey:@"event_properties"];
        [event setValue:[self replaceWithEmptyJSON:apiProperties] forKey:@"api_properties"];
        [event setValue:[self truncate:[DDUtils makeJSONSerializable:[self replaceWithEmptyJSON:userProperties]]] forKey:@"user_properties"];
        [event setValue:[self truncate:[DDUtils validateGroups:[self replaceWithEmptyJSON:groups]]] forKey:@"groups"];
        [event setValue:[self truncate:[DDUtils makeJSONSerializable:[self replaceWithEmptyJSON:groupProperties]]] forKey:@"group_properties"];
        [event setValue:[NSNumber numberWithLongLong:outOfSession ? -1 : self->_sessionId] forKey:@"session_id"];
        [event setValue:timestamp forKey:@"timestamp"];

        [self annotateEvent:event];

        // convert event dictionary to JSON String
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[DDUtils makeJSONSerializable:event] options:0 error:&error];
        if (error != nil) {
            DATADIVE_ERROR(@"ERROR: could not JSONSerialize event type %@: %@", eventType, error);
            return;
        }
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        if ([DDUtils isEmptyString:jsonString]) {
            DATADIVE_ERROR(@"ERROR: JSONSerializing event type %@ resulted in an NULL string", eventType);
            return;
        }
        if ([eventType isEqualToString:DD_IDENTIFY_EVENT] || [eventType isEqualToString:DD_GROUP_IDENTIFY_EVENT]) {
            (void) [self.dbHelper addIdentify:jsonString];
        } else {
            (void) [self.dbHelper addEvent:jsonString];
        }

        DATADIVE_LOG(@"Logged %@ Event", event[@"event_type"]);

        [self truncateEventQueues];

        int eventCount = [self.dbHelper getTotalEventCount]; // refetch since events may have been deleted
        if ((eventCount % self.eventUploadThreshold) == 0 && eventCount >= self.eventUploadThreshold) {
            [self uploadEvents];
        } else {
            [self uploadEventsWithDelay:self.eventUploadPeriodSeconds];
        }
    }];
}

- (void)truncateEventQueues {
    int numEventsToRemove = MIN(MAX(1, self.eventMaxCount/10), kDDEventRemoveBatchSize);
    int eventCount = [self.dbHelper getEventCount];
    if (eventCount > self.eventMaxCount) {
        [self.dbHelper removeEvents:([self.dbHelper getNthEventId:numEventsToRemove])];
    }
    int identifyCount = [self.dbHelper getIdentifyCount];
    if (identifyCount > self.eventMaxCount) {
        [self.dbHelper removeIdentifys:([self.dbHelper getNthIdentifyId:numEventsToRemove])];
    }
}

- (void)annotateEvent:(NSMutableDictionary *)event {
    [event setValue:self.userId forKey:@"user_id"];
    [event setValue:self.deviceId forKey:@"device_id"];
    if ([_appliedTrackingOptions shouldTrackPlatform]) {
        [event setValue:kDDPlatform forKey:@"platform"];
    }
    if ([_appliedTrackingOptions shouldTrackVersionName]) {
        [event setValue:_deviceInfo.appVersion forKey:@"version_name"];
    }
    if ([_appliedTrackingOptions shouldTrackOSName]) {
        [event setValue:_deviceInfo.osName forKey:@"os_name"];
    }
    if ([_appliedTrackingOptions shouldTrackOSVersion]) {
        [event setValue:_deviceInfo.osVersion forKey:@"os_version"];
    }
    if ([_appliedTrackingOptions shouldTrackDeviceModel]) {
        [event setValue:_deviceInfo.model forKey:@"device_model"];
    }
    if ([_appliedTrackingOptions shouldTrackDeviceManufacturer]) {
        [event setValue:_deviceInfo.manufacturer forKey:@"device_manufacturer"];
    }
    if ([_appliedTrackingOptions shouldTrackCarrier]) {
        [event setValue:_deviceInfo.carrier forKey:@"carrier"];
    }
    if ([_appliedTrackingOptions shouldTrackCountry]) {
        [event setValue:_deviceInfo.country forKey:@"country"];
    }
    if ([_appliedTrackingOptions shouldTrackLanguage]) {
        [event setValue:_deviceInfo.language forKey:@"language"];
    }
    NSDictionary *library = @{
        @"name": self.libraryName == nil ? kDDUnknownLibrary : self.libraryName,
        @"version": self.libraryVersion == nil ? kDDUnknownVersion : self.libraryVersion
    };
    [event setValue:library forKey:@"library"];
    [event setValue:[DDUtils generateUUID] forKey:@"uuid"];
    [event setValue:[NSNumber numberWithLongLong:[self getNextSequenceNumber]] forKey:@"sequence_number"];

    NSMutableDictionary *apiProperties = [event valueForKey:@"api_properties"];

    if ([_appliedTrackingOptions shouldTrackIDFA]) {
        NSString* advertiserID = [self getAdSupportID];
        if (advertiserID != nil) {
            [apiProperties setValue:advertiserID forKey:@"ios_idfa"];
        }
    }
    NSString *vendorID = _deviceInfo.vendorID;
    if ([_appliedTrackingOptions shouldTrackIDFV] && vendorID) {
        [apiProperties setValue:vendorID forKey:@"ios_idfv"];
    }

    if ([_appliedTrackingOptions shouldTrackLatLng] && self.locationInfoBlock != nil) {
        NSDictionary *location = self.locationInfoBlock();
        if (location != nil) {
            [apiProperties setValue:location forKey:@"location"];
        }
    }

    if (self->_apiPropertiesTrackingOptions.count > 0) {
        [apiProperties setValue:self->_apiPropertiesTrackingOptions forKey:@"tracking_options"];
    }
}

#pragma mark - logRevenue

// amount is a double in units of dollars
// ex. $3.99 would be passed as [NSNumber numberWithDouble:3.99]
- (void)logRevenue:(NSNumber *)amount
{
    [self logRevenue:nil quantity:1 price:amount];
}

- (void)logRevenue:(NSString *)productIdentifier quantity:(NSInteger) quantity price:(NSNumber *)price
{
    [self logRevenue:productIdentifier quantity:quantity price:price receipt:nil];
}

- (void)logRevenue:(NSString *)productIdentifier quantity:(NSInteger) quantity price:(NSNumber *)price receipt:(NSData *)receipt
{
    if (self.apiKey == nil) {
        DATADIVE_ERROR(@"ERROR: apiKey cannot be nil or empty, set apiKey with initializeApiKey: before calling logRevenue:");
        return;
    }
    if (![self isArgument:price validType:[NSNumber class] methodName:@"logRevenue:"]) {
        return;
    }
    NSDictionary *apiProperties = [NSMutableDictionary dictionary];
    [apiProperties setValue:kDDRevenueEvent forKey:@"special"];
    [apiProperties setValue:productIdentifier forKey:@"productId"];
    [apiProperties setValue:[NSNumber numberWithInteger:quantity] forKey:@"quantity"];
    [apiProperties setValue:price forKey:@"price"];

    if ([receipt respondsToSelector:@selector(base64EncodedStringWithOptions:)]) {
        [apiProperties setValue:[receipt base64EncodedStringWithOptions:0] forKey:@"receipt"];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
        [apiProperties setValue:[receipt base64Encoding] forKey:@"receipt"];
#pragma clang diagnostic pop
    }

    [self logEvent:kDDRevenueEvent withEventProperties:nil withApiProperties:apiProperties withUserProperties:nil withGroups:nil withGroupProperties:nil withTimestamp:nil outOfSession:NO];
}

- (void)logRevenueV2:(DDRevenue *)revenue {
    if (self.apiKey == nil) {
        DATADIVE_ERROR(@"ERROR: apiKey cannot be nil or empty, set apiKey with initializeApiKey: before calling logRevenueV2");
        return;
    }
    if (revenue == nil || ![revenue isValidRevenue]) {
        return;
    }

    [self logEvent:kDDRevenueEvent withEventProperties:[revenue toNSDictionary]];
}

#pragma mark - Upload events

- (void)uploadEventsWithDelay:(int)delay {
    if (!_updateScheduled) {
        _updateScheduled = YES;
        __block __weak Datadive *weakSelf = self;
        [_backgroundQueue addOperationWithBlock:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf performSelector:@selector(uploadEventsInBackground) withObject:nil afterDelay:delay];
            });
        }];
    }
}

- (void)uploadEventsInBackground {
    _updateScheduled = NO;
    [self uploadEvents];
}

- (void)uploadEvents {
    int limit = _backoffUpload ? _backoffUploadBatchSize : self.eventUploadMaxBatchSize;
    [self uploadEventsWithLimit:limit];
}

- (void)uploadEventsWithLimit:(int)limit {
    if (self.apiKey == nil) {
        DATADIVE_ERROR(@"ERROR: apiKey cannot be nil or empty, set apiKey with initializeApiKey: before calling uploadEvents:");
        return;
    }

    @synchronized (self) {
        if (_updatingCurrently) {
            return;
        }
        _updatingCurrently = YES;
    }
    
    [self runOnBackgroundQueue:^{

        // Don't communicate with the server if the user has opted out.
        if ([self optOut] || self->_offline) {
            self->_updatingCurrently = NO;
            [self endBackgroundTaskIfNeeded];
            return;
        }

        long eventCount = [self.dbHelper getTotalEventCount];
        long numEvents = limit > 0 ? fminl(eventCount, limit) : eventCount;
        if (numEvents == 0) {
            self->_updatingCurrently = NO;
            [self endBackgroundTaskIfNeeded];
            return;
        }
        NSMutableArray *events = [self.dbHelper getEvents:-1 limit:numEvents];
        NSMutableArray *identifys = [self.dbHelper getIdentifys:-1 limit:numEvents];
        NSDictionary *merged = [self mergeEventsAndIdentifys:events identifys:identifys numEvents:numEvents];

        NSMutableArray *uploadEvents = [merged objectForKey:EVENTS];
        long long maxEventId = [[merged objectForKey:MAX_EVENT_ID] longLongValue];
        long long maxIdentifyId = [[merged objectForKey:MAX_IDENTIFY_ID] longLongValue];

        NSError *error = nil;
        NSData *eventsDataLocal = nil;
        eventsDataLocal = [NSJSONSerialization dataWithJSONObject:uploadEvents options:0 error:&error];
        if (error != nil) {
            DATADIVE_ERROR(@"ERROR: NSJSONSerialization error: %@", error);
            self->_updatingCurrently = NO;
            [self endBackgroundTaskIfNeeded];
            return;
        }

        NSString *eventsString = [[NSString alloc] initWithData:eventsDataLocal encoding:NSUTF8StringEncoding];
        if ([DDUtils isEmptyString:eventsString]) {
            DATADIVE_ERROR(@"ERROR: JSONSerialization of event upload data resulted in a NULL string");
            self->_updatingCurrently = NO;
            [self endBackgroundTaskIfNeeded];
            return;
        }

        [self makeEventUploadPostRequest:self->_serverUrl events:eventsString numEvents:numEvents maxEventId:maxEventId maxIdentifyId:maxIdentifyId];
    }];
}

- (void)refreshDynamicConfig {
    if (self.useDynamicConfig) {
        __weak typeof(self) weakSelf = self;
        [[DDConfigManager sharedInstance] refresh:^{
            __strong typeof(self) strongSelf = weakSelf;
            strongSelf->_serverUrl = [DDConfigManager sharedInstance].ingestionEndpoint;
        }];
    }
}

- (long long)getNextSequenceNumber {
    NSNumber *sequenceNumberFromDB = [self.dbHelper getLongValue:SEQUENCE_NUMBER];
    long long sequenceNumber = 0;
    if (sequenceNumberFromDB != nil) {
        sequenceNumber = [sequenceNumberFromDB longLongValue];
    }

    sequenceNumber++;
    [self.dbHelper insertOrReplaceKeyLongValue:SEQUENCE_NUMBER value:[NSNumber numberWithLongLong:sequenceNumber]];

    return sequenceNumber;
}

- (NSDictionary *)mergeEventsAndIdentifys:(NSMutableArray *)events identifys:(NSMutableArray *)identifys numEvents:(long)numEvents {
    NSMutableArray *mergedEvents = [[NSMutableArray alloc] init];
    long long maxEventId = -1;
    long long maxIdentifyId = -1;

    // NSArrays actually have O(1) performance for push/pop
    while ([mergedEvents count] < numEvents) {
        NSDictionary *event = nil;
        NSDictionary *identify = nil;

        BOOL noIdentifies = [identifys count] == 0;
        BOOL noEvents = [events count] == 0;

        // case 0: no events or identifies, should not happen - means less events / identifies than expected
        if (noEvents && noIdentifies) {
            break;
        }

        // case 1: no identifys grab from events
        if (noIdentifies) {
            event = events[0];
            [events removeObjectAtIndex:0];
            maxEventId = [[event objectForKey:@"event_id"] longValue];

        // case 2: no events grab from identifys
        } else if (noEvents) {
            identify = identifys[0];
            [identifys removeObjectAtIndex:0];
            maxIdentifyId = [[identify objectForKey:@"event_id"] longValue];

        // case 3: need to compare sequence numbers
        } else {
            // events logged before v3.2.0 won't have sequeunce number, put those first
            event = events[0];
            identify = identifys[0];
            if ([event objectForKey:SEQUENCE_NUMBER] == nil ||
                    ([[event objectForKey:SEQUENCE_NUMBER] longLongValue] <
                     [[identify objectForKey:SEQUENCE_NUMBER] longLongValue])) {
                [events removeObjectAtIndex:0];
                maxEventId = [[event objectForKey:EVENT_ID] longValue];
                identify = nil;
            } else {
                [identifys removeObjectAtIndex:0];
                maxIdentifyId = [[identify objectForKey:EVENT_ID] longValue];
                event = nil;
            }
        }

        [mergedEvents addObject:event != nil ? event : identify];
    }

    NSDictionary *results = [[NSDictionary alloc] initWithObjectsAndKeys:mergedEvents, EVENTS, [NSNumber numberWithLongLong:maxEventId], MAX_EVENT_ID, [NSNumber numberWithLongLong:maxIdentifyId], MAX_IDENTIFY_ID, nil];
    return results;
}

- (void)makeEventUploadPostRequest:(NSString *)url events:(NSString *)events numEvents:(long)numEvents maxEventId:(long long)maxEventId maxIdentifyId:(long long)maxIdentifyId {
    NSMutableURLRequest *request =[NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setTimeoutInterval:60.0];

    NSString *apiVersionString = [[NSNumber numberWithInt:kDDApiVersion] stringValue];

    NSMutableData *postData = [[NSMutableData alloc] init];
    [postData appendData:[@"v=" dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[apiVersionString dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[@"&client=" dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[self.apiKey dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[@"&e=" dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[[self urlEncodeString:events] dataUsingEncoding:NSUTF8StringEncoding]];

    // Add timestamp of upload
    [postData appendData:[@"&upload_time=" dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *timestampString = [[NSNumber numberWithLongLong:[[self currentTime] timeIntervalSince1970] * 1000] stringValue];
    [postData appendData:[timestampString dataUsingEncoding:NSUTF8StringEncoding]];

    // Add checksum
    [postData appendData:[@"&checksum=" dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *checksumData = [NSString stringWithFormat:@"%@%@%@%@", apiVersionString, self.apiKey, events, timestampString];
    NSString *checksum = [self md5HexDigest:checksumData];
    [postData appendData:[checksum dataUsingEncoding:NSUTF8StringEncoding]];

    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[postData length]] forHTTPHeaderField:@"Content-Length"];

    if (_token != nil) {
        NSString *auth = [NSString stringWithFormat:@"Bearer %@", _token];
        DATADIVE_LOG(@"Attaching bearer %@", _token);
        [request setValue:auth forHTTPHeaderField:@"Authorization"];
    }

    [request setHTTPBody:postData];
    DATADIVE_LOG(@"Events: %@", events);

    // If pinning is enabled, use the DDURLSession that handles it.
#if DATADIVE_SSL_PINNING
    id session = (self.sslPinningEnabled ? [DDURLSession class] : [NSURLSession class]);
#else
    id session = [NSURLSession class];
#endif
    [[[session sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        BOOL uploadSuccessful = NO;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (response != nil) {
            if ([httpResponse statusCode] == 200) {
                NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if ([result isEqualToString:@"success"]) {
                    // success, remove existing events from dictionary
                    uploadSuccessful = YES;
                    if (maxEventId >= 0) {
                        (void) [self.dbHelper removeEvents:maxEventId];
                    }
                    if (maxIdentifyId >= 0) {
                        (void) [self.dbHelper removeIdentifys:maxIdentifyId];
                    }
                } else if ([result isEqualToString:@"invalid_api_key"]) {
                    DATADIVE_ERROR(@"ERROR: Invalid API Key, make sure your API key is correct in initializeApiKey:");
                } else if ([result isEqualToString:@"bad_checksum"]) {
                    DATADIVE_ERROR(@"ERROR: Bad checksum, post request was mangled in transit, will attempt to reupload later");
                } else if ([result isEqualToString:@"request_db_write_failed"]) {
                    DATADIVE_ERROR(@"ERROR: Couldn't write to request database on server, will attempt to reupload later");
                } else {
                    DATADIVE_ERROR(@"ERROR: %@, will attempt to reupload later", result);
                }
            } else if ([httpResponse statusCode] == 413) {
                // If blocked by one massive event, drop it
                if (numEvents == 1) {
                    if (maxEventId >= 0) {
                        (void) [self.dbHelper removeEvent:maxEventId];
                    }
                    if (maxIdentifyId >= 0) {
                        (void) [self.dbHelper removeIdentifys:maxIdentifyId];
                    }
                }

                // server complained about length of request, backoff and try again
                self->_backoffUpload = YES;
                long newNumEvents = MIN(numEvents, self->_backoffUploadBatchSize);
                self->_backoffUploadBatchSize = MAX((int)ceilf(newNumEvents / 2.0f), 1);
                DATADIVE_LOG(@"Request too large, will decrease size and attempt to reupload");
                self->_updatingCurrently = NO;
                [self uploadEventsWithLimit:self->_backoffUploadBatchSize];

            } else {
                DATADIVE_ERROR(@"ERROR: Connection response received:%ld, %@", (long)[httpResponse statusCode],
                    [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            }
        } else if (error != nil) {
            if ([error code] == -1009) {
                DATADIVE_LOG(@"No internet connection (not connected to internet), unable to upload events");
            } else if ([error code] == -1003) {
                DATADIVE_LOG(@"No internet connection (hostname not found), unable to upload events");
            } else if ([error code] == -1001) {
                DATADIVE_LOG(@"No internet connection (request timed out), unable to upload events");
            } else {
                DATADIVE_ERROR(@"ERROR: Connection error:%@", error);
            }
        } else {
            DATADIVE_ERROR(@"ERROR: response empty, error empty for NSURLConnection");
        }

        self->_updatingCurrently = NO;

        if (uploadSuccessful && [self.dbHelper getEventCount] > self.eventUploadThreshold) {
            int limit = self->_backoffUpload ? self->_backoffUploadBatchSize : 0;
            [self uploadEventsWithLimit:limit];
    #if !TARGET_OS_OSX
        } else if (self->_uploadTaskID != UIBackgroundTaskInvalid) {
            if (uploadSuccessful) {
                self->_backoffUpload = NO;
                self->_backoffUploadBatchSize = self.eventUploadMaxBatchSize;
            }

            // Upload finished, allow background task to be ended
            [self endBackgroundTaskIfNeeded];
        }
    #else
        }
    #endif
    }] resume];
}

#pragma mark - application lifecycle methods

- (void)enterForeground {
#if !TARGET_OS_OSX
    UIApplication *app = [DDUtils getSharedApplication];
    if (app == nil) {
        return;
    }
#endif

    NSNumber *now = [NSNumber numberWithLongLong:[[self currentTime] timeIntervalSince1970] * 1000];

#if !TARGET_OS_OSX
    // Stop uploading
    [self endBackgroundTaskIfNeeded];
#endif
    [self runOnBackgroundQueue:^{
        // Fetch the data ingestion endpoint based on current device's geo location.
        
        [self refreshDynamicConfig];
        [self startOrContinueSessionNSNumber:now];
        self->_inForeground = YES;
        [self uploadEvents];
    }];
}

- (void)enterBackground {
#if !TARGET_OS_OSX
    UIApplication *app = [DDUtils getSharedApplication];
    if (app == nil) {
        return;
    }
#endif

    NSNumber *now = [NSNumber numberWithLongLong:[[self currentTime] timeIntervalSince1970] * 1000];

#if !TARGET_OS_OSX
    // Stop uploading
    [self endBackgroundTaskIfNeeded];
    _uploadTaskID = [app beginBackgroundTaskWithExpirationHandler:^{
        //Took too long, manually stop
        [self endBackgroundTaskIfNeeded];
    }];
#endif

    [self runOnBackgroundQueue:^{
        self->_inForeground = NO;
        [self refreshSessionTime:now];
        [self uploadEventsWithLimit:0];
    }];
}

- (void)endBackgroundTaskIfNeeded {
#if !TARGET_OS_OSX
    if (_uploadTaskID != UIBackgroundTaskInvalid) {
        UIApplication *app = [DDUtils getSharedApplication];
        if (app == nil) {
            return;
        }

        [app endBackgroundTask:_uploadTaskID];
        self->_uploadTaskID = UIBackgroundTaskInvalid;
    }
#endif
}

#pragma mark - Sessions

/**
 * Creates a new session if we are in the background and
 * the current session is expired or if there is no current session ID].
 * Otherwise extends the session.
 *
 * Returns YES if a new session was created.
 */
- (BOOL)startOrContinueSessionNSNumber:(NSNumber *)timestamp {
    if (!_inForeground) {
        if ([self inSession]) {
            if ([self isWithinMinTimeBetweenSessions:timestamp]) {
                [self refreshSessionTime:timestamp];
                return NO;
            }
            [self startNewSession:timestamp];
            return YES;
        }
        // no current session, check for previous session
        if ([self isWithinMinTimeBetweenSessions:timestamp]) {
            // extract session id
            long long previousSessionId = [self previousSessionId];
            if (previousSessionId == -1) {
                [self startNewSession:timestamp];
                return YES;
            }
            // extend previous session
            [self setSessionId:previousSessionId];
            [self refreshSessionTime:timestamp];
            return NO;
        } else {
            [self startNewSession:timestamp];
            return YES;
        }
    }
    // not creating a session means we should continue the session
    [self refreshSessionTime:timestamp];
    return NO;
}

- (BOOL)startOrContinueSession:(long long)timestamp {
    NSNumber *timestampNumber = [NSNumber numberWithLongLong:timestamp];
    return [self startOrContinueSessionNSNumber:timestampNumber];
}

- (void)startNewSession:(NSNumber *)timestamp {
    if (_trackingSessionEvents) {
        [self sendSessionEvent:kDDSessionEndEvent];
    }
    [self setSessionId:[timestamp longLongValue]];
    [self refreshSessionTime:timestamp];
    if (_trackingSessionEvents) {
        [self sendSessionEvent:kDDSessionStartEvent];
    }
}

- (void)sendSessionEvent:(NSString *)sessionEvent {
    if (self.apiKey == nil) {
        DATADIVE_ERROR(@"ERROR: apiKey cannot be nil or empty, set apiKey with initializeApiKey: before sending session event");
        return;
    }

    if (![self inSession]) {
        return;
    }

    NSMutableDictionary *apiProperties = [NSMutableDictionary dictionary];
    [apiProperties setValue:sessionEvent forKey:@"special"];
    NSNumber *timestamp = [self lastEventTime];
    [self logEvent:sessionEvent withEventProperties:nil withApiProperties:apiProperties withUserProperties:nil withGroups:nil withGroupProperties:nil withTimestamp:timestamp outOfSession:NO];
}

- (BOOL)inSession {
    return _sessionId >= 0;
}

- (BOOL)isWithinMinTimeBetweenSessions:(NSNumber *)timestamp {
    NSNumber *previousSessionTime = [self lastEventTime];
    long long timeDelta = [timestamp longLongValue] - [previousSessionTime longLongValue];

    return timeDelta < self.minTimeBetweenSessionsMillis;
}

/**
 * Sets the session ID in memory and persists it to disk.
 */
- (void)setSessionId:(long long)timestamp {
    _sessionId = timestamp;
    [self setPreviousSessionId:_sessionId];
}

/**
 * Update the session timer if there's a running session.
 */
- (void)refreshSessionTime:(NSNumber *)timestamp {
    if (![self inSession]) {
        return;
    }
    [self setLastEventTime:timestamp];
}

- (void)setPreviousSessionId:(long long) previousSessionId {
    NSNumber *value = [NSNumber numberWithLongLong:previousSessionId];
    (void) [self.dbHelper insertOrReplaceKeyLongValue:PREVIOUS_SESSION_ID value:value];
}

- (long long)previousSessionId {
    NSNumber *previousSessionId = [self.dbHelper getLongValue:PREVIOUS_SESSION_ID];
    if (previousSessionId == nil) {
        return -1;
    }
    return [previousSessionId longLongValue];
}

- (void)setLastEventTime:(NSNumber *)timestamp {
    (void) [self.dbHelper insertOrReplaceKeyLongValue:PREVIOUS_SESSION_TIME value:timestamp];
}

- (NSNumber*)lastEventTime {
    return [self.dbHelper getLongValue:PREVIOUS_SESSION_TIME];
}

- (void)identify:(DDIdentify *)identify {
    [self identify:identify outOfSession:NO];
}

- (void)identify:(DDIdentify *)identify outOfSession:(BOOL) outOfSession {
    if (identify == nil || [identify.userPropertyOperations count] == 0) {
        return;
    }
    [self logEvent:DD_IDENTIFY_EVENT withEventProperties:nil withApiProperties:nil withUserProperties:identify.userPropertyOperations withGroups:nil withGroupProperties:nil withTimestamp:nil outOfSession:outOfSession];
}

- (void)groupIdentifyWithGroupType:(NSString *)groupType groupName:(NSObject *)groupName groupIdentify:(DDIdentify *)groupIdentify {
    [self groupIdentifyWithGroupType:groupType groupName:groupName groupIdentify:groupIdentify outOfSession:NO];
}

- (void)groupIdentifyWithGroupType:(NSString *)groupType groupName:(NSObject *)groupName groupIdentify:(DDIdentify *)groupIdentify outOfSession:(BOOL)outOfSession {
    if (groupIdentify == nil || [groupIdentify.userPropertyOperations count] == 0) {
        return;
    }

    if (groupType == nil || [groupType isEqualToString:@""]) {
        DATADIVE_LOG(@"ERROR: groupType cannot be nil or an empty string");
        return;
    }

    NSMutableDictionary *groups = [NSMutableDictionary dictionaryWithObjectsAndKeys:groupName, groupType, nil];
    [self logEvent:DD_GROUP_IDENTIFY_EVENT withEventProperties:nil withApiProperties:nil withUserProperties:nil withGroups:groups withGroupProperties:groupIdentify.userPropertyOperations withTimestamp:nil outOfSession:outOfSession];
}

#pragma mark - configurations

- (void)setUserProperties:(NSDictionary *)userProperties {
    if (userProperties == nil || ![self isArgument:userProperties validType:[NSDictionary class] methodName:@"setUserProperties:"] || [userProperties count] == 0) {
        return;
    }

    NSDictionary *copy = [userProperties copy];
    [self runOnBackgroundQueue:^{
        // sanitize and truncate user properties before turning into identify
        NSDictionary *sanitized = [self truncate:copy];
        if ([sanitized count] == 0) {
            return;
        }

        DDIdentify *identify = [DDIdentify identify];
        for (NSString *key in copy) {
            NSObject *value = [copy objectForKey:key];
            [identify set:key value:value];
        }
        [self identify:identify];
    }];
}

// maintain for legacy
// replace argument is deprecated. In earlier versions of this SDK, this replaced the in-memory userProperties dictionary with the input, but now userProperties are no longer stored in memory.
- (void)setUserProperties:(NSDictionary *)userProperties replace:(BOOL)replace {
    [self setUserProperties:userProperties];
}

- (void)clearUserProperties {
    DDIdentify *identify = [[DDIdentify identify] clearAll];
    [self identify:identify];
}

- (void)setGroup:(NSString *)groupType groupName:(NSObject *)groupName {
    if (self.apiKey == nil) {
        DATADIVE_ERROR(@"ERROR: apiKey cannot be nil or empty, set apiKey with initializeApiKey: before calling setGroupType");
        return;
    }

    if (groupType == nil || [groupType isEqualToString:@""]) {
        DATADIVE_LOG(@"ERROR: groupType cannot be nil or an empty string");
        return;
    }

    NSMutableDictionary *groups = [NSMutableDictionary dictionaryWithObjectsAndKeys:groupName, groupType, nil];
    DDIdentify *identify = [[DDIdentify identify] set:groupType value:groupName];
    [self logEvent:DD_IDENTIFY_EVENT withEventProperties:nil withApiProperties:nil withUserProperties:identify.userPropertyOperations withGroups:groups withGroupProperties:nil withTimestamp:nil outOfSession:NO];

}

- (void)setTrackingOptions:(DDTrackingOptions *)options {
    if (![self isArgument:options validType:[DDTrackingOptions class] methodName:@"setTrackingOptions:"]) {
        return;
    }

    _inputTrackingOptions = options;
    _appliedTrackingOptions = [DDTrackingOptions copyOf:options];
    
    if (_coppaControlEnabled) {
        [_appliedTrackingOptions mergeIn:[DDTrackingOptions forCoppaControl]];
    }

    self->_apiPropertiesTrackingOptions = [NSDictionary dictionaryWithDictionary:[options getApiPropertiesTrackingOption]];
}

- (void)enableCoppaControl {
    _coppaControlEnabled = YES;
    [_appliedTrackingOptions mergeIn:[DDTrackingOptions forCoppaControl]];
    _apiPropertiesTrackingOptions = [_appliedTrackingOptions getApiPropertiesTrackingOption];
}

- (void)disableCoppaControl {
    _coppaControlEnabled = NO;
    // Restore it to original input.
    _appliedTrackingOptions = [DDTrackingOptions copyOf:_inputTrackingOptions];
    _apiPropertiesTrackingOptions = [_appliedTrackingOptions getApiPropertiesTrackingOption];
}

- (void)setUserId:(NSString *)userId {
    [self setUserId:userId startNewSession:NO];
}

- (void)setUserId:(NSString *)userId startNewSession:(BOOL)startNewSession {
    if (!(userId == nil || [self isArgument:userId validType:[NSString class] methodName:@"setUserId:"])) {
        return;
    }

    [self runOnBackgroundQueue:^{
        if (startNewSession && self->_trackingSessionEvents) {
            [self sendSessionEvent:kDDSessionEndEvent];
        }

        self->_userId = userId;
        [self.dbHelper insertOrReplaceKeyValue:USER_ID value:self.userId];

        if (startNewSession) {
            NSNumber *timestamp = [NSNumber numberWithLongLong:[[self currentTime] timeIntervalSince1970] * 1000];
            [self setSessionId:[timestamp longLongValue]];
            [self refreshSessionTime:timestamp];
            if (self->_trackingSessionEvents) {
                [self sendSessionEvent:kDDSessionStartEvent];
            }
        }
    }];
}

- (void)setOptOut:(BOOL)enabled {
    [self runOnBackgroundQueue:^{
        NSNumber *value = [NSNumber numberWithBool:enabled];
        (void) [self.dbHelper insertOrReplaceKeyLongValue:OPT_OUT value:value];
    }];
}

- (void)setOffline:(BOOL)offline {
    _offline = offline;

    if (!_offline) {
        [self uploadEvents];
    }
}

- (void)setServerUrl:(NSString *)serverUrl {
    if (!(serverUrl == nil || [self isArgument:serverUrl validType:[NSString class] methodName:@"setServerUrl:"])) {
        return;
    }

    self->_serverUrl = serverUrl;
}

- (void)setBearerToken:(NSString *)token {
    if (!(token == nil || [self isArgument:token validType:[NSString class] methodName:@"setBearerToken:"])) {
        return;
    }

    self->_token = token;
}

- (void)setEventUploadMaxBatchSize:(int)eventUploadMaxBatchSize {
    _eventUploadMaxBatchSize = eventUploadMaxBatchSize;
    _backoffUploadBatchSize = eventUploadMaxBatchSize;
}

- (BOOL)optOut {
    return [[self.dbHelper getLongValue:OPT_OUT] boolValue];
}

- (void)setDeviceId:(NSString *)deviceId {
    if (![self isValidDeviceId:deviceId]) {
        return;
    }

    [self runOnBackgroundQueue:^{
        self->_deviceId = deviceId;
        [self.dbHelper insertOrReplaceKeyValue:DEVICE_ID value:deviceId];
    }];
}

- (void)regenerateDeviceId {
    [self runOnBackgroundQueue:^{
        [self setDeviceId:[DDDeviceInfo generateUUID]];
    }];
}

- (void)useAdvertisingIdForDeviceId {
    _useAdvertisingIdForDeviceId = YES;
}

#pragma mark - Getters for device data
- (NSString *)getAdSupportID {
    NSString *result = nil;
    if (self.adSupportBlock != nil && [_appliedTrackingOptions shouldTrackIDFA]) {
        result = self.adSupportBlock();
    }
    // IDFA access was denied or still in progress.
    if ([result isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
        result = nil;
    }
    return result;
}

- (NSString *)getDeviceId {
    return self.deviceId;
}

- (long long)getSessionId {
    return _sessionId;
}

- (NSString *)initializeDeviceId {
    if (self.deviceId == nil) {
        self.deviceId = [self.dbHelper getValue:DEVICE_ID];
        if (![self isValidDeviceId:self.deviceId]) {
            self.deviceId = [self _getDeviceId];
            [self.dbHelper insertOrReplaceKeyValue:DEVICE_ID value:self.deviceId];
        }
    }
    return self.deviceId;
}

- (NSString *)_getDeviceId {
    NSString *deviceId = nil;
    if (_useAdvertisingIdForDeviceId && [_appliedTrackingOptions shouldTrackIDFA]) {
        deviceId = [self getAdSupportID];
    }

    // return identifierForVendor
    if ([_appliedTrackingOptions shouldTrackIDFV] && !deviceId) {
        deviceId = _deviceInfo.vendorID;
    }

    if (!deviceId) {
        // Otherwise generate random ID
        deviceId = [DDDeviceInfo generateUUID];
    }
    return [[NSString alloc] initWithString:deviceId];
}

- (BOOL)isValidDeviceId:(NSString *)deviceId {
    if (deviceId == nil ||
        ![self isArgument:deviceId validType:[NSString class] methodName:@"isValidDeviceId"] ||
        [deviceId isEqualToString:@"e3f5536a141811db40efd6400f1d0a4e"] ||
        [deviceId isEqualToString:@"04bab7ee75b9a58d39b8dc54e8851084"]) {
        return NO;
    }
    return YES;
}

- (NSDictionary *)replaceWithEmptyJSON:(NSDictionary *)dictionary {
    return dictionary == nil ? [NSMutableDictionary dictionary] : dictionary;
}

- (id) truncate:(id)obj {
    if ([obj isKindOfClass:[NSString class]]) {
        obj = (NSString *)obj;
        if ([obj length] > kDDMaxStringLength) {
            obj = [obj substringWithRange:[obj rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, kDDMaxStringLength)]];
        }
    } else if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *arr = [NSMutableArray array];
        id objCopy = [obj copy];
        for (id i in objCopy) {
            [arr addObject:[self truncate:i]];
        }
        obj = [NSArray arrayWithArray:arr];
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        // if too many properties, ignore
        if ([(NSDictionary *)obj count] > kDDMaxPropertyKeys) {
            DATADIVE_LOG(@"WARNING: too many properties (more than 1000), ignoring");
            return [NSDictionary dictionary];
        }

        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        id objCopy = [obj copy];
        for (id key in objCopy) {
            NSString *coercedKey;
            if (![key isKindOfClass:[NSString class]]) {
                coercedKey = [key description];
                DATADIVE_LOG(@"WARNING: Non-string property key, received %@, coercing to %@", [key class], coercedKey);
            } else {
                coercedKey = key;
            }
            // do not truncate revenue receipt field
            if ([coercedKey isEqualToString:DD_REVENUE_RECEIPT]) {
                dict[coercedKey] = objCopy[key];
            } else {
                dict[coercedKey] = [self truncate:objCopy[key]];
            }
        }
        obj = [NSDictionary dictionaryWithDictionary:dict];
    }
    return obj;
}

- (BOOL)isArgument:(id)argument validType:(Class)class methodName:(NSString *)methodName {
    if ([argument isKindOfClass:class]) {
        return YES;
    } else {
        DATADIVE_ERROR(@"ERROR: Invalid type argument to method %@, expected %@, received %@, ", methodName, class, [argument class]);
        return NO;
    }
}

- (NSString *)md5HexDigest:(NSString *)input {
    const char *str = [input UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG) strlen(str), result);

    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
    for(int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x",result[i]];
    }
    return ret;
}

- (NSString *)urlEncodeString:(NSString *)string {
    NSCharacterSet * allowedCharacters = [[NSCharacterSet characterSetWithCharactersInString:@":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"] invertedSet];
    return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
}

- (NSDate *)currentTime {
    return [NSDate date];
}

- (void)printEventsCount {
    DATADIVE_LOG(@"Events count:%ld", (long) [self.dbHelper getEventCount]);
}

#pragma mark - Compatibility

/**
 * Move all preference data from the legacy name to the new, static name if needed.
 *
 * Data used to be in the NSCachesDirectory, which would sometimes be cleared unexpectedly,
 * resulting in data loss. We move the data from NSCachesDirectory to the current
 * location in NSLibraryDirectory.
 *
 */
- (BOOL)upgradePrefs {
    // Copy any old data files to new file paths
    NSString *oldEventsDataDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *oldPropertyListPath = [oldEventsDataDirectory stringByAppendingPathComponent:@"ai.datadive.plist"];
    NSString *oldEventsDataPath = [oldEventsDataDirectory stringByAppendingPathComponent:@"ai.datadive.archiveDict"];
    BOOL success = [self moveFileIfNotExists:oldPropertyListPath to:_propertyListPath];
    success &= [self moveFileIfNotExists:oldEventsDataPath to:_eventsDataPath];
    return success;
}

#pragma mark - Filesystem

- (BOOL)savePropertyList {
    @synchronized (_propertyList) {
        BOOL success = [self serializePList:_propertyList toFile:_propertyListPath];
        if (!success) {
            DATADIVE_ERROR(@"Error: Unable to save propertyList to file");
        }
        return success;
    }
}

- (id)deserializePList:(NSString *)path {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSData *pListData = [[NSFileManager defaultManager] contentsAtPath:path];
        if (pListData != nil) {
            NSError *error = nil;
            NSMutableDictionary *pList = (NSMutableDictionary *)[NSPropertyListSerialization
                                                                   propertyListWithData:pListData
                                                                   options:NSPropertyListMutableContainersAndLeaves
                                                                   format:NULL error:&error];
            if (error == nil) {
                return pList;
            } else {
                DATADIVE_ERROR(@"ERROR: propertyList deserialization error:%@", error);
                error = nil;
                [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
                if (error != nil) {
                    DATADIVE_ERROR(@"ERROR: Can't remove corrupt propertyList file:%@", error);
                }
            }
        }
    }
    return nil;
}

- (BOOL)serializePList:(id)data toFile:(NSString *)path {
    NSError *error = nil;
    NSData *propertyListData = [NSPropertyListSerialization
                                dataWithPropertyList:data
                                format:NSPropertyListXMLFormat_v1_0
                                options:0 error:&error];
    if (error == nil) {
        if (propertyListData != nil) {
            BOOL success = [propertyListData writeToFile:path atomically:YES];
            if (!success) {
                DATADIVE_ERROR(@"ERROR: Unable to save propertyList to file");
            }
            return success;
        } else {
            DATADIVE_ERROR(@"ERROR: propertyListData is nil");
        }
    } else {
        DATADIVE_ERROR(@"ERROR: Unable to serialize propertyList:%@", error);
    }
    return NO;

}

- (id)unarchive:(NSString *)path {
#if !TARGET_OS_OSX
    // unarchive using new NSKeyedUnarchiver method from iOS 9.0 that doesn't throw exceptions
    if (@available(iOS 9.0, *)) {
#else
    if (@available(macOS 10.11, *)) {
#endif
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:path]) {
            NSData *inputData = [fileManager contentsAtPath:path];
            NSError *error = nil;
            if (inputData != nil) {
                id data = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:inputData error:&error];
                if (error == nil) {
                    if (data != nil) {
                        return data;
                    } else {
                        DATADIVE_ERROR(@"ERROR: unarchived data is nil for file: %@", path);
                    }
                } else {
                    DATADIVE_ERROR(@"ERROR: Unable to unarchive file %@: %@", path, error);
                }
            } else {
                DATADIVE_ERROR(@"ERROR: File data is nil for file: %@", path);
            }

            // if reach here, then an error occured during unarchiving, delete corrupt file
            [fileManager removeItemAtPath:path error:&error];
            if (error != nil) {
                DATADIVE_ERROR(@"ERROR: Can't remove corrupt file %@: %@", path, error);
            }
        }
#if !TARGET_OS_OSX
    } else {
        DATADIVE_LOG(@"WARNING: user is using a version of iOS that is older than 9.0, skipping unarchiving of file: %@", path);
    }
#else
    }
#endif
    return nil;
}

- (BOOL)archive:(id) obj toFile:(NSString*)path {
    return [NSKeyedArchiver archiveRootObject:obj toFile:path];
}

- (BOOL)moveFileIfNotExists:(NSString *)from to:(NSString *)to {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    if (![fileManager fileExistsAtPath:to] &&
        [fileManager fileExistsAtPath:from]) {
        if ([fileManager copyItemAtPath:from toPath:to error:&error]) {
            DATADIVE_LOG(@"INFO: copied %@ to %@", from, to);
            [fileManager removeItemAtPath:from error:NULL];
        } else {
            DATADIVE_LOG(@"WARN: Copy from %@ to %@ failed: %@", from, to, error);
            return NO;
        }
    }
    return YES;
}

#pragma clang diagnostic pop
@end
