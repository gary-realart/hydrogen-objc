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


#import "HYMessage.h"


@implementation HYMessage

- (id)init
{
    self = [super init];
    if (self)
    {
        self.len = 0;
        self.payload = [[NSData alloc] init];
    }
    
    return self;
}

@end
