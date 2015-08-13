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
#import "HydrogenTypes.h"


@protocol HYNbkqStream <NSObject>

// Called when connection to host has been established
- (void)onConnected;
// Called when connection to host has been lost
- (void)onDisconnected;
// Called when data is received from host
- (void)onDataReceived:(const uint8_t *)buffer;
// Called when an error has been encountered
- (void)onError:(HydrogenResult)error;

@end


@interface HYNbkqStream : NSObject <NSStreamDelegate>

- (id)initWithInputStream:(NSInputStream *)input
          andOutputStream:(NSOutputStream *)output
  andHYNbkqStreamDelegate:(id<HYNbkqStream>)delegate;

- (void)write:(NSData *)buffer;

- (void)close;

@end