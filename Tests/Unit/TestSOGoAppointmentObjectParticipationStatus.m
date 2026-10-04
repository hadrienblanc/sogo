/* TestSOGoAppointmentObjectParticipationStatus.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 */

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalPerson.h>

#import <Appointments/SOGoAppointmentObject.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoUser.h>

#import "SOGoTest.h"

@interface SOGoUser5981Stub : SOGoUser
@end

@implementation SOGoUser5981Stub

- (NSArray *) allEmails
{
  return [NSArray arrayWithObject: @"attendee5981@example.org"];
}

- (BOOL) hasEmail: (NSString *) email
{
  return [[self allEmails] containsCaseInsensitiveString: email];
}

- (SOGoDomainDefaults *) domainDefaults
{
  return nil;
}

- (SOGoUserSettings *) userSettings
{
  return nil;
}

@end

@interface SOGoAppointmentObject5981Stub : SOGoAppointmentObject
{
  iCalCalendar *savedCalendar;
}

- (iCalCalendar *) savedCalendar;

@end

@implementation SOGoAppointmentObject5981Stub

- (void) dealloc
{
  [savedCalendar release];
  [super dealloc];
}

- (iCalCalendar *) savedCalendar
{
  return savedCalendar;
}

- (NSException *) saveComponent: (id) theComponent
                     baseVersion: (unsigned int) newVersion
{
  ASSIGN (savedCalendar, theComponent);

  return nil;
}

@end

@interface TestSOGoAppointmentObjectParticipationStatus : SOGoTest
@end

@implementation TestSOGoAppointmentObjectParticipationStatus

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

static SOGoUser5981Stub *
User5981 ()
{
  static SOGoUser5981Stub *user = nil;

  if (!user)
    {
      user = [[SOGoUser5981Stub alloc] initWithLogin: @"attendee5981"
                                                roles: nil
                                                trust: YES];
      [[SOGoCache sharedCache] registerUser: user
                                   withName: @"attendee5981"];
    }

  return user;
}

- (SOGoAppointmentObject5981Stub *) _objectWithContent: (NSString *) content
{
  SOGoAppointmentObject5981Stub *object;

  object = [SOGoAppointmentObject5981Stub objectWithName: @"test-5981.ics"
                                              andContent: content
                                             inContainer: nil];
  [object setOwner: @"attendee5981"];

  return object;
}

- (NSString *) _masterWithRrule: (NSString *) rrule
{
  NSMutableString *content;

  content = [NSMutableString stringWithString:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"
                         @"PRODID:-//Microsoft Corporation//Outlook 16.0 MIMEDIR//EN\r\n"
                         @"BEGIN:VEVENT\r\n"
                         @"UID:test-5981\r\n"
                         @"SUMMARY:OAC - Walkthrough\r\n"
                         @"DTSTART:20301105T100000Z\r\n"
                         @"DTEND:20301105T110000Z\r\n"];
  if (rrule)
    [content appendFormat: @"RRULE:%@\r\n", rrule];
  [content appendString:
                 @"ORGANIZER;CN=\"Rathish Nath\":mailto:rathish.n@azentio.example\r\n"
                 @"ATTENDEE;CN=\"Attendee\";ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:attendee5981@example.org\r\n"
                 @"END:VEVENT\r\n"
                 @"END:VCALENDAR\r\n"];

  return content;
}

- (NSCalendarDate *) _recurrenceIdOnSecondDay
{
  NSCalendarDate *recurrenceId;
  NSCalendarDate *startDate;

  startDate = [[iCalCalendar parseSingleFromSource:
                          [self _masterWithRrule: nil]]
                firstChildWithTag: @"vevent"];
  recurrenceId = [[[startDate startDate] copy] autorelease];
  [recurrenceId addTimeInterval: 86400];

  return recurrenceId;
}

- (void) test_unresolvableRecurrenceIdFallsBackOnMaster
{
  SOGoAppointmentObject5981Stub *object;
  iCalEvent *master;
  NSException *error;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  User5981 ();
  object = [self _objectWithContent: [self _masterWithRrule: nil]];

  error = [object changeParticipationStatus: @"ACCEPTED"
                                 withDelegate: nil
                                        alarm: nil
                              forRecurrenceId: [self _recurrenceIdOnSecondDay]];

  testWithMessage (error == nil, [error description]);
  master = [[object savedCalendar] firstChildWithTag: @"vevent"];
  testWithMessage ([[[master userAsAttendee: User5981 ()] partStat]
                     isEqualToString: @"ACCEPTED"],
                  @"master attendee partstat is ACCEPTED");
}

- (void) test_noRecurrenceIdUsesMaster
{
  SOGoAppointmentObject5981Stub *object;
  iCalEvent *master;
  NSException *error;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  User5981 ();
  object = [self _objectWithContent: [self _masterWithRrule: nil]];

  error = [object changeParticipationStatus: @"DECLINED"
                                 withDelegate: nil
                                        alarm: nil
                              forRecurrenceId: nil];

  testWithMessage (error == nil, [error description]);
  master = [[object savedCalendar] firstChildWithTag: @"vevent"];
  testWithMessage ([[[master userAsAttendee: User5981 ()] partStat]
                     isEqualToString: @"DECLINED"],
                  @"master attendee partstat is DECLINED");
}

- (void) test_recurrenceIdOnOccurrenceCreatesException
{
  SOGoAppointmentObject5981Stub *object;
  NSArray *events;
  iCalEvent *occurrence;
  NSException *error;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  User5981 ();
  object = [self _objectWithContent:
                     [self _masterWithRrule: @"FREQ=DAILY;COUNT=5"]];

  error = [object changeParticipationStatus: @"ACCEPTED"
                                 withDelegate: nil
                                        alarm: nil
                              forRecurrenceId: [self _recurrenceIdOnSecondDay]];

  testWithMessage (error == nil, [error description]);
  events = [[object savedCalendar] events];
  testWithMessage ([events count] == 2,
                  @"master plus exception");
  occurrence = [events objectAtIndex: 1];
  testWithMessage ([occurrence recurrenceId] != nil,
                  @"exception carries a recurrence-id");
  testWithMessage ([[[occurrence userAsAttendee: User5981 ()] partStat]
                     isEqualToString: @"ACCEPTED"],
                  @"exception attendee partstat is ACCEPTED");
  testWithMessage ([[[[events objectAtIndex: 0]
                     userAsAttendee: User5981 ()] partStat]
                     isEqualToString: @"NEEDS-ACTION"],
                  @"master attendee partstat is left untouched");
}

@end
