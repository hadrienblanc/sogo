/* TestiCalRepeatableEntityObject+SOGo.m - this file is part of SOGo
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

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalRecurrenceRule.h>

#import "SOGoTest.h"

@interface iCalRepeatableEntityObject (SOGoTestsDeclaration)
- (void) setAttributes: (NSDictionary *) data
             inContext: (id) context;
@end

@interface TestiCalRepeatableEntityObject_plus_SOGo : SOGoTest
@end

@implementation TestiCalRepeatableEntityObject_plus_SOGo

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (iCalEvent *) _eventWithContent: (NSString *) content
{
  iCalCalendar *calendar;
  iCalEvent *event;

  calendar = [iCalCalendar parseSingleFromSource: content];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");
  event = [[calendar events] objectAtIndex: 0];
  testWithMessage (event != nil, @"no VEVENT found in iCalendar content");

  return event;
}

- (NSDictionary *) _customRepeatData
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithBool: YES], @"isAllDay",
                       @"2026-04-24", @"startDate",
                       @"2026-04-25", @"endDate",
                       [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"custom", @"frequency",
                         [NSArray arrayWithObject:
                           [NSDictionary dictionaryWithObjectsAndKeys:
                                             @"2026-04-25", @"date",
                                             @"00:00", @"time",
                                             nil]],
                         @"dates",
                         nil],
                       @"repeat",
                       nil];
}

- (NSDictionary *) _weeklyRepeatData
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithBool: YES], @"isAllDay",
                       @"2026-04-24", @"startDate",
                       @"2026-04-25", @"endDate",
                       [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"weekly", @"frequency",
                         [NSNumber numberWithInt: 1], @"interval",
                         [NSNumber numberWithInt: 2], @"count",
                         [NSArray arrayWithObject:
                           [NSDictionary dictionaryWithObject: @"FR"
                                                       forKey: @"day"]],
                         @"days",
                         nil],
                       @"repeat",
                       nil];
}

- (void) test_saveCustomRepeatRemovesRecurrenceRule
{
  iCalEvent *event;

  testWithMessage (LoadAppointmentsBundle (),
                   @"Appointments.SOGo bundle unavailable");
  if (!LoadAppointmentsBundle ())
    return;

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6193-weekly\r\n"
                    @"SUMMARY:test-6193\r\n"
                    @"RRULE:FREQ=WEEKLY;COUNT=2;BYDAY=FR\r\n"
                    @"DTSTART;VALUE=DATE:20260424\r\n"
                    @"DTEND;VALUE=DATE:20260425\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];
  test ([event hasRecurrenceRules]);
  test (![event hasRecurrenceDates]);

  [event setAttributes: [self _customRepeatData] inContext: nil];

  testWithMessage (![event hasRecurrenceRules],
                   @"a custom repeat must drop the recurrence rule");
  testWithMessage ([event hasRecurrenceDates],
                   @"a custom repeat must keep its recurrence dates");
  testWithMessage ([[event recurrenceDates] count] == 1,
                   @"a custom repeat must record exactly one recurrence date");
}

- (void) test_saveCustomRepeatOnMixedEventRemovesRecurrenceRule
{
  iCalEvent *event;

  testWithMessage (LoadAppointmentsBundle (),
                   @"Appointments.SOGo bundle unavailable");
  if (!LoadAppointmentsBundle ())
    return;

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6193-mixed\r\n"
                    @"SUMMARY:test-6193\r\n"
                    @"RRULE:FREQ=WEEKLY;COUNT=2;BYDAY=FR\r\n"
                    @"RDATE;VALUE=DATE:20260424\r\n"
                    @"DTSTART;VALUE=DATE:20260424\r\n"
                    @"DTEND;VALUE=DATE:20260425\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];
  test ([event hasRecurrenceRules]);
  test ([event hasRecurrenceDates]);

  [event setAttributes: [self _customRepeatData] inContext: nil];

  testWithMessage (![event hasRecurrenceRules],
                   @"saving a custom repeat must drop the leftover recurrence rule");
  testWithMessage ([[event recurrenceDates] count] == 1,
                   @"saving a custom repeat must replace the recurrence dates");
}

- (void) test_saveRuleRepeatRemovesRecurrenceDates
{
  iCalEvent *event;
  NSArray *rules;

  testWithMessage (LoadAppointmentsBundle (),
                   @"Appointments.SOGo bundle unavailable");
  if (!LoadAppointmentsBundle ())
    return;

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6193-custom\r\n"
                    @"SUMMARY:test-6193\r\n"
                    @"RDATE;VALUE=DATE:20260424\r\n"
                    @"DTSTART;VALUE=DATE:20260424\r\n"
                    @"DTEND;VALUE=DATE:20260425\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];
  test (![event hasRecurrenceRules]);
  test ([event hasRecurrenceDates]);

  [event setAttributes: [self _weeklyRepeatData] inContext: nil];

  testWithMessage (![event hasRecurrenceDates],
                   @"a rule-based repeat must drop the recurrence dates");
  rules = [event recurrenceRules];
  testWithMessage ([rules count] == 1,
                   @"a rule-based repeat must record exactly one recurrence rule");
  if ([rules count] == 1)
    test ([[rules objectAtIndex: 0] frequency] == iCalRecurrenceFrequenceWeekly);
}

@end
