//
//  SIOSocket.m
//  Spika
//
//  Created by Dmitry Rybochkin on 26.01.17.
//  Copyright © 2017 Clover Studio. All rights reserved.
//

#import "SIOSocket.h"


@interface SIOSocket ()
    @property (nonatomic, strong) SocketIOClient *socket;
@end

@implementation SIOSocket

- (instancetype) init:(NSString *)hostURL reconnectAutomatically:(BOOL)reconnectAutomatically attemptLimit:(NSInteger)attempts withDelay:(NSTimeInterval)reconnectionDelay maximumDelay:(NSTimeInterval)maximumDelay timeout:(NSTimeInterval)timeout nsp: (NSString*) nsp {
    self = [super init];
    if (self) {
        NSURL* url = [[NSURL alloc] initWithString: hostURL];
        self.socket = [[SocketIOClient alloc] initWithSocketURL:url config:@{@"log": @YES, @"nsp": nsp, @"reconnects": @(reconnectAutomatically), @"reconnectAttempts": @(attempts), @"reconnectWait": @(timeout)}];
    }
    return self;
}

// Generators
+ (void)socketWithHost:(NSString *)hostURL response:(void (^)(SIOSocket *))response {
    return [self socketWithHost: hostURL
         reconnectAutomatically: YES
                   attemptLimit: -1
                      withDelay: 1
                   maximumDelay: 5
                        timeout: 20
                            nsp: @"/spika"
                       response: response];
}

+ (void)socketWithHost:(NSString *)hostURL reconnectAutomatically:(BOOL)reconnectAutomatically attemptLimit:(NSInteger)attempts withDelay:(NSTimeInterval)reconnectionDelay maximumDelay:(NSTimeInterval)maximumDelay timeout:(NSTimeInterval)timeout nsp: (NSString*) nsp response:(void (^)(SIOSocket *))response {
    SIOSocket *socket = [[SIOSocket alloc] init:hostURL reconnectAutomatically: reconnectAutomatically attemptLimit: attempts withDelay: reconnectionDelay maximumDelay: maximumDelay timeout: timeout nsp: nsp];
    if (!socket) {
        response(nil);
        return;
    }
    
    [socket.socket connect];
    
    __weak typeof(socket) weakSocket = socket;

    [socket.socket on:@"connect" callback:^(NSArray* data, SocketAckEmitter* ack) {
        NSLog(@"socket connected");
        if (weakSocket.onConnect) {
            weakSocket.onConnect();
        }
    }];
    
    [socket.socket on:@"disconnect" callback: ^(NSArray* data, SocketAckEmitter* ack) {
        NSLog(@"socket disconnected");
        if (weakSocket.onDisconnect) {
            weakSocket.onDisconnect();
        }
    }];

    [socket.socket on:@"error" callback: ^(NSArray* data, SocketAckEmitter* ack) {
        NSLog(@"socket error");
        if (weakSocket.onError) {
            //TODO convert data to NSDictionary
            weakSocket.onError([NSDictionary dictionaryWithObject:data forKey: @"data"]);
        }
    }];

    [socket.socket on:@"reconnect" callback: ^(NSArray* data, SocketAckEmitter* ack) {
        NSLog(@"socket reconnect");
        if (weakSocket.onReconnect) {
            weakSocket.onReconnect(data.count);
        }
    }];

    [socket.socket on:@"reconnectAttempt" callback: ^(NSArray* data, SocketAckEmitter* ack) {
        NSLog(@"socket reconnectAttempt");
        if (weakSocket.onReconnectionAttempt) {
            weakSocket.onReconnectionAttempt(data.count);
        }
    }];
    
    [socket.socket onAny:^(SocketAnyEvent* event) {
        NSLog(@"socket anyevent %@", event);
    }];
    
    response(socket);
}

- (void)dealloc {
    [self close];
}


// Event listeners
- (void)on:(NSString *)event callback:(void (^)(SIOParameterArray *args)) function {
    NSString *eventID = [event stringByReplacingOccurrencesOfString: @" " withString: @"_"];
    [self.socket on: eventID callback: ^(NSArray* data, SocketAckEmitter* ack) {
        NSLog(@"socket %@", event);
        function(data);
    }];
}

// Emitters
- (void)emit:(NSString *)event {
    [self emit: event args: nil];
}

- (void)emit:(NSString *)event args:(SIOParameterArray *)args {
    NSString *eventID = [event stringByReplacingOccurrencesOfString: @" " withString: @"_"];
    [self.socket emit: eventID with: args];
}

- (void)close {
    [self.socket disconnect];
}

@end
