/* TestiCalCalendarInvitationUpdate.m - this file is part of SOGo
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
#import <NGCards/iCalPerson.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoUser.h>

#import "SOGoTest.h"

@interface iCalCalendar (SOGoTestsDeclaration)
- (BOOL) applyInvitationUpdate: (iCalEvent *) newEvent
                       forUser: (SOGoUser *) user;
@end

@interface iCalEntityObject (SOGoTestsDeclaration)
- (iCalPerson *) userAsAttendee: (SOGoUser *) user;
@end

@interface SOGoUser6078Stub : SOGoUser
@end

@implementation SOGoUser6078Stub

- (NSArray *) allEmails
{
  return [NSArray arrayWithObject: @"mailbox-one@example.org"];
}

- (BOOL) hasEmail: (NSString *) email
{
  return [[self allEmails] containsCaseInsensitiveString: email];
}

@end

@interface TestiCalCalendarInvitationUpdate : SOGoTest
@end

@implementation TestiCalCalendarInvitationUpdate

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

  user = [[SOGoUser6078Stub alloc] initWithLogin: @"mailbox-one"
                                            roles: nil
                                            trust: YES];

  return [user autorelease];
}

- (iCalCalendar *) _calendarWithContent: (NSString *) content
{
  iCalCalendar *calendar;

  calendar = [iCalCalendar parseSingleFromSource: content];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");

  return calendar;
}

- (iCalCalendar *) _storedCalendarWithSequence: (NSString *) sequence
                                      dtStart: (NSString *) dtStart
                                      partStat: (NSString *) partStat
{
  NSMutableString *content;

  content = [NSMutableString stringWithString:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"
                         @"BEGIN:VEVENT\r\n"
                         @"UID:test-6078\r\n"
                         @"SUMMARY:stored invitation\r\n"];
  [content appendFormat: @"SEQUENCE:%@\r\n", sequence];
  [content appendFormat: @"DTSTART:%@\r\n", dtStart];
  [content appendString: @"DTEND:20261015T110000Z\r\n"];
  [content appendString: @"ORGANIZER;CN=Jean Dupont:mailto:jean@external.example\r\n"];
  [content appendFormat: @"ATTENDEE;CN=Mailbox One;ROLE=REQ-PARTICIPANT;PARTSTAT=%@;RSVP=TRUE:mailto:mailbox-one@example.org\r\n", partStat];
  [content appendString: @"END:VEVENT\r\n"
                        @"END:VCALENDAR\r\n"];

  return [self _calendarWithContent: content];
}

- (iCalEvent *) _updateEventWithSequence: (NSString *) sequence
                                 dtStart: (NSString *) dtStart
                                 partStat: (NSString *) partStat
                            recurrenceId: (NSString *) recurrenceId
                                   rrule: (NSString *) rrule
{
  NSMutableString *content;

  content = [NSMutableString stringWithString:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"
                         @"METHOD:REQUEST\r\n"
                         @"BEGIN:VEVENT\r\n"
                         @"UID:test-6078\r\n"
                         @"SUMMARY:updated invitation\r\n"];
  [content appendFormat: @"SEQUENCE:%@\r\n", sequence];
  [content appendFormat: @"DTSTART:%@\r\n", dtStart];
  [content appendString: @"DTEND:20261015T113000Z\r\n"];
  if (rrule)
    [content appendFormat: @"RRULE:%@\r\n", rrule];
  if (recurrenceId)
    [content appendFormat: @"RECURRENCE-ID:%@\r\n", recurrenceId];
  [content appendString: @"ORGANIZER;CN=Jean Dupont:mailto:jean@external.example\r\n"];
  [content appendFormat: @"ATTENDEE;CN=Mailbox One;ROLE=REQ-PARTICIPANT;PARTSTAT=%@;RSVP=TRUE:mailto:mailbox-one@example.org\r\n", partStat];
  [content appendString: @"END:VEVENT\r\n"
                        @"END:VCALENDAR\r\n"];

  return [[[self _calendarWithContent: content] events] objectAtIndex: 0];
}

- (void) test_newerRequestReplacesStoredMaster
{
  iCalCalendar *storedCalendar;
  iCalEvent *updateEvent, *master;
  NSCalendarDate *updateStartDate;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  storedCalendar = [self _storedCalendarWithSequence: @"0"
                                             dtStart: @"20261015T100000Z"
                                             partStat: @"NEEDS-ACTION"];
  updateEvent = [self _updateEventWithSequence: @"1"
                                       dtStart: @"20261015T140000Z"
                                       partStat: @"NEEDS-ACTION"
                                  recurrenceId: nil rrule: nil];
  updateStartDate = [updateEvent startDate];

  test ([storedCalendar applyInvitationUpdate: updateEvent
                                      forUser: [self _user]] == YES);
  test ([[storedCalendar events] count] == 1);
  master = [[storedCalendar events] objectAtIndex: 0];
  test ([[master summary] isEqualToString: @"updated invitation"]);
  test ([[master startDate] timeIntervalSinceDate: updateStartDate] == 0);
}

- (void) test_staleRequestIsIgnored
{
  iCalCalendar *storedCalendar;
  iCalEvent *master;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  storedCalendar = [self _storedCalendarWithSequence: @"2"
                                             dtStart: @"20261015T100000Z"
                                             partStat: @"NEEDS-ACTION"];

  test ([storedCalendar applyInvitationUpdate: [self _updateEventWithSequence: @"1"
                                                                      dtStart: @"20261015T140000Z"
                                                                      partStat: @"NEEDS-ACTION"
                                                                 recurrenceId: nil rrule: nil]
                                      forUser: [self _user]] == NO);
  test ([[storedCalendar events] count] == 1);
  master = [[storedCalendar events] objectAtIndex: 0];
  test ([[master summary] isEqualToString: @"stored invitation"]);
}

- (void) test_requestWithSameVersionIsIgnored
{
  iCalCalendar *storedCalendar;
  iCalEvent *master;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  storedCalendar = [self _storedCalendarWithSequence: @"1"
                                             dtStart: @"20261015T100000Z"
                                             partStat: @"NEEDS-ACTION"];

  test ([storedCalendar applyInvitationUpdate: [self _updateEventWithSequence: @"1"
                                                                      dtStart: @"20261015T140000Z"
                                                                      partStat: @"NEEDS-ACTION"
                                                                 recurrenceId: nil rrule: nil]
                                      forUser: [self _user]] == NO);
  test ([[storedCalendar events] count] == 1);
  master = [[storedCalendar events] objectAtIndex: 0];
  test ([[master summary] isEqualToString: @"stored invitation"]);
}

- (void) test_userPartStatIsPreserved
{
  iCalCalendar *storedCalendar;
  iCalEvent *updateEvent, *master;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  storedCalendar = [self _storedCalendarWithSequence: @"1"
                                             dtStart: @"20261015T100000Z"
                                             partStat: @"ACCEPTED"];
  updateEvent = [self _updateEventWithSequence: @"2"
                                       dtStart: @"20261015T140000Z"
                                       partStat: @"NEEDS-ACTION"
                                  recurrenceId: nil rrule: nil];

  test ([storedCalendar applyInvitationUpdate: updateEvent
                                      forUser: [self _user]] == YES);
  master = [[storedCalendar events] objectAtIndex: 0];
  test ([[[master userAsAttendee: [self _user]] partStat]
          isEqualToString: @"ACCEPTED"]);
}

- (void) test_recurrentUpdateShiftsExceptionRecurrenceIds
{
  NSMutableString *content;
  iCalCalendar *storedCalendar;
  iCalEvent *updateEvent, *master, *exception;
  NSCalendarDate *oldRecurrenceId;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  content = [NSMutableString stringWithString:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"
                         @"BEGIN:VEVENT\r\n"
                         @"UID:test-6078\r\n"
                         @"SUMMARY:stored invitation\r\n"
                         @"SEQUENCE:1\r\n"
                         @"DTSTART:20261015T100000Z\r\n"
                         @"DTEND:20261015T110000Z\r\n"
                         @"RRULE:FREQ=DAILY;COUNT=5\r\n"
                         @"ORGANIZER;CN=Jean Dupont:mailto:jean@external.example\r\n"
                         @"ATTENDEE;CN=Mailbox One;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:mailbox-one@example.org\r\n"
                         @"END:VEVENT\r\n"
                         @"BEGIN:VEVENT\r\n"
                         @"UID:test-6078\r\n"
                         @"SUMMARY:moved occurrence\r\n"
                         @"SEQUENCE:1\r\n"
                         @"DTSTART:20261015T110000Z\r\n"
                         @"DTEND:20261015T120000Z\r\n"
                         @"RECURRENCE-ID:20261015T110000Z\r\n"
                         @"ORGANIZER;CN=Jean Dupont:mailto:jean@external.example\r\n"
                         @"ATTENDEE;CN=Mailbox One;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:mailbox-one@example.org\r\n"
                         @"END:VEVENT\r\n"
                         @"END:VCALENDAR\r\n"];
  storedCalendar = [self _calendarWithContent: content];
  exception = [[storedCalendar events] objectAtIndex: 1];
  oldRecurrenceId = [[[exception recurrenceId] copy] autorelease];

  updateEvent = [self _updateEventWithSequence: @"2"
                                       dtStart: @"20261015T113000Z"
                                       partStat: @"NEEDS-ACTION"
                                  recurrenceId: nil
                                         rrule: @"FREQ=DAILY;COUNT=5"];

  test ([storedCalendar applyInvitationUpdate: updateEvent
                                      forUser: [self _user]] == YES);
  test ([[storedCalendar events] count] == 2);
  master = [[storedCalendar events] objectAtIndex: 0];
  test ([[master summary] isEqualToString: @"updated invitation"]);
  test ([[exception recurrenceId] timeIntervalSinceDate: oldRecurrenceId] == 5400);
}

- (void) test_exceptionRequestIsIgnored
{
  iCalCalendar *storedCalendar;
  iCalEvent *master;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  storedCalendar = [self _storedCalendarWithSequence: @"1"
                                             dtStart: @"20261015T100000Z"
                                             partStat: @"NEEDS-ACTION"];

  test ([storedCalendar applyInvitationUpdate: [self _updateEventWithSequence: @"2"
                                                                      dtStart: @"20261015T140000Z"
                                                                      partStat: @"NEEDS-ACTION"
                                                                 recurrenceId: @"20261015T110000Z"
                                                                        rrule: nil]
                                      forUser: [self _user]] == NO);
  test ([[storedCalendar events] count] == 1);
  master = [[storedCalendar events] objectAtIndex: 0];
  test ([[master summary] isEqualToString: @"stored invitation"]);
}

@end
