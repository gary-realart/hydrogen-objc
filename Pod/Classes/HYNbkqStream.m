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


#import "HYNbkqStream.h"
#import "HYMessage.h"
#import "HYReadBuffer.h"


@interface HYNbkqStream ()

@property (nonatomic) FrameState state;
@property (nonatomic) NSInputStream *inputStream;
@property (nonatomic) NSOutputStream *outputStream;
@property (nonatomic) NSMutableArray *buffer;
@property (nonatomic) NSMutableArray *scratch;
@property (nonatomic) id<HYNbkqStream> streamDelegate;

// NSStreamEvent likes to send a notification for each side of the
// stream (in and out), this is here to provide a count so that the
// end user only gets one callback called once both streams are connected
@property (nonatomic) uint8_t streamsConnected;

@end


@implementation HYNbkqStream

- (id)initWithInputStream:(NSInputStream *)input
          andOutputStream:(NSOutputStream *)output
  andHYNbkqStreamDelegate:(id<HYNbkqStream>)delegate
{
    NSParameterAssert(input);
    NSParameterAssert(output);
    NSParameterAssert(delegate);
    
    self = [super init];
    if (self)
    {
        self.streamsConnected = 0;
        self.inputStream = input;
        self.outputStream = output;
        int result = [self ensureStreamsAreAlive];
        if (result == -1)
        {
            NSLog(@"Error opening streams, terminating...");
            NSParameterAssert(NULL);
        }
        self.state = Start;
        self.buffer = [[NSMutableArray alloc] init];
        self.scratch = [[NSMutableArray alloc] init];
        self.streamDelegate = delegate;
    }
    
    return self;
}

- (int)ensureStreamsAreAlive
{
    NSStreamStatus status;
    
    status = [self.inputStream streamStatus];
    if (status == NSStreamStatusNotOpen)
    {
        [self.inputStream setDelegate:self];
        [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                    forMode:NSDefaultRunLoopMode];
        [self.inputStream open];
    }
    
    status = [self.inputStream streamStatus];
    if (status != NSStreamStatusOpening && status != NSStreamStatusOpen)
    {
        return -1;
    }
    
    status = [self.outputStream streamStatus];
    if (status == NSStreamStatusNotOpen)
    {
        [self.outputStream setDelegate:self];
        [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                     forMode:NSDefaultRunLoopMode];
        [self.outputStream open];
    }
    
    status = [self.outputStream streamStatus];
    if (status != NSStreamStatusOpening && status != NSStreamStatusOpen)
    {
        return -1;
    }
    
    return 0;
}

- (void)read
{
    uint8_t *tbuf = calloc(512, sizeof(uint8_t));
    const int num_read = [self.inputStream read:tbuf maxLength:512];
    if (num_read < 0)
    {
        [self.streamDelegate onError:E_ON_READ];
    }
    if (num_read == 0)
    {
        [self.streamDelegate onError:E_EOF];
    }
    
    uint8_t *buf = calloc([self.scratch count] + num_read, sizeof(uint8_t));
    for (int x = 0; x < [self.scratch count]; x++)
    {
        buf[x] = self.scratch[x];
    }
    memcpy(buf + [self.scratch count], tbuf, num_read);
    free(tbuf);
    
    size_t seek_pos = 0;
    const uint32_t len = num_read + [self.scratch count];
    
    if (self.state == Start)
    {
        [self readForFrameStart:buf withOffset:&seek_pos toLen:len];
    }
    
    if (self.state == PayloadLen)
    {
        [self readPayloadLength:buf withOffset:&seek_pos toLen:len];
    }
    
    if (self.state == Payload)
    {
        [self readPayload:buf withOffset:&seek_pos toLen:len];
    }
    
    if (self.state == End)
    {
        [self readForFrameEnd:buf withOffset:seek_pos toLen:len];
    }
    
    free(buf);
}

- (void)readForFrameStart:(const uint8_t *)buf withOffset:(size_t *)offset toLen:(const size_t)len
{
    while (*offset < len)
    {
        if (buf[*offset] == FRAME_START)
        {
            [self.buffer addObject:[NSNumber numberWithUnsignedChar:buf[*offset]]];
            self.state = PayloadLen;
            *offset += 1;
            break;
        }
        *offset += 1;
    }
}

- (void)readPayloadLength:(const uint8_t *)buf withOffset:(size_t *)offset toLen:(const size_t)len
{
    while (*offset < len)
    {
        [self.buffer addObject:[NSNumber numberWithUnsignedChar:buf[*offset]]];
        if ([self.buffer count] == 3)
        {
            self.state = Payload;
            *offset += 1;
            break;
        }
        *offset += 1;
    }
}

- (void)readPayload:(const uint8_t *)buf withOffset:(size_t *)offset toLen:(const size_t)len
{
    while (*offset < len)
    {
        [self.buffer addObject:[NSNumber numberWithUnsignedChar:buf[*offset]]];
        if ([self.buffer count] == [self payloadLen] + 3)
        {
            self.state = End;
            *offset += 1;
            break;
        }
        *offset += 1;
    }
}

- (void)readForFrameEnd:(const uint8_t *)buf withOffset:(size_t)offset toLen:(const size_t)len
{
    if (offset < len)
    {
        const uint8_t expected_end_byte = buf[offset];
        if (expected_end_byte == FRAME_END)
        {
            const size_t payload_len = [self payloadLen];
            uint8_t *payload = calloc(payload_len, sizeof(uint8_t));
            for (int x = 3; x < [self.buffer count]; x++)
            {
                payload[x - 3] = self.buffer[x];
            }
            self.state = Start;
            self.buffer = [[NSMutableArray alloc] init];
            
            // Dump remaining into scratch space
            offset++;
            self.scratch = [[NSMutableArray alloc] init];
            for (int x = offset; x < len; x++)
            {
                [self.scratch addObject:[NSNumber numberWithUnsignedChar:buf[x]]];
            }
            
            // Do all the callbacks and shit
            [self.streamDelegate onDataReceived:payload
                                        withLen:payload_len];
            return;
        }
        
        // If we're here, the frame was wrong. Maybe our fault, who knows?
        // Either way, we're going to reset and try to start again from the start byte.
        // We need to dump whatever is left in the buffer into our scratch because it
        // might be in there?
        self.state = Start;
        self.buffer = [[NSMutableArray alloc] init];
        self.scratch = [[NSMutableArray alloc] init];
        for (int x = offset; x < len; x++)
        {
            [self.scratch addObject:[NSNumber numberWithUnsignedChar:buf[x]]];
        }
    }
    return;
}

- (uint16_t) payloadLen
{
    const uint16_t mask = 0xFFFF;
    uint16_t len = ((uint16_t)self.buffer[1] << 8) & mask;
    len = len | (uint16_t)self.buffer[2];
    return len;
}

- (void)write:(NSData *)buffer
{
    uint8_t *nBuffer = (uint8_t *)calloc(buffer.length + 4, sizeof(uint8_t));
    uint8_t *nBufferOrigin = nBuffer;
    nBuffer[0] = FRAME_START;
    nBuffer[1] = (uint16_t)buffer.length & 0xFFFF << 8;
    nBuffer[2] = (uint16_t)buffer.length & 0xFFFF;
    
    const uint8_t *bytes = [buffer bytes];
    for (int x = 0; x < buffer.length; x++)
    {
        nBuffer[x + 3] = *(bytes + x);
    }
    nBuffer[buffer.length + 3] = FRAME_END;
    
    uint zeroWrittenAttempts = 0;
    size_t bytesRemaining = buffer.length + 4;
    while (bytesRemaining > 0)
    {
        int numWritten = (int)[self.outputStream write:nBuffer maxLength:bytesRemaining];
        if (numWritten == -1)
        {
            NSError *error = [self.outputStream streamError];
            NSLog(@"Error writing to stream");
            NSLog(@"domain: %@", error.domain);
            NSLog(@"code: %ld", (long)error.code);
            [self.streamDelegate onError:E_ON_WRITE];
            free(nBufferOrigin);
            return;
        }
        
        if (numWritten == 0)
        {
            zeroWrittenAttempts++;
        }
        
        if (zeroWrittenAttempts > 2)
        {
            NSLog(@"3 attempts to write returned 0, assuming EOF");
            [self.streamDelegate onError:E_EOF];
            free(nBufferOrigin);
            return;
        }
        
        if (numWritten > 0)
        {
            bytesRemaining -= numWritten;
            nBuffer += numWritten;
            if (zeroWrittenAttempts > 0)
            {
                zeroWrittenAttempts--;
            }
        }
    }
    
    free(nBufferOrigin);
}

- (void)writeBytes:(const uint8_t *)buffer toLen:(const size_t)len
{
    uint8_t *nBuffer = (uint8_t *)calloc(len + 2, sizeof(uint8_t));
    uint8_t *nBufferOrigin = nBuffer;
    nBuffer[0] = (uint16_t)len & 0xFFFF << 8;
    nBuffer[1] = (uint16_t)len & 0xFFFF;
    
    for (int x = 0; x < len; x++)
    {
        nBuffer[x + 2] = *(buffer + x);
    }
    
    uint zeroWrittenAttempts = 0;
    size_t bytesRemaining = len + 2;
    while (bytesRemaining > 0)
    {
        int numWritten = (int)[self.outputStream write:nBuffer maxLength:bytesRemaining];
        if (numWritten == -1)
        {
            NSError *error = [self.outputStream streamError];
            NSLog(@"Error writing to stream");
            NSLog(@"domain: %@", error.domain);
            NSLog(@"code: %ld", (long)error.code);
            [self.streamDelegate onError:E_ON_WRITE];
            free(nBufferOrigin);
            return;
        }
        
        if (numWritten == 0)
        {
            zeroWrittenAttempts++;
        }
        
        if (zeroWrittenAttempts > 2)
        {
            NSLog(@"3 attempts to write returned 0, assuming EOF");
            [self.streamDelegate onError:E_EOF];
            free(nBufferOrigin);
            return;
        }
        
        if (numWritten > 0)
        {
            bytesRemaining -= numWritten;
            nBuffer += numWritten;
            if (zeroWrittenAttempts > 0)
            {
                zeroWrittenAttempts--;
            }
        }
    }
    
    free(nBufferOrigin);
}

- (void)close
{
    CFReadStreamSetProperty((__bridge CFReadStreamRef)self.inputStream,
                            kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
    CFReadStreamSetProperty((__bridge CFReadStreamRef)self.outputStream,
                            kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
    
    [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                forMode:NSDefaultRunLoopMode];
    [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                 forMode:NSDefaultRunLoopMode];
    
    [self.inputStream close];
    [self.outputStream close];
    [self.streamDelegate onDisconnected];
}

- (void)stream:(NSStream *)theStream
   handleEvent:(NSStreamEvent)streamEvent
{
    if (streamEvent == NSStreamEventOpenCompleted)
    {
        self.streamsConnected++;
        if (self.streamsConnected > 1)
        {
            [self.streamDelegate onConnected];
        }
    }
    else if (streamEvent == NSStreamEventHasBytesAvailable)
    {
        [self read];
    }
    else if (streamEvent == NSStreamEventEndEncountered)
    {
        [self.streamDelegate onError:E_EOF];
    }
    else if (streamEvent == NSStreamEventErrorOccurred)
    {
        [self.streamDelegate onError:E_STREAM];
    }
}

@end
