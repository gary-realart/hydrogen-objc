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


@interface HYReadBuffer : NSObject

// Bytes need to complete the current payload
- (uint16_t)remaining;
// Pushes elem onto the buffer, decrementing remaining
- (void)push:(uint8_t)elem;
// Sets the internal buffers capacity
- (void)setCapacity:(uint16_t)size;
// Calculates the payload len from the payload length frame
- (void)calcPayloadLen;
// Returns the length of the current payload
- (uint16_t)payloadLen;
// Pushes the current payload onto the queue and resets the internal buffer
- (void)reset;
// Returns the current queue length
- (size_t)queueLen;
// Returns a mutable reference to the queue
- (NSMutableArray *)queueAsMutable;
// Returns an NSArray of NSData and reset the queue to the default state
- (NSArray *)drainQueue;

@end
