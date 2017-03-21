//
//  SocketEventHandler.h
//  Spika
//
//  Created by Dmitry Rybochkin on 31.01.17.
//  Copyright © 2017 Clover Studio. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SocketEventHandler : NSObject

+ (SocketEventHandler*) eventWithName: (NSString*) event andCallback: (void (^)(NSArray *items, id socket)) callback;
- (void) executeCallback: (NSArray*) items socket: (id) socket;
- (BOOL) isEventEqual: (NSString*) eventName;

@end
