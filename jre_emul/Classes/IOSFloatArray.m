// Copyright 2011 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//
//  IOSFloatArray.m
//  JreEmulation
//
//  Created by Tom Ball on 6/16/11.
//

#import "IOSFloatArray.h"
#import "IOSClass.h"

@implementation IOSFloatArray

PRIMITIVE_ARRAY_IMPLEMENTATION(float, Float, float)

- (NSString *)descriptionOfElementAtIndex:(NSUInteger)index {
  return [NSString stringWithFormat:@"%g", buffer_[index]];
}

- (IOSClass *)elementType {
  return [IOSClass floatClass];
}

+ (IOSClass *)iosClass {
  return [IOSClass arrayClassWithComponentType:[IOSClass floatClass]];
}

- (id)copyWithZone:(NSZone *)zone {
  return [[IOSFloatArray allocWithZone:zone]
          initWithFloats:buffer_ count:size_];
}

- (void)dealloc {
  free(buffer_);
#if ! __has_feature(objc_arc)
  [super dealloc];
#endif
}

@end
