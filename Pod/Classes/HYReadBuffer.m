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


#import "HYReadBuffer.h"
#import "HYMessage.h"


@interface HYReadBuffer()

@property (nonatomic) HYMessage *cMsg;
@property (nonatomic) uint16_t cRemaining;
@property (nonatomic) NSMutableData *cBuffer;
@property (nonatomic) NSMutableArray *queue;

@end


@implementation HYReadBuffer

- (id)init
{
    self = [super init];
    if (self)
    {
        self.cMsg = [[HYMessage alloc] init];
        self.cRemaining = 2;
        self.cBuffer = [[NSMutableData alloc] init];
        self.queue = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (unsigned short)remaining
{
    return self.cRemaining;
}

- (void)push:(uint8_t)elem
{
    [self.cBuffer appendBytes:&elem length:1];
    self.cRemaining--;
}

- (void)setCapacity:(unsigned short)size
{
    self.cRemaining = size;
    self.cBuffer = [[NSMutableData alloc] initWithCapacity:size];
}

- (void)calcPayloadLen
{
    unsigned short len = 0;
    const unsigned char *bytes = [self.cBuffer bytes];
    len = len | *bytes;
    len = (len << 8) | *(bytes + 1);
    self.cMsg.len = len;
}

- (uint16_t)payloadLen
{
    return self.cMsg.len;
}

- (void)reset
{
    self.cMsg.payload = [NSMutableData dataWithData:self.cBuffer];
    [self.queue addObject:self.cMsg];
    self.cMsg = [[HYMessage alloc] init];
    self.cRemaining = 2;
    self.cBuffer = [[NSMutableData alloc] initWithCapacity:2];
}

- (size_t)queueLen
{
    return [self.queue count];
}

- (NSMutableArray *)queueAsMutable
{
    return self.queue;
}

- (NSArray *)drainQueue
{
    NSMutableArray *buffer = [[NSMutableArray alloc]
                              initWithCapacity:[self.queue count]];
    
    for (uint x = 0; x < [self.queue count]; x++)
    {
        [buffer addObject:((HYMessage *)self.queue[0]).payload];
    }
    
    self.queue = [[NSMutableArray alloc] init];
    return buffer;
}

@end
