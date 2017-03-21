//
//  SocketEventHandler.m
//  Spika
//
//  Created by Dmitry Rybochkin on 31.01.17.
//  Copyright © 2017 Clover Studio. All rights reserved.
//

#import "SocketEventHandler.h"

@interface SocketEventHandler ()
{
    NSString *event;
    void (^_callback)(NSArray *items, id socket);
}

@end

@implementation SocketEventHandler

+ (SocketEventHandler*) eventWithName: (NSString*) event andCallback: (void (^)(NSArray *items, id socket)) callback {
    return [[SocketEventHandler alloc] init: event andCallback: callback];
}

- (instancetype) init: (NSString*) eventName andCallback: (void (^)(NSArray *items, id socket)) callback {
    self = [super init];
    if (self) {
        event = eventName;
        _callback = callback;
    }
    return self;
}

- (void) executeCallback: (NSArray*) items socket: (id) socket
{
    if (_callback) {
        _callback(items, socket);
    }
}

- (BOOL) isEventEqual: (NSString*) eventName {
    return [event isEqualToString: eventName];
}

@end
