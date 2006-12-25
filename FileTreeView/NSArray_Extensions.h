//
//  NSArray_Extensions.h
//
//  Copyright (c) 2001-2002, Apple. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (MyExtensions)
- (BOOL)containsObjectIdenticalTo: (id)object;
@end

@interface NSMutableArray (MyExtensions)
- (void) insertObjectsFromArray:(NSArray *)array atIndex:(int)index;
@end

