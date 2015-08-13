# hydrogen-objc

[![CI Status](http://img.shields.io/travis/Nathan Sizemore/hydrogen-objc.svg?style=flat)](https://travis-ci.org/Nathan Sizemore/hydrogen-objc)
[![Version](https://img.shields.io/cocoapods/v/hydrogen-objc.svg?style=flat)](http://cocoapods.org/pods/hydrogen-objc)
[![License](https://img.shields.io/cocoapods/l/hydrogen-objc.svg?style=flat)](http://cocoapods.org/pods/hydrogen-objc)
[![Platform](https://img.shields.io/cocoapods/p/hydrogen-objc.svg?style=flat)](http://cocoapods.org/pods/hydrogen-objc)

## Usage

~~~objc
// Initialize a client
//
// Initialization can be done with C function pointers, Obj-C delegates, or
// by passing in Obj-C blocks.
self.client = [[HydrogenClient alloc] initWithHydrogenDelegate:self];

// Connect to a hydrogen server
NSString *hostAddress = @"127.0.0.1";
uint16_t port = 1337;
[self.client connectToHostWithAddress:hostAddress andPort:port];

// Send a thing to server
const char *ping = "ping";
NSData *buffer = [[NSData alloc] initWithBytes:ping length:4];
[self.client write:buffer];

// Disconnect
[self.client disconnect];


// Hydrogen Protocol

// Called when connection to host has been established
- (void)onConnected
{
    NSLog(@"onConnected");
}

// Called when connection to host has been lost
- (void)onDisconnected
{
    NSLog(@"onDisconnected");
}

// Called when data is received from host
- (void)onDataReceived:(const uint8_t *)buffer
{
    NSLog(@"onDataReceived");

    // Assuming it's valid ASCII
    NSLog(@"Host said: %s", (const char *)buffer);
}

// Called when an error has been encountered
- (void)onError:(HydrogenResult)error
{
    // You should probably disconnect and reconnect here
    // instead of just logging... :)
    NSLog(@"onError");
}
~~~

## Installation

hydrogen-objc is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "hydrogen-objc"
```

## Author

Nathan Sizemore, nathanrsizemore@gmail.com

## License

hydrogen-objc is available under the MPL-2.0 license. See the LICENSE file for more info.
