//
//  SIOSocket.m
//  Spika
//
//  Created by Dmitry Rybochkin on 26.01.17.
//  Copyright © 2017 Clover Studio. All rights reserved.
//

#import "SIOSocket.h"
#import "SocketEventHandler.h"

@interface SIOSocket () <SRWebSocketDelegate>

@property (nonatomic, strong) SRWebSocket *socket;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) BOOL isTryingReConnect;
@property (nonatomic) BOOL reconnectAutomatically;
@property (nonatomic, strong) NSString* hostURL;
@property (nonatomic) NSInteger attemptLimit;
@property (nonatomic) NSTimeInterval reconnectionDelay;
@property (nonatomic) NSTimeInterval maximumDelay;
@property (nonatomic) NSTimeInterval timeout;
@property (nonatomic) NSInteger attemptDelay;
@property (nonatomic, strong) NSMutableArray<SocketEventHandler *>* handlers;
@property (nonatomic, strong) NSMutableArray<NSString*>* queue;
//@property (nonatomic, copy) void (^response)(SIOSocket *socket);

@end

@implementation SIOSocket

- (instancetype) init:(NSString *)hostURL reconnectAutomatically:(BOOL)reconnectAutomatically attemptLimit:(NSInteger)attempts withDelay:(NSTimeInterval)reconnectionDelay maximumDelay:(NSTimeInterval)maximumDelay timeout:(NSTimeInterval)timeout nsp: (NSString*) nsp response:(void (^)(SIOSocket *))response {
    self = [super init];
    if (self) {
        self.isTryingReConnect = NO;
        self.reconnectAutomatically = reconnectAutomatically;
        self.hostURL = hostURL;
        self.attemptLimit = attempts;
        self.reconnectionDelay = reconnectionDelay;
        self.maximumDelay = maximumDelay;
        self.timeout = timeout;
        self.attemptDelay = 0;
        //self.response = response;
        self.handlers = [[NSMutableArray alloc] init];
        self.queue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) initSocket {
    if (self.socket != nil) {
        self.socket.delegate = nil;
        [self.socket close];
        self.socket = nil;
    }
    NSURL *url = [NSURL URLWithString: _hostURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    self.socket = [[SRWebSocket alloc] initWithURLRequest:request];

    self.socket.delegate = self;
}

- (void) connect {
    _isTryingReConnect = NO;
    _attemptDelay = 1;
    
    [self initSocket];
    
    [self.socket open];
}

-(void) reconnect
{
    _isTryingReConnect = YES;
    if (_timer == nil) {
        _timer = [NSTimer scheduledTimerWithTimeInterval: _timeout repeats: _reconnectAutomatically block: ^(NSTimer* timer) {
            _attemptDelay++;
            if (self.onReconnectionAttempt != nil) {
                self.onReconnectionAttempt(_attemptDelay);
            }
            
            [self initSocket];
            
            [self.socket open];
        }];
    }
    if (_reconnectAutomatically && _attemptDelay < _attemptLimit && _timer.isValid) {
        [_timer fire];
    }
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
    SIOSocket *socket = [[SIOSocket alloc] init:hostURL reconnectAutomatically: reconnectAutomatically attemptLimit: attempts withDelay: reconnectionDelay maximumDelay: maximumDelay timeout: timeout nsp: nsp response: response];
    if (!socket) {
        response(nil);
        return;
    }
    
    response(socket);
    
    [socket connect];
}

- (void)dealloc {
    [self close];
    [self.handlers removeAllObjects];
}


// Event listeners
- (void)on:(NSString *)event callback:(void (^)(SIOParameterArray *args)) function {
    NSString *eventID = [event stringByReplacingOccurrencesOfString: @" " withString: @"_"];
    
    SocketEventHandler* handler = [SocketEventHandler eventWithName:eventID andCallback: ^(NSArray* items, id socket) {
        NSLog(@"socket %@", event);
        if (function) {
            function(items);
        }
    }];
    
    [self.handlers addObject: handler];
}

// Emitters
- (void)emit:(NSString *)event {
    [self emit: event args: nil];
}

- (void)emit:(NSString *)event args:(SIOParameterArray *)args {
    //пример ["login",{"roomID":"w1","name":"MacBookPro","avatarURL":"","userID":"MacBookPro"}]
    
    NSString *eventID = [event stringByReplacingOccurrencesOfString: @" " withString: @"_"];
    NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObjectsAndKeys: eventID, @"event", @"", @"data", nil];
    //[NSMutableArray arrayWithObject: [NSString stringWithFormat: @"'%@'", eventID]];
    for (id arg in args) {
        if ([arg isKindOfClass: [NSNull class]]) {
            [arguments setObject: @"null" forKey: @"data"];
        }
        else if ([arg isKindOfClass: [NSString class]]) {
            [arguments setObject: [NSString stringWithFormat: @"'%@'", arg] forKey: @"data"];
        }
        else if ([arg isKindOfClass: [NSNumber class]]) {
            [arguments setObject: [NSString stringWithFormat: @"'%@'", arg] forKey: @"data"];
        }
        else if ([arg isKindOfClass: [NSData class]]) {
            NSString *dataString = [[NSString alloc] initWithData: arg encoding: NSUTF8StringEncoding];
            [arguments setObject: [NSString stringWithFormat: @"blob('%@')", dataString] forKey: @"data"];
        }
        else if ([arg isKindOfClass: [NSArray class]] || [arg isKindOfClass: [NSDictionary class]]) {
            [arguments setObject: arg forKey: @"data"];
        }
    }
    /*TODO проверить формат отправки*/
    /*если сокет не подключен нужно добавить в очередь*/
    NSString *str = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject: arguments options: 0 error: nil] encoding: NSUTF8StringEncoding];
    if (self.socket.readyState == SR_OPEN) {
        NSError* error;
        [self.socket sendString: str error: &error];
    } else {
        [self.queue addObject: str];
    }
}

- (void)close {
    [self.socket close];
    [self.queue removeAllObjects];
}

- (void) processEvent:(nonnull NSString *)event data: (SIOParameterArray*) data
{
    NSLog(@"Received \"%@\"", event);
    
    NSPredicate* eventName = [NSPredicate predicateWithBlock: ^BOOL(id evaluatedObject, NSDictionary *bindings) {
        SocketEventHandler* handler = (SocketEventHandler*)evaluatedObject;
        return [handler isEventEqual: event];
    }];
    
    NSArray<SocketEventHandler*> *events = [self.handlers filteredArrayUsingPredicate: eventName];
    for(SocketEventHandler *handler in events) {
        [handler executeCallback: data socket: self];
    }
}


///--------------------------------------
#pragma mark - SRWebSocketDelegate
///--------------------------------------

- (void)webSocketDidOpen:(SRWebSocket *)webSocket;
{
    NSLog(@"Websocket Connected");
    if (!_isTryingReConnect && self.onConnect != nil) {
        self.onConnect();
    }
    if (_isTryingReConnect && self.onReconnect != nil) {
        self.onReconnect(_attemptDelay);
    }
    _attemptDelay = 0;
    if (self.timer != nil && self.timer.isValid) {
        [self.timer invalidate];
    }
    NSError *error;
    for (NSString* message in self.queue) {
        [self.socket sendString: message error: &error];
        [self.queue removeObject: message];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
{
    NSLog(@":( Websocket Failed With Error %@", error);
    if (!_isTryingReConnect && self.onError != nil) {
        self.onError([error userInfo]);
    }
    if (_isTryingReConnect && self.onReconnectionError != nil) {
        self.onReconnectionError([error userInfo]);
    }
    self.socket = nil;
    
    [self reconnect];
}

- (void) executeEvent: (NSString*) event {
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    NSLog(@"Received \"%@\"", message);

    if ([message isKindOfClass:[NSString class]]) {
        [self webSocket:webSocket didReceiveMessageWithString: message];
    } else {
        if (self.onError) {
            //TODO проверить формат передачи ошибок
            self.onError(@{NSLocalizedDescriptionKey: (NSLocalizedString(@"Operation was unsuccessful.", nil))});
        }
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessageWithString:(nonnull NSString *)string
{
    NSLog(@"Received \"%@\"", string);
    //пример ["login",{"roomID":"w1","name":"MacBookPro","avatarURL":"","userID":"MacBookPro"}]
    
    //TODO Проверить как работает с null и blob
    NSError *error;
    NSData* jsonData = [string dataUsingEncoding: NSUTF8StringEncoding];
    NSArray *values = [NSJSONSerialization JSONObjectWithData: jsonData options: NSJSONReadingMutableContainers error: &error];
    
    if (error && error.code != 0 && !(values && values.count > 0 && ![values[0] isKindOfClass: [NSString class]])) {
        if (self.onError) {
            //TODO проверить формат передачи ошибок
            if (error) {
                self.onError([error userInfo]);
            } else {
                self.onError( @{ NSLocalizedDescriptionKey: [NSString stringWithFormat: @"%@ %@", (NSLocalizedString(@"Operation was unsuccessful.", nil)), string] } );
            }
        }
        return;
    }
    
    NSString* event = [values[0] stringByReplacingOccurrencesOfString: @" " withString: @"_"];
    
    if (values.count > 1 && [values[1] isKindOfClass:[NSDictionary class]]) {
        [self processEvent: event data: @[values[1]]];
    } else {
        [self processEvent: event data: @[]];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
{
    NSLog(@"WebSocket closed %ld, %@, %d", (long)code, reason, wasClean);
    if (self.onDisconnect != nil) {
        self.onDisconnect();
    }
    //self.title = @"Connection Closed! (see logs)";
    self.socket = nil;
    if (code != 0) {
        [self reconnect];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload;
{
    NSLog(@"WebSocket received pong");
}

@end
