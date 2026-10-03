/* TestSOGoCacheLifecycle.m - this file is part of SOGo
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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoUser.h>

#import "SOGoTest.h"

@interface TestSOGoCacheLifecycle : SOGoTest
@end

@implementation TestSOGoCacheLifecycle

- (NSString *) _login
{
  return @"test-6080-user";
}

- (void) test_registeredUsersAreFlushedOnKillCache
{
  SOGoCache *cache;
  SOGoUser *user;

  cache = [SOGoCache sharedCache];
  user = [SOGoUser userWithLogin: @"anonymous"];

  [cache registerUser: user withName: [self _login]];
  testWithMessage ([cache userNamed: [self _login]] == user,
                   @"registered user must be served from the request cache");

  [cache killCache];
  testWithMessage ([cache userNamed: [self _login]] == nil,
                   @"registered users must be dropped when the request"
                   @" cache is flushed");
}

- (void) test_userAttributesLifecycleAcrossKillCache
{
  SOGoCache *cache;
  NSString *login, *value;

  cache = [SOGoCache sharedCache];
  login = [self _login];
  value = @"{\"c_uid\":\"test-6080-user\",\"cn\":\"Test 6080\"}";

  [cache setUserAttributes: value forLogin: login];
  testWithMessage ([[cache userAttributesForLogin: login] isEqualToString: value],
                   @"cached user attributes could not be read back");

  [cache killCache];
  [cache removeValueForKey: [NSString stringWithFormat: @"%@+attributes", login]];
  testWithMessage ([cache userAttributesForLogin: login] == nil,
                   @"user attributes must not be served after a request-cache"
                   @" flush followed by an invalidation");
}

- (void) test_invalidateUnknownLoginIsHarmless
{
  SOGoCache *cache;

  cache = [SOGoCache sharedCache];

  [cache killCache];
  [cache removeValueForKey:
             [NSString stringWithFormat: @"%@+attributes", [self _login]]];

  testWithMessage ([cache userAttributesForLogin: [self _login]] == nil,
                   @"invalidating an unknown login must not resurrect"
                   @" entries");
}

@end
