// Copyright 2015 Nathan Sizemore <nathanrsizemore@gmail.com>
//
// This Source Code Form is subject to the
// terms of the Mozilla Public License, v.
// 2.0. If a copy of the MPL was not
// distributed with this file, You can
// obtain one at
// http://mozilla.org/MPL/2.0/.


#import "HydrogenClient.h"
#import <CoreFoundation/CoreFoundation.h>


@interface HydrogenClient ()

@property (nonatomic) id<Hydrogen> hydrogenDelegate;
@property (nonatomic, strong) void (^onConnectHandler)();
@property (nonatomic, strong) void (^onDisconnectHandler)();
@property (nonatomic, strong) void (^onDataReceivedHandler)(NSData *);
@property (nonatomic, strong) void (^onErrorHandler)(HydrogenResult);
@property (nonatomic) ExecutionEnvironment environment;
@property (nonatomic) HYNbkqStream *stream;

@end


@implementation HydrogenClient

- (id)initWithDataReceivedFunction:(void (*)(const uint8_t *, const size_t))dataReceivedFunction
              andOnConnectFunction:(void (*)())onConnectFunction
           andOnDisconnectFunction:(void (*)())onDisconnectFunction
                andOnErrorFunction:(void (*)(HydrogenResult))onErrorFunction
{
    self = [super init];
    if (self)
    {
        self.environment = EE_BLOCK;
        self.onConnectHandler = ^() { onConnectFunction(); };
        self.onDisconnectHandler = ^() { onDisconnectFunction(); };
        self.onDataReceivedHandler = ^(NSData *data) {
            dataReceivedFunction((const uint8_t *)[data bytes], (const size_t)[data length]);
        };
        self.onErrorHandler = ^(HydrogenResult result) { onErrorFunction(result); };
    }
    
    return self;
}

- (id)initWithHydrogenDelegate:(id<Hydrogen>)delegate
{
    self = [super init];
    if (self)
    {
        self.environment = EE_DELEGATE;
        self.hydrogenDelegate = delegate;
    }
    
    return self;
}

- (id)initWithDataReceivedBlock:(void (^)(NSData *))onDataReceivedBlock
              andOnConnectBlock:(void (^)())onConnectBlock
           andOnDisconnectBlock:(void (^)())onDisconnectBlock
                andOnErrorBlock:(void (^)(HydrogenResult))onErrorBlock
{
    self = [super init];
    if (self)
    {
        self.environment = EE_BLOCK;
        self.onConnectHandler = onConnectBlock;
        self.onDisconnectHandler = onDisconnectBlock;
        self.onDataReceivedHandler = onDataReceivedBlock;
        self.onErrorHandler = onErrorBlock;
    }
    
    return self;
}

- (void)connectToHostWithAddress:(NSString *)hostAddress
                         andPort:(uint16_t)port
                          useSSL:(BOOL)sslOption
{
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                       (__bridge CFStringRef)hostAddress,
                                       port,
                                       &readStream,
                                       &writeStream);
    if (!readStream && !writeStream)
    {
        NSLog(@"Unable to create read and write streams...");
        return;
    }
    
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    
    inputStream = (__bridge_transfer NSInputStream *)readStream;
    outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    
    if (sslOption)
    {
        [inputStream setProperty:NSStreamSocketSecurityLevelTLSv1 forKey:NSStreamSocketSecurityLevelKey];
        [outputStream setProperty:NSStreamSocketSecurityLevelTLSv1 forKey:NSStreamSocketSecurityLevelKey];
    }
    
    self.stream = [[HYNbkqStream alloc] initWithInputStream:inputStream
                                            andOutputStream:outputStream
                                    andHYNbkqStreamDelegate:self];
}

- (void)disconnect
{
    [self.stream close];
}

- (void)writeData:(NSData *)buffer
{
    [self.stream write:buffer];
}

- (void)writeBytes:(const uint8_t *)buffer toLen:(const size_t)len
{
    [self.stream writeBytes:buffer toLen:len];
}

// Called when connection to host has been established
- (void)onConnected
{
    switch (self.environment)
    {
        case EE_BLOCK:
            self.onConnectHandler();
            break;
        case EE_DELEGATE:
            [self.hydrogenDelegate onConnected];
            break;
            
        default:
            NSLog(@"Environment: %d - something is not initialized...?", (int)self.environment);
    }
}

// Called when connection to host has been lost
- (void)onDisconnected
{
    switch (self.environment)
    {
        case EE_BLOCK:
            self.onDisconnectHandler();
            break;
        case EE_DELEGATE:
            [self.hydrogenDelegate onDisconnected];
            break;
            
        default:
            NSLog(@"Environment: %d - something is not initialized...?", (int)self.environment);
    }
}

// Called when data is received from host
- (void)onDataReceived:(const uint8_t *)buffer withLen:(const size_t)len
{
    switch (self.environment)
    {
        case EE_BLOCK:
        {
            NSData *data = [NSData dataWithBytesNoCopy:(void*)buffer length:len freeWhenDone:YES];
            self.onDataReceivedHandler(data);
            break;
        }
        case EE_DELEGATE:
        {
            NSData *data = [NSData dataWithBytesNoCopy:(void*)buffer length:len freeWhenDone:YES];
            [self.hydrogenDelegate onDataReceived:data];
            break;
        }
            
        default:
            NSLog(@"Environment: %d - something is not initialized...?", (int)self.environment);
    }
}

// Called when an error has been encountered
- (void)onError:(HydrogenResult)error
{
    switch (self.environment)
    {
        case EE_BLOCK:
            self.onErrorHandler(error);
            break;
        case EE_DELEGATE:
            [self.hydrogenDelegate onError:error];
            break;
            
        default:
            NSLog(@"Environment: %d - something is not initialized...?", (int)self.environment);
    }
}

@end
