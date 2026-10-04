/* TestLDAPSourceUserSearchFilter.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any
 * later version.
 *
 * This file is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <EOControl/EOControl.h>
#import <SOGo/LDAPSource.h>

#import "SOGoTest.h"

@interface LDAPSource (TestUserSearchFilter)
- (EOQualifier *) _qualifierForFilter: (NSString *) filter
                           onCriteria: (NSArray *) criteria;
@end

@interface TestLDAPSourceUserSearchFilter : SOGoTest
@end

@implementation TestLDAPSourceUserSearchFilter

- (LDAPSource *) _sourceWithSearchFields: (NSArray *) searchFields
{
  NSMutableDictionary *udSource;

  udSource = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                          @"test-6002-ldap", @"id",
                          @"ldap", @"type",
                          @"ou=people,dc=example,dc=com", @"baseDN",
                          nil];
  if (searchFields)
    [udSource setObject: searchFields forKey: @"SearchFieldNames"];

  return [LDAPSource sourceFromUDSource: udSource inDomain: nil];
}

- (void) test_defaultSearchFieldsMatchSubstringsWithoutUIDField
{
  LDAPSource *source;
  NSString *description;

  source = [self _sourceWithSearchFields: nil];
  description = [[source _qualifierForFilter: @"jsmith" onCriteria: nil] description];

  testWithMessage ([description rangeOfString: @"sn = '*jsmith*'"].location != NSNotFound,
                   @"default search fields expand 'name' to sn substring clause");
  testWithMessage ([description rangeOfString: @"displayname = '*jsmith*'"].location != NSNotFound,
                   @"default search fields expand 'name' to displayname substring clause");
  testWithMessage ([description rangeOfString: @"cn = '*jsmith*'"].location != NSNotFound,
                   @"default search fields expand 'name' to cn substring clause");
  testWithMessage ([description rangeOfString: @"mail = '*jsmith*'"].location != NSNotFound,
                   @"default search fields expand 'mail' to mail substring clause");
  testWithMessage ([description rangeOfString: @"uid"].location == NSNotFound,
                   @"default search fields do not match the uid attribute (bug 6002)");
}

- (void) test_customSearchFieldsStillMatchSubstrings
{
  LDAPSource *source;
  NSString *description;

  source = [self _sourceWithSearchFields: [NSArray arrayWithObject: @"uid"]];
  description = [[source _qualifierForFilter: @"jsmith" onCriteria: nil] description];

  testWithMessage ([description rangeOfString: @"uid = '*jsmith*'"].location != NSNotFound,
                   @"a uid sent to usersSearch is matched as a substring, never "
                   @"as an exact value (bug 6002)");
}

@end
