/* TestSOGoUserFolderCalendarUserAddressSet.m - this file is part of SOGo
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
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <Appointments/SOGoUserFolder+Appointments.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoUser.h>

#import "SOGoTest.h"

@interface SOGoUser5962Stub : SOGoUser
{
  NSArray *emails;
}

+ (SOGoUser5962Stub *) registeredUserWithLogin: (NSString *) login
                                        emails: (NSArray *) theEmails;

@end

@implementation SOGoUser5962Stub

+ (SOGoUser5962Stub *) registeredUserWithLogin: (NSString *) login
                                       emails: (NSArray *) theEmails
{
  SOGoUser5962Stub *user;

  user = [[[self alloc] initWithLogin: login
                                roles: nil
                                trust: YES] autorelease];
  [user setEmails: theEmails];
  [[SOGoCache sharedCache] registerUser: user
                               withName: login];

  return user;
}

- (void) dealloc
{
  [emails release];

  [super dealloc];
}

- (void) setEmails: (NSArray *) theEmails
{
  if (emails != theEmails)
    {
      [emails release];
      emails = [theEmails retain];
    }
}

- (NSArray *) allEmails
{
  return emails;
}

- (SOGoDomainDefaults *) domainDefaults
{
  return nil;
}

@end

@interface TestSOGoUserFolderCalendarUserAddressSet : SOGoTest
@end

@implementation TestSOGoUserFolderCalendarUserAddressSet

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (SOGoUserFolder *) _userFolderWithOwner: (NSString *) login
{
  SOGoUserFolder *folder;

  folder = [[[SOGoUserFolder alloc] init] autorelease];
  [folder setOwner: login];
  [folder setNameInContainer: login];

  return folder;
}

- (void) test_primaryEmailIsTheLastMailtoEntryOfTheAddressSet
{
  NSArray *addressSet;

  LoadAppointmentsBundle ();
  [SOGoUser5962Stub registeredUserWithLogin: @"test-5962-owner"
                                     emails: [NSArray arrayWithObjects:
                                                       @"test-5962@example.org",
                                                       @"alias-one.5962@example.org",
                                                       @"alias-two.5962@example.org",
                                                       nil]];
  addressSet = [[self _userFolderWithOwner: @"test-5962-owner"]
                  davCalendarUserAddressSet];

  testEquals ([NSNumber numberWithInt: [addressSet count]],
              [NSNumber numberWithInt: 4]);
  testEquals ([[addressSet objectAtIndex: 0] objectAtIndex: 3],
              @"mailto:alias-one.5962@example.org");
  testEquals ([[addressSet objectAtIndex: 1] objectAtIndex: 3],
              @"mailto:alias-two.5962@example.org");
  testEquals ([[addressSet objectAtIndex: 2] objectAtIndex: 3],
              @"mailto:test-5962@example.org");
  testEquals ([[addressSet objectAtIndex: 3] objectAtIndex: 3],
              @"/SOGo/dav/test-5962-owner/");
}

- (void) test_primaryEmailStaysTheOnlyMailtoForSingleEmailUsers
{
  NSArray *addressSet;

  LoadAppointmentsBundle ();
  [SOGoUser5962Stub registeredUserWithLogin: @"test-5962-single"
                                     emails: [NSArray arrayWithObject:
                                                       @"test-5962@example.org"]];
  addressSet = [[self _userFolderWithOwner: @"test-5962-single"]
                  davCalendarUserAddressSet];

  testEquals ([NSNumber numberWithInt: [addressSet count]],
              [NSNumber numberWithInt: 2]);
  testEquals ([[addressSet objectAtIndex: 0] objectAtIndex: 3],
              @"mailto:test-5962@example.org");
  testEquals ([[addressSet objectAtIndex: 1] objectAtIndex: 3],
              @"/SOGo/dav/test-5962-single/");
}

- (void) test_duplicatedEmailsAppearOnlyOnce
{
  NSArray *addressSet;

  LoadAppointmentsBundle ();
  [SOGoUser5962Stub registeredUserWithLogin: @"test-5962-dup"
                                     emails: [NSArray arrayWithObjects:
                                                       @"test-5962@example.org",
                                                       @"alias.5962@example.org",
                                                       @"test-5962@example.org",
                                                       nil]];
  addressSet = [[self _userFolderWithOwner: @"test-5962-dup"]
                  davCalendarUserAddressSet];

  testEquals ([NSNumber numberWithInt: [addressSet count]],
              [NSNumber numberWithInt: 3]);
  testEquals ([[addressSet objectAtIndex: 0] objectAtIndex: 3],
              @"mailto:alias.5962@example.org");
  testEquals ([[addressSet objectAtIndex: 1] objectAtIndex: 3],
              @"mailto:test-5962@example.org");
  testEquals ([[addressSet objectAtIndex: 2] objectAtIndex: 3],
              @"/SOGo/dav/test-5962-dup/");
}

@end
