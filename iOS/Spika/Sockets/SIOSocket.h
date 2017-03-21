//
//  SIOSocket.h
//  Spika
//
//  Created by Dmitry Rybochkin on 26.01.17.
//  Copyright © 2017 Clover Studio. All rights reserved.
//

#import <Foundation/Foundation.h>
@import SocketIO;

// NSArray of these JSValue-valid objects:
typedef NSArray SIOParameterArray;
// --------------------
//        NSNull
//       NSString
//       NSNumber
//     NSDictionary
//       NSArray
//        NSData
// --------------------

@interface SIOSocket : NSObject

// Generators
+ (void)socketWithHost:(NSString *)hostURL response:(void(^)(SIOSocket *socket))response;
+ (void)socketWithHost:(NSString *)hostURL reconnectAutomatically:(BOOL)reconnectAutomatically attemptLimit:(NSInteger)attempts withDelay:(NSTimeInterval)reconnectionDelay maximumDelay:(NSTimeInterval)maximumDelay timeout:(NSTimeInterval)timeout nsp: (NSString*) nsp response:(void(^)(SIOSocket *socket))response;

// Event responders
@property (nonatomic, copy) void (^onConnect)();
@property (nonatomic, copy) void (^onDisconnect)();
@property (nonatomic, copy) void (^onError)(NSDictionary *errorInfo);

@property (nonatomic, copy) void (^onReconnect)(NSInteger numberOfAttempts);
@property (nonatomic, copy) void (^onReconnectionAttempt)(NSInteger numberOfAttempts);
@property (nonatomic, copy) void (^onReconnectionError)(NSDictionary *errorInfo);

- (void)on:(NSString *)event callback:(void (^)(SIOParameterArray *args))function;

// Emitters
- (void)emit:(NSString *)event;
- (void)emit:(NSString *)event args:(SIOParameterArray *)args;

- (void)close;

@end

