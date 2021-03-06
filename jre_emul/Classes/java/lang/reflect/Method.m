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
//  Method.m
//  JreEmulation
//
//  Created by Tom Ball on 11/07/11.
//

#import "IOSClass.h"
#import "IOSObjectArray.h"
#import "IOSReflection.h"
#import "JavaMetadata.h"
#import "JreEmulation.h"
#import "java/lang/AssertionError.h"
#import "java/lang/IllegalArgumentException.h"
#import "java/lang/NullPointerException.h"
#import "java/lang/reflect/Method.h"
#import "java/lang/reflect/TypeVariable.h"

@implementation JavaLangReflectMethod

+ (id)methodWithSelector:(SEL)aSelector
               withClass:(IOSClass *)aClass
            withMetadata:(JavaMethodMetadata *)metadata {
  return AUTORELEASE([[JavaLangReflectMethod alloc]
      initWithSelector:aSelector withClass:aClass withMetadata:metadata]);
}

- (id)initWithSelector:(SEL)aSelector
             withClass:(IOSClass *)aClass
          withMetadata:(JavaMethodMetadata *)metadata {
  return [super initWithSelector:aSelector
                       withClass:aClass
                    withMetadata:metadata];
}

// Returns method name.
- (NSString *)getName {
  NSString *javaName = [metadata_ javaName];
  if (javaName) {
    return javaName;
  }

  // Demangle signature to retrieve original method name.
  NSString *name = NSStringFromSelector(selector_);
  NSRange range = [name rangeOfString:@":"];
  if (range.location == NSNotFound) {
    return name;  // It's not mangled.
  }

  // The name ends with the last "WithType" before the first colon.
  range = [name rangeOfString:@"With" options:NSBackwardsSearch
      range:NSMakeRange(0, range.location)];
  if (range.location == NSNotFound) {
    return name;
  }
  return [name substringToIndex:range.location];
}

- (NSString *)internalName {
  return NSStringFromSelector(selector_);
}

- (IOSClass *)getReturnType {
  id<JavaLangReflectType> returnType = [metadata_ returnType];
  if (returnType) {
    if (![returnType isKindOfClass:[IOSClass class]]) {
      return [IOSClass objectClass];
    } else {
      return (IOSClass *) returnType;
    }
  }
  const char *argType = [methodSignature_ methodReturnType];
  if (strlen(argType) != 1) {
    NSString *errorMsg =
        [NSString stringWithFormat:@"unexpected return type: %s", argType];
    id exception = [[JavaLangAssertionError alloc] initWithNSString:errorMsg];
#if ! __has_feature(objc_arc)
    [exception autorelease];
#endif
    @throw exception;
  }
  return decodeTypeEncoding(argType);
}

- (id<JavaLangReflectType>)getGenericReturnType {
  id<JavaLangReflectType> returnType = [metadata_ returnType];
  if (returnType) {
    if (returnType && [returnType conformsToProtocol:@protocol(JavaLangReflectTypeVariable)]) {
      return returnType;
    }
  }
  return [self getReturnType];
}

- (id)invokeWithId:(id)object
       withNSObjectArray:(IOSObjectArray *)arguments {
  if (!classMethod_ && object == nil) {
    @throw AUTORELEASE([[JavaLangNullPointerException alloc] initWithNSString:
      @"null object specified for non-final method"]);
  }

  IOSObjectArray *paramTypes = [self getParameterTypes];
  NSUInteger nArgs = arguments ? arguments->size_ : 0;
  if (nArgs != paramTypes->size_) {
    @throw AUTORELEASE([[JavaLangIllegalArgumentException alloc] initWithNSString:
        @"wrong number of arguments"]);
  }

  NSInvocation *invocation =
      [NSInvocation invocationWithMethodSignature:methodSignature_];
  [invocation setSelector:selector_];
  for (NSUInteger i = 0; i < nArgs; i++) {
    J2ObjcRawValue arg;
    if (![paramTypes->buffer_[i] __unboxValue:arguments->buffer_[i] toRawValue:&arg]) {
      @throw AUTORELEASE([[JavaLangIllegalArgumentException alloc] initWithNSString:
          @"argument type mismatch"]);
    }
    [invocation setArgument:&arg atIndex:i + SKIPPED_ARGUMENTS];
  }
  if (object == nil || [object isKindOfClass:[IOSClass class]]) {
    [invocation setTarget:class_.objcClass];
  } else {
    [invocation setTarget:object];
  }

  [invocation invoke];
  IOSClass *returnType = [self getReturnType];
  if (returnType == [IOSClass voidClass]) {
    return nil;
  }
  J2ObjcRawValue returnValue;
  [invocation getReturnValue:&returnValue];
  return [returnType __boxValue:&returnValue];
}

- (NSString *)description {
  NSString *kind = classMethod_ ? @"+" : @"-";
  const char *argType = [methodSignature_ methodReturnType];
  NSString *returnType = [NSString stringWithUTF8String:argType];
  NSString *result = [NSString stringWithFormat:@"%@ %@ %@(", kind,
                      describeTypeEncoding(returnType), [self getName]];

  NSUInteger nArgs = [methodSignature_ numberOfArguments] - SKIPPED_ARGUMENTS;
  for (NSUInteger i = 0; i < nArgs; i++) {
    const char *argType =
        [methodSignature_ getArgumentTypeAtIndex:i + SKIPPED_ARGUMENTS];
    NSString *paramEncoding = [NSString stringWithUTF8String:argType];
    result = [result stringByAppendingFormat:@"%@",
                  describeTypeEncoding(paramEncoding)];
    if (i + 1 < nArgs) {
      result = [result stringByAppendingString:@", "];
    }
  }
  return [result stringByAppendingString:@")"];
}

- (IOSObjectArray *)getDeclaredAnnotations {
  JavaLangReflectMethod *method = [self getAnnotationsAccessor:[self internalName]];
  return [self getAnnotationsFromAccessor:method];
}

- (IOSObjectArray *)getParameterAnnotations {
  JavaLangReflectMethod *method = [self getParameterAnnotationsAccessor:[self internalName]];
  return [self getAnnotationsFromAccessor:method];
}

- (id)getDefaultValue {
  // TODO(tball): implement as part of method metadata.
  return nil;
}

@end
