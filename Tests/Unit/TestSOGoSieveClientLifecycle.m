/* TestSOGoSieveClientLifecycle.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <NGImap4/NGSieveClient.h>

#import <SOGo/SOGoSieveManager.h>

#import "SOGoTest.h"

@interface Test6071Account : NSObject
@end

@implementation Test6071Account

- (NSURL *) imap4URL
{
  return [NSURL URLWithString: @"imap://test-6071:secret@127.0.0.1/"];
}

- (NSString *) imap4PasswordRenewed: (BOOL) renewed
{
  return nil;
}

@end

@interface TestSOGoSieveClientLifecycle : SOGoTest
@end

@implementation TestSOGoSieveClientLifecycle

- (void) test_clientForAccountWithoutPasswordReleasesClient
{
  NSAutoreleasePool *pool;
  SOGoSieveManager *manager;
  Test6071Account *account;
  int before, after;

  GSDebugAllocationActive (YES);

  pool = [NSAutoreleasePool new];
  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];
  account = [[[Test6071Account alloc] init] autorelease];

  before = GSDebugAllocationCount ([NGSieveClient class]);
  test([manager clientForAccount: account] == nil);
  [pool release];

  after = GSDebugAllocationCount ([NGSieveClient class]);
  testWithMessage (after == before, @"sieve client leaked without password");
}

- (void) test_clientForAccountWithFailingLoginReleasesClient
{
  NSAutoreleasePool *pool;
  SOGoSieveManager *manager;
  Test6071Account *account;
  int before, after;

  GSDebugAllocationActive (YES);

  pool = [NSAutoreleasePool new];
  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];
  account = [[[Test6071Account alloc] init] autorelease];

  before = GSDebugAllocationCount ([NGSieveClient class]);
  test([manager clientForAccount: account
                    withUsername: @"test-6071"
                     andPassword: @"wrong-password"] == nil);
  [pool release];

  after = GSDebugAllocationCount ([NGSieveClient class]);
  testWithMessage (after == before, @"sieve client leaked after failed login");
}

@end
