/* TestSOGoCalendarComponentCopy.m - this file is part of SOGo
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

#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalAlarm.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>

#import <Appointments/SOGoAppointmentObject.h>
#import <Appointments/SOGoAppointmentFolder.h>

#import "SOGoTest.h"

static iCalCalendar *test6070SavedCalendar = nil;
static NSString *test6070SavedName = nil;

@interface Test6070CalendarComponent : SOGoAppointmentObject
@end

@implementation Test6070CalendarComponent

- (NSException *) saveCalendar: (iCalCalendar *) newCalendar
{
  ASSIGN (test6070SavedCalendar, newCalendar);
  ASSIGN (test6070SavedName, [self nameInContainer]);

  return nil;
}

- (void) sendReceiptEmailForObject: (iCalEntityObject *) object
                    addedAttendees: (NSArray *) addedAttendees
                  deletedAttendees: (NSArray *) deletedAttendees
                  updatedAttendees: (NSArray *) updatedAttendees
                         operation: (SOGoComponentOperation) operation
{
}

@end

@interface TestSOGoCalendarComponentCopy : SOGoTest
{
  SOGoAppointmentFolder *sourceFolder;
  SOGoAppointmentFolder *destinationFolder;
  Test6070CalendarComponent *sourceEvent;
}

@end

@implementation TestSOGoCalendarComponentCopy

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (void) setUp
{
  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  sourceFolder = [[SOGoAppointmentFolder objectWithName: @"test-6070-source"
                                          inContainer: nil] retain];
  destinationFolder = [[SOGoAppointmentFolder objectWithName: @"test-6070-dest"
                                                inContainer: nil] retain];
  sourceEvent = [[Test6070CalendarComponent objectWithName: @"test-6070-event.ics"
                                             inContainer: sourceFolder] retain];
  ASSIGN (test6070SavedCalendar, nil);
  ASSIGN (test6070SavedName, nil);
}

- (void) tearDown
{
  [sourceEvent release];
  [destinationFolder release];
  [sourceFolder release];
  [test6070SavedCalendar release];
  test6070SavedCalendar = nil;
  [test6070SavedName release];
  test6070SavedName = nil;
}

- (void) _assertCopiedEvent
{
  iCalEvent *savedEvent;

  testWithMessage (test6070SavedCalendar != nil,
                   @"copy must save a calendar in the destination folder");
  if (!test6070SavedCalendar)
    return;

  testWithMessage ([[test6070SavedCalendar events] count] == 1,
                   @"copied calendar must hold exactly one event");
  if ([[test6070SavedCalendar events] count] != 1)
    return;

  savedEvent = [[test6070SavedCalendar events] objectAtIndex: 0];
  testEquals([savedEvent uid],
             [test6070SavedName stringByDeletingPathExtension]);
  testWithMessage ([[savedEvent alarms] count] == 1,
                   @"copied event must keep its reminder (bug 6070)");
  if ([[savedEvent alarms] count] != 1)
    return;

  testEquals([[[[savedEvent alarms] objectAtIndex: 0] action] uppercaseString],
             @"DISPLAY");
  testWithMessage ([[[savedEvent alarms] objectAtIndex: 0] trigger] != nil,
                   @"copied alarm must keep its trigger");
}

- (void) test_copyComponentPreservesAlarm
{
  iCalCalendar *calendar;
  NSException *ex;

  calendar = [iCalCalendar parseSingleFromSource:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"
                         @"BEGIN:VEVENT\r\n"
                         @"UID:test-6070-event\r\n"
                         @"SUMMARY:test-6070-event\r\n"
                         @"DTSTART:20301105T100000Z\r\n"
                         @"DTEND:20301105T110000Z\r\n"
                         @"BEGIN:VALARM\r\n"
                         @"ACTION:DISPLAY\r\n"
                         @"TRIGGER:-PT15M\r\n"
                         @"DESCRIPTION:Reminder\r\n"
                         @"END:VALARM\r\n"
                         @"END:VEVENT\r\n"
                         @"END:VCALENDAR\r\n"];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");

  ex = [sourceEvent copyComponent: calendar
                         toFolder: destinationFolder];

  testEquals(ex, nil);
  [self _assertCopiedEvent];
}

- (void) test_copyComponentPreservesAlarmAfterCopySanitization
{
  iCalCalendar *calendar;
  iCalEvent *event;
  NSException *ex;

  calendar = [iCalCalendar parseSingleFromSource:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"
                         @"BEGIN:VEVENT\r\n"
                         @"UID:test-6070-recurrent\r\n"
                         @"SUMMARY:test-6070-recurrent\r\n"
                         @"DTSTART:20301105T100000Z\r\n"
                         @"DTEND:20301105T110000Z\r\n"
                         @"RRULE:FREQ=WEEKLY;BYDAY=MO\r\n"
                         @"ORGANIZER:mailto:organizer@example.org\r\n"
                         @"ATTENDEE:mailto:attendee@example.org\r\n"
                         @"BEGIN:VALARM\r\n"
                         @"ACTION:DISPLAY\r\n"
                         @"TRIGGER:-PT30M\r\n"
                         @"DESCRIPTION:Reminder\r\n"
                         @"END:VALARM\r\n"
                         @"END:VEVENT\r\n"
                         @"END:VCALENDAR\r\n"];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");
  event = [[calendar events] objectAtIndex: 0];

  [event removeAllExceptionRules];
  [event removeAllExceptionDates];
  [event setOrganizer: nil];
  [event removeAllAttendees];
  [calendar setUniqueChild: event];

  ex = [sourceEvent copyComponent: calendar
                         toFolder: destinationFolder];

  testEquals(ex, nil);
  [self _assertCopiedEvent];
}

@end
