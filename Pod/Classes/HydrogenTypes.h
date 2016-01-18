// Copyright 2015 Nathan Sizemore <nathanrsizemore@gmail.com>
//
// This Source Code Form is subject to the
// terms of the Mozilla Public License, v.
// 2.0. If a copy of the MPL was not
// distributed with this file, You can
// obtain one at
// http://mozilla.org/MPL/2.0/.


#ifndef Pods_HydrogenTypes_h
#define Pods_HydrogenTypes_h

#define FRAME_START 0x01
#define FRAME_END   0x17

// State pf current NSInputStream
typedef enum
{
    // Reading for frame start
    Start,
    // Reading for payload len
    PayloadLen,
    // Reading payload
    Payload,
    // Reading for frame end byte
    End
} FrameState;

// Represents the type of callbacks the client will execute
typedef enum
{
    // Obj-C style block as callbacks
    EE_BLOCK,
    // Obj-C style delegates as callbacks
    EE_DELEGATE,
    // C style function pointers as callbacks
    EE_FUNCTION
} ExecutionEnvironment;

// Hydrogen Errors
typedef enum
{
    // Result is Ok
    OK,
    // Buffer was not valid UTF-8
    E_UTF8 = 100,
    // Unable to establish connection with host
    E_CONN_REFUSED = 101,
    // Error during a write to stream
    E_ON_WRITE = 102,
    // Error during read on stream
    E_ON_READ = 103,
    // Stream has reached EOF
    E_EOF = 104,
    // Generic error on stream NSStreamEventErrorOccurred
    E_STREAM = 105
} HydrogenResult;

#endif
