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

@property (nonatomic) ReadState state;
@property (nonatomic) NSInputStream *inputStream;
@property (nonatomic) NSOutputStream *outputStream;
@property (nonatomic) HYReadBuffer *buffer;
@property (nonatomic) id<HYNbkqStream> streamDelegate;

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
        self.inputStream = input;
        self.outputStream = output;
        int result = [self ensureStreamsAreAlive];
        if (result == -1)
        {
            NSLog(@"Error opening streams, terminating...");
            NSParameterAssert(NULL);
        }
        self.state = PayloadLen;
        self.buffer = [[HYReadBuffer alloc] init];
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
    const unsigned short count = [self.buffer remaining];
    uint8_t buffer[count];
    int numRead = (int)[self.inputStream read:buffer maxLength:count];
    
    if (numRead < 0)
    {
        [self.streamDelegate onError:E_ON_READ];
    }
    
    if (numRead == 0)
    {
        [self.streamDelegate onError:E_EOF];
    }
    
    for (int x = 0; x < numRead; x++)
    {
        [self.buffer push:buffer[x]];
    }
    
    if ([self.buffer remaining] == 0)
    {
        if (self.state == PayloadLen)
        {
            [self.buffer calcPayloadLen];
            uint16_t payloadLen = [self.buffer payloadLen];
            [self.buffer setCapacity:payloadLen];
            self.state = Payload;
        }
        else
        {
            [self.buffer reset];
            self.state = PayloadLen;
            
            NSArray *internalBuffer = [self.buffer drainQueue];
            if ([internalBuffer count] != 1)
            {
                NSLog(@"Error - reading completed but internal buffer was not equal to one...?");
                NSParameterAssert(NULL);
            }
            NSData *internalPayload = (NSData *)internalBuffer[0];
            [self.streamDelegate onDataReceived:(const uint8_t *)[internalPayload bytes]
                                        withLen:(const size_t)[internalPayload length]];
        }
    }
}

- (void)write:(NSData *)buffer
{
    uint8_t *nBuffer = (uint8_t *)calloc(buffer.length + 2, sizeof(uint8_t));
    uint8_t *nBufferOrigin = nBuffer;
    nBuffer[0] = (uint16_t)buffer.length & 0xFFFF << 8;
    nBuffer[1] = (uint16_t)buffer.length & 0xFFFF;
    
    const uint8_t *bytes = [buffer bytes];
    for (int x = 0; x < buffer.length; x++)
    {
        nBuffer[x + 2] = *(bytes + x);
    }
    
    uint zeroWrittenAttempts = 0;
    size_t bytesRemaining = buffer.length + 2;
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
        [self.streamDelegate onConnected];
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
