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


@interface HYMessage : NSObject

// Represents the current payload length
@property uint16_t len;
// Represents the current payload
@property (strong, nonatomic) NSData *payload;

@end
