/* TestiCalRepeatableEntityObjectInvitation.m - this file is part of SOGo
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUser.h>

#import "SOGoTest.h"

@interface iCalRepeatableEntityObject (SOGoTestsDeclaration)
- (BOOL) isInvitationRequestForUser: (SOGoUser *) user;
@end

@interface SOGoUser6112Stub : SOGoUser
@end

@implementation SOGoUser6112Stub

- (NSArray *) allEmails
{
  return [NSArray arrayWithObject: @"mailbox-one@example.org"];
}

- (BOOL) hasEmail: (NSString *) email
{
  return [[self allEmails] containsCaseInsensitiveString: email];
}

@end

@interface SOGoUser6112OrganizerStub : SOGoUser6112Stub
@end

@implementation SOGoUser6112OrganizerStub

- (NSArray *) allEmails
{
  return [NSArray arrayWithObject: @"jean@external.example"];
}

@end

@interface SOGoUser6112OutsiderStub : SOGoUser6112Stub
@end

@implementation SOGoUser6112OutsiderStub

- (NSArray *) allEmails
{
  return [NSArray arrayWithObject: @"outsider@example.org"];
}

@end

@interface TestiCalRepeatableEntityObjectInvitation : SOGoTest
@end

@implementation TestiCalRepeatableEntityObjectInvitation

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (void) setUp
{
  [[NSUserDefaults standardUserDefaults]
    registerDefaults: [NSDictionary dictionaryWithObject: @"127.0.0.1:11211"
                                                  forKey: @"SOGoMemcachedHost"]];
}

- (SOGoUser *) _user
{
  SOGoUser *user;

  user = [[SOGoUser6112Stub alloc] initWithLogin: @"mailbox-one"
                                           roles: nil
                                           trust: YES];

  return [user autorelease];
}

- (iCalEvent *) _invitationWithMethod: (NSString *) method
                          recurrenceId: (NSString *) recurrenceId
{
  NSMutableString *content;
  iCalCalendar *calendar;

  content = [NSMutableString stringWithString:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"];
  if (method)
    [content appendFormat: @"METHOD:%@\r\n", method];
  [content appendString:
              @"BEGIN:VEVENT\r\n"
              @"UID:test-6112\r\n"
              @"SUMMARY:test 6112\r\n"
              @"DTSTART:20261015T100000Z\r\n"
              @"DTEND:20261015T110000Z\r\n"
              @"ORGANIZER;CN=Jean Dupont:mailto:jean@external.example\r\n"
              @"ATTENDEE;CN=Mailbox One;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:mailbox-one@example.org\r\n"];
  if (recurrenceId)
    [content appendFormat: @"RECURRENCE-ID:%@\r\n", recurrenceId];
  [content appendString:
              @"END:VEVENT\r\n"
              @"END:VCALENDAR\r\n"];

  calendar = [iCalCalendar parseSingleFromSource: content];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");

  return [[calendar events] objectAtIndex: 0];
}

- (void) test_requestForAttendeeIsInvitationRequest
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _invitationWithMethod: @"REQUEST"
                          recurrenceId: nil];

  test ([event isInvitationRequestForUser: [self _user]] == YES);
}

- (void) test_methodComparisonIsCaseInsensitive
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _invitationWithMethod: @"request"
                          recurrenceId: nil];

  test ([event isInvitationRequestForUser: [self _user]] == YES);
}

- (void) test_missingMethodIsNotInvitationRequest
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _invitationWithMethod: nil
                          recurrenceId: nil];

  test ([event isInvitationRequestForUser: [self _user]] == NO);
}

- (void) test_publishIsNotInvitationRequest
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _invitationWithMethod: @"PUBLISH"
                          recurrenceId: nil];

  test ([event isInvitationRequestForUser: [self _user]] == NO);
}

- (void) test_replyIsNotInvitationRequest
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _invitationWithMethod: @"REPLY"
                          recurrenceId: nil];

  test ([event isInvitationRequestForUser: [self _user]] == NO);
}

- (void) test_cancelIsNotInvitationRequest
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _invitationWithMethod: @"CANCEL"
                          recurrenceId: nil];

  test ([event isInvitationRequestForUser: [self _user]] == NO);
}

- (void) test_recurrenceExceptionIsNotInvitationRequest
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _invitationWithMethod: @"REQUEST"
                          recurrenceId: @"20261015T100000Z"];

  test ([event isInvitationRequestForUser: [self _user]] == NO);
}

- (void) test_organizerIsNotInvited
{
  iCalEvent *event;
  SOGoUser *organizerUser;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _invitationWithMethod: @"REQUEST"
                          recurrenceId: nil];
  organizerUser = [[SOGoUser6112OrganizerStub alloc] initWithLogin: @"jean"
                                                             roles: nil
                                                             trust: YES];
  [organizerUser autorelease];

  test ([event isInvitationRequestForUser: organizerUser] == NO);
}

- (void) test_outsiderIsNotInvited
{
  iCalEvent *event;
  SOGoUser *outsiderUser;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _invitationWithMethod: @"REQUEST"
                          recurrenceId: nil];
  outsiderUser = [[SOGoUser6112OutsiderStub alloc] initWithLogin: @"outsider"
                                                           roles: nil
                                                           trust: YES];
  [outsiderUser autorelease];

  test ([event isInvitationRequestForUser: outsiderUser] == NO);
}

@end
