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
@property (nonatomic) void *onConnectHandler;
@property (nonatomic) void *onDisconnectHandler;
@property (nonatomic) void *onDataReceivedHandler;
@property (nonatomic) void *onErrorHandler;
@property (nonatomic) ExecutionEnvironment environment;
@property (nonatomic) HYNbkqStream *stream;

@end


@implementation HydrogenClient

- (id)initWithDataReceivedFunction:(void (*)(const uint8_t *, const size_t len))dataReceivedFunction
              andOnConnectFunction:(void (*)())onConnectFunction
           andOnDisconnectFunction:(void (*)())onDisconnectFunction
                andOnErrorFunction:(void (*)(HydrogenResult))onErrorFunction
{
    self = [super init];
    if (self)
    {
        self.environment = EE_FUNCTION;
        self.onConnectHandler = (void *)onConnectFunction;
        self.onDisconnectHandler = (void *)onDisconnectFunction;
        self.onDataReceivedHandler = (void *)dataReceivedFunction;
        self.onErrorHandler = (void *)onErrorFunction;
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
        self.onConnectHandler = (__bridge void *)onConnectBlock;
        self.onDisconnectHandler = (__bridge void *)onDisconnectBlock;
        self.onDataReceivedHandler = (__bridge void *)onDataReceivedBlock;
        self.onErrorHandler = (__bridge void *)onErrorBlock;
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
            ((__bridge void (^)())self.onConnectHandler)();
            break;
        case EE_DELEGATE:
            [self.hydrogenDelegate onConnected];
            break;
        case EE_FUNCTION:
            ((void (*)())self.onConnectHandler)();
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
            ((__bridge void (^)())self.onDisconnectHandler)();
            break;
        case EE_DELEGATE:
            [self.hydrogenDelegate onDisconnected];
            break;
        case EE_FUNCTION:
            ((void (*)())self.onDisconnectHandler)();
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
            ((__bridge void (^)(NSData *))self.onDataReceivedHandler)(data);
            break;
        }
        case EE_DELEGATE:
        {
            NSData *data = [NSData dataWithBytesNoCopy:(void*)buffer length:len freeWhenDone:YES];
            [self.hydrogenDelegate onDataReceived:data];
            break;
        }
        case EE_FUNCTION:
        {
            ((void (*)(const uint8_t *, const size_t len))self.onDataReceivedHandler)(buffer, len);
            free((void *)buffer);
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
            ((__bridge void (^)())self.onErrorHandler)(error);
            break;
        case EE_DELEGATE:
            [self.hydrogenDelegate onError:error];
            break;
        case EE_FUNCTION:
            ((void (*)())self.onErrorHandler)(error);
            break;
            
        default:
            NSLog(@"Environment: %d - something is not initialized...?", (int)self.environment);
    }
}

@end
