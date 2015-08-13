// Copyright 2015 Nathan Sizemore <nathanrsizemore@gmail.com>
//
// This Source Code Form is subject to the
// terms of the Mozilla Public License, v.
// 2.0. If a copy of the MPL was not
// distributed with this file, You can
// obtain one at
// http://mozilla.org/MPL/2.0/.
//
// This Source Code Form is "Incompatible
// With Secondary Licenses", as defined by
// the Mozilla Public License, v. 2.0.


#import <Foundation/Foundation.h>
#import "HYNbkqStream.h"
#import "HydrogenTypes.h"


@protocol Hydrogen <NSObject>

// Called when connection to host has been established
- (void)onConnected;
// Called when connection to host has been lost
- (void)onDisconnected;
// Called when data is received from host
- (void)onDataReceived:(const uint8_t *)buffer;
// Called when an error has been encountered
- (void)onError:(HydrogenResult)error;

@end


@interface HydrogenClient : NSObject <HYNbkqStream>

// Initializes the client with C style function pointers
- (id)initWithDataReceivedFunction:(void (*)(const uint8_t *))dataReceivedFunction
              andOnConnectFunction:(void (*)())onConnectFunction
           andOnDisconnectFunction:(void (*)())onDisconnectFunction
                andOnErrorFunction:(void (*)(HydrogenResult))onErrorFunction;
// Initializes the client with Obj-C style delegate/protocol messaging
- (id)initWithHydrogenDelegate:(id<Hydrogen>)delegate;
// Initializes the client with Obj-C style blocks
- (id)initWithDataReceivedBlock:(void (^)(const uint8_t *))dataReceivedBlock
              andOnConnectBlock:(void (^)())onConnectBlock
           andOnDisconnectBlock:(void (^)())onDisconnectBlock
                andOnErrorBlock:(void (^)(HydrogenResult))onErrorBlock;
// Attempts to connect to the given Ipv4 address and port
// On failure, the onError callback is called
- (void)connectToHostWithAddress:(NSString *)hostAddress
                         andPort:(uint16_t)port;
// Attempts to write the complete buffer to the stream
// On failure E_ON_WRITE error is returned
- (void)write:(NSData *)buffer;
// Disconnects from the current connected host
- (void)disconnect;

@end
