//
// MQTTCFSocketDecoder.m
// MQTTClient.framework
//
// Copyright © 2013-2017, Christoph Krey. All rights reserved.
//

#import "MQTTCFSocketDecoder.h"
#import <FirebaseCrashlytics/FIRCrashlytics.h>
#import "MQTTLog.h"
#import "BossBasicDefine.h"

@interface MQTTCFSocketDecoder()

@end

@implementation MQTTCFSocketDecoder

- (instancetype)init {
    self = [super init];
    self.state = MQTTCFSocketDecoderStateInitializing;
    
    self.stream = nil;
    return self;
}

- (void)open {
    if (self.state == MQTTCFSocketDecoderStateInitializing) {
        (self.stream).delegate = self;
        [self.stream open];
    }
}

- (void)dealloc {
    @try {
        if (self.stream.streamStatus == NSStreamStatusOpen) {
            [self.stream close];
            [self.stream setDelegate:nil];
        }
    } @catch (NSException *exception) {
        
    } @finally {
        
    }
}

- (void)close {
    // try catch
    @try {
        //此处写可能出现崩溃的代码
        if (self.stream.streamStatus == NSStreamStatusOpen) {
            [self.stream close];
            [self.stream setDelegate:nil];
        }
    } @catch (NSException *exception) {
        //捕获到异常要执行的代码
        NSDictionary *userInfo = @{
            @"accountId": kCache.umsAccessTokenModel.accountId?:@"用户id为空",
            @"exception": exception
        };
        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                             code:-1001
                                         userInfo:userInfo];
        [[FIRCrashlytics crashlytics] recordError:error];
    } @finally {
        //不管能不能捕获到异常都会执行的方法
    }
}

- (void)stream:(NSStream *)sender handleEvent:(NSStreamEvent)eventCode {
    if (eventCode & NSStreamEventOpenCompleted) {
        DDLogVerbose(@"[MQTTCFSocketDecoder] NSStreamEventOpenCompleted");
        self.state = MQTTCFSocketDecoderStateReady;
        [self.delegate decoderDidOpen:self];
    }
    
    if (eventCode & NSStreamEventHasBytesAvailable) {
        DDLogVerbose(@"[MQTTCFSocketDecoder] NSStreamEventHasBytesAvailable");
        if (self.state == MQTTCFSocketDecoderStateInitializing) {
            self.state = MQTTCFSocketDecoderStateReady;
        }
        
        if (self.state == MQTTCFSocketDecoderStateReady) {
            NSInteger n;
            UInt8 buffer[768];
            
            n = [self.stream read:buffer maxLength:sizeof(buffer)];
            if (n == -1) {
                self.state = MQTTCFSocketDecoderStateError;
                [self.delegate decoder:self didFailWithError:nil];
            } else {
                NSData *data = [NSData dataWithBytes:buffer length:n];
                DDLogVerbose(@"[MQTTCFSocketDecoder] received (%lu)=%@...", (unsigned long)data.length,
                             [data subdataWithRange:NSMakeRange(0, MIN(256, data.length))]);
                [self.delegate decoder:self didReceiveMessage:data];
            }
        }
    }
    if (eventCode & NSStreamEventHasSpaceAvailable) {
        DDLogVerbose(@"[MQTTCFSocketDecoder] NSStreamEventHasSpaceAvailable");
    }
    
    if (eventCode & NSStreamEventEndEncountered) {
        DDLogVerbose(@"[MQTTCFSocketDecoder] NSStreamEventEndEncountered");
        self.state = MQTTCFSocketDecoderStateInitializing;
        self.error = nil;
        [self.delegate decoderdidClose:self];
    }
    
    if (eventCode & NSStreamEventErrorOccurred) {
        DDLogVerbose(@"[MQTTCFSocketDecoder] NSStreamEventErrorOccurred");
        self.state = MQTTCFSocketDecoderStateError;
        self.error = self.stream.streamError;
        [self.delegate decoder:self didFailWithError:self.error];
    }
}

@end
