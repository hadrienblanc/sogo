/* TestSOGoCacheACLs.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any
 * later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <SOGo/SOGoCache.h>

#import "SOGoTest.h"

@interface TestSOGoCacheACLs : SOGoTest
@end

@implementation TestSOGoCacheACLs

- (NSString *) _aclPath
{
  return @"sogotest1/Calendar/test-6171-folder";
}

- (void) test_setACLsThenInvalidate
{
  SOGoCache *cache;
  NSString *path;
  NSDictionary *acls;

  cache = [SOGoCache sharedCache];
  path = [self _aclPath];
  acls = [NSDictionary dictionaryWithObject:
                       [NSArray arrayWithObject: @"ObjectViewer"]
                                   forKey: @"sogotest2"];

  [cache setACLs: acls forPath: path];
  testWithMessage ([[cache aclsForPath: path] isEqual: acls],
                   @"cached ACLs could not be read back");

  [cache setACLs: nil forPath: path];
  testWithMessage ([cache aclsForPath: path] == nil,
                   @"ACLs are still served after invalidation (bug 6171)");
}

- (void) test_invalidateUnknownPathIsHarmless
{
  SOGoCache *cache;

  cache = [SOGoCache sharedCache];

  [cache setACLs: nil forPath: [self _aclPath]];

  testWithMessage ([cache aclsForPath: [self _aclPath]] == nil,
                   @"invalidating an uncached ACL path must not resurrect"
                   @" entries");
}

@end
