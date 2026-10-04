/* TestSOGoAppointmentObjectConflictWindow.m - this file is part of SOGo
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>

#import <Appointments/SOGoAppointmentObject.h>

#import "SOGoTest.h"

@interface SOGoAppointmentObject (ConflictWindowTests)
+ (NSCalendarDate *) conflictCheckStartDateForEvent: (iCalEvent *) theEvent;
@end

@interface TestSOGoAppointmentObjectConflictWindow : SOGoTest
@end

@implementation TestSOGoAppointmentObjectConflictWindow

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (iCalEvent *) _weeklyEventWithStart: (NSString *) dtstart
                                  end: (NSString *) dtend
{
  iCalCalendar *calendar;

  calendar = [iCalCalendar parseSingleFromSource:
                        [NSString stringWithFormat:
                                  @"BEGIN:VCALENDAR\r\n"
                                  @"VERSION:2.0\r\n"
                                  @"BEGIN:VEVENT\r\n"
                                  @"UID:test-6075.ics\r\n"
                                  @"SUMMARY:Test\r\n"
                                  @"DTSTART;TZID=Europe/Paris:%@\r\n"
                                  @"DTEND;TZID=Europe/Paris:%@\r\n"
                                  @"RRULE:FREQ=WEEKLY;BYDAY=MO\r\n"
                                  @"END:VEVENT\r\n"
                                  @"END:VCALENDAR\r\n",
                                  dtstart, dtend]];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");

  return [[calendar events] objectAtIndex: 0];
}

- (NSString *) _wallClock: (NSCalendarDate *) theDate
{
  NSCalendarDate *parisDate;

  parisDate = [theDate copy];
  [parisDate autorelease];
  [parisDate setTimeZone: [NSTimeZone timeZoneWithName: @"Europe/Paris"]];

  return [parisDate descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S"];
}

- (void) test_futureEventStartsAtItsOwnStartDate
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _weeklyEventWithStart: @"20301105T100000"
                                  end: @"20301105T110000"];

  testEquals([self _wallClock: [SOGoAppointmentObject conflictCheckStartDateForEvent: event]],
             @"2030-11-05 10:00:01");
}

- (void) test_pastEventStartsAtCurrentTime
{
  iCalEvent *event;
  NSCalendarDate *before, *after, *result;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _weeklyEventWithStart: @"20200907T100000"
                                  end: @"20200907T110000"];

  before = [NSCalendarDate date];
  result = [SOGoAppointmentObject conflictCheckStartDateForEvent: event];
  after = [[NSCalendarDate date] dateByAddingYears: 0  months: 0  days: 0  hours: 0  minutes: 0  seconds: 1];

  testWithMessage ([result compare: before] != NSOrderedAscending,
                   @"conflict window must not start in the past");
  testWithMessage ([result compare: after] != NSOrderedDescending,
                   @"conflict window must start at the current time, not at the event start");
  testWithMessage ([[event startDate] compare: result] == NSOrderedAscending,
                   @"conflict window must not be anchored on a past start date");
}

@end
