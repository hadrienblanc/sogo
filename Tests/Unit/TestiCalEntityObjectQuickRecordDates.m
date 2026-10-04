/* TestiCalEntityObjectQuickRecordDates.m - this file is part of SOGo
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
 * along with this program; if not, see <http://www.gnu.org/licenses/>.
 */

#include <limits.h>

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSTimeZone.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalRepeatableEntityObject.h>

#import "SOGoTest.h"

@interface iCalEntityObject (SOGoTestsDeclaration)
- (NSNumber *) quickRecordDateAsNumber: (NSCalendarDate *) _date
                            withOffset: (int) offset
                             forAllDay: (BOOL) allDay;
@end

@interface TestiCalEntityObjectQuickRecordDates : SOGoTest
@end

@implementation TestiCalEntityObjectQuickRecordDates

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (NSCalendarDate *) _gmtDateWithYear: (int) year
                                month: (int) month
                                  day: (int) day
{
  NSCalendarDate *date;

  date = [NSCalendarDate dateWithYear: year month: month day: day
                                 hour: 0 minute: 0 second: 0
                             timeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];

  return date;
}

- (void) test_quickRecordDateNumberForEpochsInsideInt32Range
{
  iCalEvent *event;
  NSCalendarDate *date;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [iCalEvent new];
  [event autorelease];

  date = [self _gmtDateWithYear: 2024 month: 9 day: 10];
  testEquals ([event quickRecordDateAsNumber: date
                                 withOffset: 0
                                  forAllDay: NO],
              [NSNumber numberWithInt: 1725926400]);

  date = [self _gmtDateWithYear: 2037 month: 9 day: 10];
  testEquals ([event quickRecordDateAsNumber: date
                                 withOffset: 0
                                  forAllDay: NO],
              [NSNumber numberWithInt: 2136153600]);

  date = [self _gmtDateWithYear: 2038 month: 1 day: 19];
  testEquals ([event quickRecordDateAsNumber: date
                                 withOffset: 0
                                  forAllDay: NO],
              [NSNumber numberWithInt: 2147472000]);
}

- (void) test_quickRecordDateNumberClampsEpochsBeyondInt32Range
{
  iCalEvent *event;
  NSCalendarDate *date;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [iCalEvent new];
  [event autorelease];

  date = [self _gmtDateWithYear: 2038 month: 1 day: 20];
  testEquals ([event quickRecordDateAsNumber: date
                                 withOffset: 0
                                  forAllDay: NO],
              [NSNumber numberWithInt: INT_MAX]);

  date = [self _gmtDateWithYear: 2038 month: 9 day: 10];
  testEquals ([event quickRecordDateAsNumber: date
                                 withOffset: 0
                                  forAllDay: NO],
              [NSNumber numberWithInt: INT_MAX]);

  date = [self _gmtDateWithYear: 2054 month: 9 day: 10];
  testEquals ([event quickRecordDateAsNumber: date
                                 withOffset: 0
                                  forAllDay: NO],
              [NSNumber numberWithInt: INT_MAX]);

  date = [self _gmtDateWithYear: 2054 month: 9 day: 10];
  testEquals ([event quickRecordDateAsNumber: date
                                 withOffset: 0
                                  forAllDay: YES],
              [NSNumber numberWithInt: INT_MAX]);
}

- (void) test_cycleEndDateForYearlyRuleEndingBeyond2038
{
  iCalCalendar *calendar;
  iCalEvent *event;
  NSCalendarDate *lastStart;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  calendar = [iCalCalendar parseSingleFromSource:
                          @"BEGIN:VCALENDAR\r\n"
                          @"VERSION:2.0\r\n"
                          @"BEGIN:VEVENT\r\n"
                          @"UID:test-6032-yearly-until-2054\r\n"
                          @"SUMMARY:Test\r\n"
                          @"DTSTART;VALUE=DATE:20240910\r\n"
                          @"DTEND;VALUE=DATE:20240911\r\n"
                          @"RRULE:FREQ=YEARLY;UNTIL=20540910\r\n"
                          @"END:VEVENT\r\n"
                          @"END:VCALENDAR\r\n"];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");
  event = [[calendar events] objectAtIndex: 0];

  lastStart = [event lastPossibleRecurrenceStartDate];
  testWithMessage (lastStart != nil, @"yearly rule with UNTIL must expose a last start date");
  testEquals ([lastStart descriptionWithCalendarFormat: @"%Y%m%dT%H%M%SZ"],
              @"20540910T000000Z");

  testEquals ([event quickRecordDateAsNumber: lastStart
                                 withOffset: 0
                                  forAllDay: NO],
              [NSNumber numberWithInt: INT_MAX]);
}

- (void) test_cycleEndDateForYearlyCountRuleEndingBeyond2038
{
  iCalCalendar *calendar;
  iCalEvent *event;
  NSCalendarDate *lastStart;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  calendar = [iCalCalendar parseSingleFromSource:
                          @"BEGIN:VCALENDAR\r\n"
                          @"VERSION:2.0\r\n"
                          @"BEGIN:VEVENT\r\n"
                          @"UID:test-6032-yearly-count-31\r\n"
                          @"SUMMARY:Test\r\n"
                          @"DTSTART;VALUE=DATE:20240910\r\n"
                          @"DTEND;VALUE=DATE:20240911\r\n"
                          @"RRULE:FREQ=YEARLY;COUNT=31\r\n"
                          @"END:VEVENT\r\n"
                          @"END:VCALENDAR\r\n"];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");
  event = [[calendar events] objectAtIndex: 0];

  lastStart = [event lastPossibleRecurrenceStartDate];
  testWithMessage (lastStart != nil, @"yearly rule with COUNT must expose a last start date");
  testEquals ([lastStart descriptionWithCalendarFormat: @"%Y%m%dT%H%M%SZ"],
              @"20540910T000000Z");

  testEquals ([event quickRecordDateAsNumber: lastStart
                                 withOffset: 0
                                  forAllDay: NO],
              [NSNumber numberWithInt: INT_MAX]);
}

@end
