/* TestLDAPSourceUserAddressBooks.m - this file is part of SOGo
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

#import <SOGo/LDAPSource.h>
#import <SOGo/SOGoCache.h>

#import "SOGoTest.h"

@interface LDAPSource (TestUserDNHook)
- (NSString *) _userDNForLogin: (NSString *) theLogin;
@end

@interface TestLDAPSourceUserAddressBooks : SOGoTest
@end

@implementation TestLDAPSourceUserAddressBooks

- (LDAPSource *) _sourceWithBindFields: (BOOL) hasBindFields
{
  NSMutableDictionary *udSource;

  udSource = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                          @"test-6054-ldap", @"id",
                          @"ldap", @"type",
                          @"Test 6054 Addressbook", @"displayName",
                          @"ou=people,dc=example,dc=com", @"baseDN",
                          @"uid", @"IDFieldName",
                          @"mail", @"UIDFieldName",
                          @"addressbook", @"abOU",
                          nil];
  if (hasBindFields)
    [udSource setObject: [NSArray arrayWithObject: @"mail"]
                 forKey: @"bindFields"];

  return [LDAPSource sourceFromUDSource: udSource inDomain: nil];
}

- (void) _cleanCachedDNForLogin: (NSString *) theLogin
{
  SOGoCache *cache;

  cache = [SOGoCache sharedCache];
  [cache killCache];
  [cache removeValueForKey:
            [NSString stringWithFormat: @"%@+dn", theLogin]];
}

- (void) test_userDNForLoginUsesCachedUserDNOverLogin
{
  LDAPSource *source;
  SOGoCache *cache;
  NSString *login;

  login = @"test-6054-user@example.com";
  [self _cleanCachedDNForLogin: login];

  cache = [SOGoCache sharedCache];
  [cache setDistinguishedName: @"uid=test-6054-user,ou=people,dc=example,dc=com"
                      forLogin: login];

  source = [self _sourceWithBindFields: YES];
  testWithMessage ([[source _userDNForLogin: login] isEqualToString:
                     @"uid=test-6054-user,ou=people,dc=example,dc=com"],
                   @"exuser@example.com (UIDFieldName=mail, domain-based"
                   @" uid) -> uid=test-6054-user,ou=people,dc=example,dc=com"
                   @" (IDFieldName=uid, bug 6054)");

  [self _cleanCachedDNForLogin: login];
}

- (void) test_userDNForLoginFallsBackToIDFieldWithoutBindFields
{
  LDAPSource *source;
  NSString *login;

  login = @"test-6054-direct";
  [self _cleanCachedDNForLogin: login];

  source = [self _sourceWithBindFields: NO];
  testWithMessage ([[source _userDNForLogin: login] isEqualToString:
                     @"uid=test-6054-direct,ou=people,dc=example,dc=com"],
                   @"test-6054-direct -> uid=test-6054-direct,ou=people,"
                   @"dc=example,dc=com when no bindFields are set");

  [self _cleanCachedDNForLogin: login];
}

@end
