/* TestSOGoUserManagerSources.m - this file is part of SOGo
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
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#import <SOGo/SOGoUserManager.h>

#import "SOGoTest.h"

@interface SOGoUserManager (TestSourceRegistration)
- (BOOL) _registerSource: (NSDictionary *) udSource
                 inDomain: (NSString *) domain;
@end

@interface TestSOGoUserManagerSources : SOGoTest
{
  SOGoUserManager *userManager;
}
@end

@implementation TestSOGoUserManagerSources

- (id) init
{
  NSDictionary *authSource, *addressBookSource;

  if ((self = [super init]))
    {
      authSource = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"test-6092-auth", @"id",
                                 @"sql", @"type",
                                 @"mysql://127.0.0.1/sogo/test_6092_auth", @"viewURL",
                                 [NSNumber numberWithBool: YES], @"canAuthenticate",
                                 [NSNumber numberWithBool: NO], @"isAddressBook",
                                 nil];
      addressBookSource = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"test-6092-gal", @"id",
                                    @"sql", @"type",
                                    @"mysql://127.0.0.1/sogo/test_6092_gal", @"viewURL",
                                    @"Test 6092 GAL", @"displayName",
                                    [NSNumber numberWithBool: NO], @"canAuthenticate",
                                    [NSNumber numberWithBool: YES], @"isAddressBook",
                                    nil];

      userManager = [[SOGoUserManager alloc] init];
      [userManager _registerSource: authSource inDomain: nil];
      [userManager _registerSource: addressBookSource inDomain: nil];
    }

  return self;
}

- (void) dealloc
{
  [userManager release];

  [super dealloc];
}

- (void) test_authenticationSourceIDsInDomainIncludesAuthenticationSource
{
  testWithMessage ([[userManager authenticationSourceIDsInDomain: nil]
                     containsObject: @"test-6092-auth"],
                   @"a source declared with canAuthenticate = YES must be "
                   @"searchable for users");
}

- (void) test_authenticationSourceIDsInDomainExcludesAddressBookOnlySource
{
  testWithMessage (![[userManager authenticationSourceIDsInDomain: nil]
                      containsObject: @"test-6092-gal"],
                   @"a source declared with canAuthenticate = NO must not be "
                   @"searchable for users");
}

- (void) test_addressBookSourceIDsInDomainIncludesAddressBookSource
{
  testWithMessage ([[userManager addressBookSourceIDsInDomain: nil]
                     containsObject: @"test-6092-gal"],
                   @"a source declared with isAddressBook = YES must be "
                   @"searchable for contacts");
}

- (void) test_addressBookSourceIDsInDomainExcludesPrivateAuthenticationSource
{
  testWithMessage (![[userManager addressBookSourceIDsInDomain: nil]
                      containsObject: @"test-6092-auth"],
                   @"a source declared with isAddressBook = NO must not be "
                   @"searchable for contacts");
}

- (void) test_isAddressBookSourceAnswersYESForAddressBookSource
{
  testWithMessage ([userManager isAddressBookSource:
                     [userManager sourceWithID: @"test-6092-gal"]] == YES,
                   @"isAddressBookSource must answer YES for a source "
                   @"declared with isAddressBook = YES");
}

- (void) test_isAddressBookSourceAnswersNOForPrivateAuthenticationSource
{
  testWithMessage ([userManager isAddressBookSource:
                     [userManager sourceWithID: @"test-6092-auth"]] == NO,
                   @"isAddressBookSource must answer NO for a source declared "
                   @"with isAddressBook = NO (bug 6092)");
}

- (void) test_isAddressBookSourceAnswersNOForUnknownObject
{
  testWithMessage ([userManager isAddressBookSource: (id) @"not-a-source"] == NO,
                   @"isAddressBookSource must answer NO for an unregistered "
                   @"object");
}

- (void) test_isAddressBookSourceAnswersNOForNil
{
  testWithMessage ([userManager isAddressBookSource: nil] == NO,
                   @"isAddressBookSource must answer NO for a nil source");
}

@end
