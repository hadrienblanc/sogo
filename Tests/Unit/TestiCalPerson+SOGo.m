/* TestiCalPerson+SOGo.m - this file is part of SOGo
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
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUser.h>

#import "SOGoTest.h"

@class WOContext;

@interface iCalPerson (SOGoTestsDeclaration)
- (NSString *) uid;
- (NSString *) uidForUser: (SOGoUser *) user;
- (NSString *) uidInContext: (WOContext *) context;
@end

@interface iCalEntityObject (SOGoTestsDeclaration)
- (NSArray *) attendeesWithoutUser: (SOGoUser *) user;
- (NSDictionary *) attributesInContext: (WOContext *) context;
@end

@interface SOGoUser6144Stub : SOGoUser
@end

@implementation SOGoUser6144Stub

- (NSArray *) allEmails
{
  return [NSArray arrayWithObjects: @"mailbox-one@example.org",
                                   @"test-6144-alias@example.org",
                                   nil];
}

- (BOOL) hasEmail: (NSString *) email
{
  return [[self allEmails] containsCaseInsensitiveString: email];
}

@end

@interface TestiCalPerson_plus_SOGo : SOGoTest
@end

@implementation TestiCalPerson_plus_SOGo

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (void) setUp
{
  /* The reverse email lookups reach SOGoUserManager and its cache;
     without a server list libmemcached aborts on a NULL host. */
  [[NSUserDefaults standardUserDefaults]
    registerDefaults: [NSDictionary dictionaryWithObject: @"127.0.0.1:11211"
                                                  forKey: @"SOGoMemcachedHost"]];
}

- (SOGoUser *) _user
{
  SOGoUser *user;

  user = [[SOGoUser6144Stub alloc] initWithLogin: @"mailbox-one"
                                           roles: nil
                                           trust: YES];

  return [user autorelease];
}

- (WOContext *) _contextWithUser
{
  WOContext *context;

  context = [WOContext contextWithRequest: nil];
  [context setActiveUser: [self _user]];

  return context;
}

- (iCalEvent *) _eventWithOrganizer: (NSString *) organizer
                         attendees: (NSArray *) attendeeEmails
{
  NSMutableString *content;
  iCalCalendar *calendar;
  NSUInteger i;

  content = [NSMutableString stringWithString:
                       @"BEGIN:VCALENDAR\r\n"
                       @"VERSION:2.0\r\n"
                       @"BEGIN:VEVENT\r\n"
                       @"UID:test-6144\r\n"
                       @"SUMMARY:test 6144\r\n"
                       @"DTSTART:20261015T100000Z\r\n"
                       @"DTEND:20261015T110000Z\r\n"];
  [content appendFormat: @"ORGANIZER;CN=Mailbox One:mailto:%@\r\n", organizer];

  for (i = 0; i < [attendeeEmails count]; i++)
    [content appendFormat:
      @"ATTENDEE;CN=Guest;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION:mailto:%@\r\n",
      [attendeeEmails objectAtIndex: i]];

  [content appendString:
              @"END:VEVENT\r\n"
              @"END:VCALENDAR\r\n"];

  calendar = [iCalCalendar parseSingleFromSource: content];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");

  return [[calendar events] objectAtIndex: 0];
}

- (void) test_uidForUserPrefersUserOwningTheAlias
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithOrganizer: @"test-6144-alias@example.org"
                          attendees: [NSArray array]];

  testEquals ([[event organizer] uidForUser: [self _user]], @"mailbox-one");
}

- (void) test_uidForUserFallsBackOnForeignEmail
{
  iCalEvent *event;
  iCalPerson *organizer;
  NSString *uid;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithOrganizer: @"test-6144-foreign@example.org"
                          attendees: [NSArray array]];
  organizer = [event organizer];

  uid = [organizer uidForUser: [self _user]];
  testWithMessage (![uid isEqualToString: @"mailbox-one"],
                   @"an address the user does not own must never resolve "
                   @"to that user");
  testEquals (uid, [organizer uid]);
}

- (void) test_uidInContextResolvesOwnAliasToActiveUser
{
  WOContext *context;
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  context = [self _contextWithUser];
  event = [self _eventWithOrganizer: @"test-6144-alias@example.org"
                          attendees: [NSArray array]];

  testEquals ([[event organizer] uidInContext: context], @"mailbox-one");
}

- (void) test_uidInContextIgnoresForeignEmail
{
  WOContext *context;
  iCalEvent *event;
  NSString *uid;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  context = [self _contextWithUser];
  event = [self _eventWithOrganizer: @"test-6144-foreign@example.org"
                          attendees: [NSArray array]];

  uid = [[event organizer] uidInContext: context];
  testWithMessage (![uid isEqualToString: @"mailbox-one"],
                   @"an address the active user does not own must never "
                   @"resolve to that user");
}

- (void) test_attendeesWithoutUserDropsAttendeeWithOwnAlias
{
  iCalEvent *event;
  NSArray *attendees;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithOrganizer: @"test-6144-alias@example.org"
                          attendees: [NSArray arrayWithObjects:
                                        @"test-6144-alias@example.org",
                                        @"test-6144-guest@example.org",
                                        nil]];
  attendees = [event attendeesWithoutUser: [self _user]];

  testWithMessage ([attendees count] == 1,
                   @"an attendee entry using an address owned by the user "
                   @"is the user themself and must be filtered out");
  if ([attendees count] == 1)
    testEquals ([[[attendees objectAtIndex: 0] rfc822Email]
                  lowercaseString],
                @"test-6144-guest@example.org");
}

- (void) test_attendeesWithoutUserKeepsForeignAttendees
{
  iCalEvent *event;
  NSArray *attendees;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithOrganizer: @"test-6144-alias@example.org"
                          attendees: [NSArray arrayWithObjects:
                                        @"test-6144-guest@example.org",
                                        @"test-6144-guest2@example.org",
                                        nil]];
  attendees = [event attendeesWithoutUser: [self _user]];

  testWithMessage ([attendees count] == 2,
                   @"attendees not related to the user must be kept");
}

- (void) test_attributesExposeOrganizerUidOfActiveUser
{
  WOContext *context;
  iCalEvent *event;
  NSDictionary *data, *organizer;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  context = [self _contextWithUser];
  event = [self _eventWithOrganizer: @"test-6144-alias@example.org"
                          attendees: [NSArray arrayWithObject:
                                        @"test-6144-guest@example.org"]];
  data = [event attributesInContext: context];

  organizer = [data objectForKey: @"organizer"];
  testWithMessage (organizer != nil, @"the organizer must be exposed");
  if (organizer)
    testEquals ([organizer objectForKey: @"uid"], @"mailbox-one");
}

- (void) test_attributesOmitOrganizerUidWithoutOwner
{
  iCalEvent *event;
  NSDictionary *data, *organizer;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithOrganizer: @"test-6144-foreign@example.org"
                          attendees: [NSArray arrayWithObject:
                                        @"test-6144-guest@example.org"]];
  data = [event attributesInContext: nil];

  organizer = [data objectForKey: @"organizer"];
  testWithMessage (organizer != nil,
                   @"the organizer must be exposed without a context");
  if (organizer)
    test ([organizer objectForKey: @"uid"] == nil);
}

@end
