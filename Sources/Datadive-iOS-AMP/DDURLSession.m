//
//  DDURLSession.m
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

#if DATADIVE_SSL_PINNING

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

#import "DDURLSession.h"
#import "DDConstants.h"
#import "ISPCertificatePinning.h"
#import "ISPPinnedNSURLSessionDelegate.h"

@interface DDURLSession ()

@end

@implementation DDURLSession {
    NSURLSession *_sharedSession;
}

+ (DDURLSession *)sharedSession {
    static DDURLSession *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[DDURLSession alloc] init];
    });
    return _instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        [DDURLSession pinSSLCertificate:@[@"ComodoRsaDomainValidationCA"]];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _sharedSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    }
    return self;
}

+ (void)pinSSLCertificate:(NSArray *)certFilenames {
    // We pin the anchor/CA certificates
    NSMutableArray *certs = [NSMutableArray array];
    for (NSString *certFilename in certFilenames) {
        NSString *certPath =  [[NSBundle bundleForClass:[self class]] pathForResource:certFilename ofType:@"der"];
        NSData *certData = [[NSData alloc] initWithContentsOfFile:certPath];
        if (certData == nil) {
            DATADIVE_LOG(@"Failed to load a certificate");
            return;
        }
        [certs addObject:certData];
    }

    NSMutableDictionary *pins = [[NSMutableDictionary alloc] init];
    [pins setObject:certs forKey:kDDEventLogDomain];

    if (pins == nil) {
        DATADIVE_LOG(@"Failed to pin a certificate");
        return;
    }

    // Save the SSL pins so that our connection delegates automatically use them
    if ([ISPCertificatePinning setupSSLPinsUsingDictionnary:pins] != YES) {
        DATADIVE_LOG(@"Failed to pin the certificates");
        return;
    }
}

- (void)dealloc {
    [_sharedSession finishTasksAndInvalidate];
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    return [_sharedSession dataTaskWithRequest:request completionHandler:completionHandler];
}

@end

#endif
