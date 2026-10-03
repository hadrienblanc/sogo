/* TestGCSChannelManager.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <objc/runtime.h>

#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/NSURL+GCS.h>

#import "SOGoTest.h"

static NSString *k6082URL = @"mysql://test-6082:sogo@127.0.0.1:3326/sogo_db/test_6082_pool";

@interface Test6082Channel : NSObject
{
  BOOL isOpen;
  int closeCount;
}

- (int) closeCount;

@end

@implementation Test6082Channel

- (id) init
{
  if ((self = [super init]))
    isOpen = YES;

  return self;
}

- (BOOL) isOpen
{
  return isOpen;
}

- (BOOL) openChannel
{
  return isOpen;
}

- (void) closeChannel
{
  closeCount++;
  isOpen = NO;
}

- (int) closeCount
{
  return closeCount;
}

@end

@interface Test6082Context : NSObject
@end

@implementation Test6082Context

- (id) createAdaptorChannel
{
  return [[[Test6082Channel alloc] init] autorelease];
}

@end

@interface Test6082Adaptor : NSObject
@end

@implementation Test6082Adaptor

- (id) createAdaptorContext
{
  return [Test6082Context new];
}

@end

static id ivarValue6082 (id object, NSString *name)
{
  Ivar ivar;

  ivar = class_getInstanceVariable (object_getClass (object),
                                    [name UTF8String]);
  if (ivar == NULL)
    return nil;

  return object_getIvar (object, ivar);
}

static void setIvarValue6082 (id object, NSString *name, id value)
{
  Ivar ivar;

  ivar = class_getInstanceVariable (object_getClass (object),
                                    [name UTF8String]);
  if (ivar != NULL)
    object_setIvar (object, ivar, value);
}

@interface TestGCSChannelManager : SOGoTest
{
  GCSChannelManager *cm;
  NSURL *url;
}

@end

@implementation TestGCSChannelManager

- (void) setUp
{
  NSMutableDictionary *urlToAdaptor;

  cm = [[GCSChannelManager alloc] init];
  url = [NSURL URLWithString: k6082URL];

  urlToAdaptor = ivarValue6082 (cm, @"urlToAdaptor");
  [urlToAdaptor setObject: [Test6082Adaptor new]
                  forKey: [url gcsURLId]];
}

- (void) tearDown
{
  [cm release];
}

- (Test6082Channel *) acquireChannel
{
  return (Test6082Channel *) [cm acquireOpenChannelForURL: url];
}

- (Test6082Channel *) pooledChannel
{
  NSArray *availableChannels;
  id handle;

  availableChannels = ivarValue6082 (cm, @"availableChannels");
  handle = [availableChannels lastObject];
  if (handle == nil)
    return nil;

  return ivarValue6082 (handle, @"channel");
}

- (void) agePooledChannelBySeconds: (NSTimeInterval) seconds
{
  NSArray *availableChannels;
  id handle;

  availableChannels = ivarValue6082 (cm, @"availableChannels");
  handle = [availableChannels lastObject];
  setIvarValue6082 (handle, @"creationTime",
                    [NSDate dateWithTimeIntervalSinceNow: -seconds]);
}

- (void) test_freshPooledChannelIsReused
{
  Test6082Channel *first, *second;

  first = [self acquireChannel];
  failIf(first == nil);
  [cm releaseChannel: (id) first];
  testEquals([self pooledChannel], first);

  second = [self acquireChannel];
  testEquals(second, first);
  testEquals([NSNumber numberWithInt: [first closeCount]],
             [NSNumber numberWithInt: 0]);
}

- (void) test_agedPooledChannelIsDiscardedInsteadOfReused
{
  NSArray *availableChannels;
  Test6082Channel *first, *second;

  first = [self acquireChannel];
  [cm releaseChannel: (id) first];
  [self agePooledChannelBySeconds: 7200];

  second = [self acquireChannel];
  failIf(second == first);
  failIf(second == nil);
  testEquals([NSNumber numberWithInt: [first closeCount]],
             [NSNumber numberWithInt: 1]);
  availableChannels = ivarValue6082 (cm, @"availableChannels");
  testEquals([NSNumber numberWithInt: [availableChannels count]],
             [NSNumber numberWithInt: 0]);
}

- (void) test_closedPooledChannelIsDiscardedInsteadOfReused
{
  Test6082Channel *first, *second;

  first = [self acquireChannel];
  [cm releaseChannel: (id) first];
  [first closeChannel];

  second = [self acquireChannel];
  failIf(second == first);
  failIf(second == nil);
  testEquals([NSNumber numberWithInt: [first closeCount]],
             [NSNumber numberWithInt: 1]);
}

- (void) test_immediateReleaseDoesNotRepoolChannel
{
  Test6082Channel *first;
  NSArray *availableChannels;

  first = [self acquireChannel];
  [cm releaseChannel: (id) first  immediately: YES];

  availableChannels = ivarValue6082 (cm, @"availableChannels");
  testEquals([NSNumber numberWithInt: [availableChannels count]],
             [NSNumber numberWithInt: 0]);
  testEquals([NSNumber numberWithInt: [first closeCount]],
             [NSNumber numberWithInt: 1]);
}

@end
