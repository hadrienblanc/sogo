/* TestiCalEvent+SOGo.m - this file is part of SOGo
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

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalRecurrenceRule.h>

#import "SOGoTest.h"

@interface iCalEvent (SOGoTestsDeclaration)
- (void) synchronizeStartDateWithRecurrenceRule;
- (void) setAttributes: (NSDictionary *) data
             inContext: (id) context;
@end

@interface TestiCalEvent_plus_SOGo : SOGoTest
@end

@implementation TestiCalEvent_plus_SOGo

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

- (NSString *) _dateTimeString: (NSCalendarDate *) date
{
  return [date descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M"];
}

- (NSString *) _dateTimeString: (NSCalendarDate *) date
                    inTimeZone: (NSString *) tzName
{
  NSCalendarDate *localDate;

  localDate = [date copy];
  [localDate autorelease];
  [localDate setTimeZone: [NSTimeZone timeZoneWithName: tzName]];

  return [localDate descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M"];
}

- (NSString *) _dateString: (NSCalendarDate *) date
{
  return [date descriptionWithCalendarFormat: @"%Y-%m-%d"];
}

- (void) test_synchronizeStartDateOnNonMatchingWeeklyByDay
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6162-weekly\r\n"
                    @"SUMMARY:Test\r\n"
                    @"DTSTART;TZID=Europe/Moscow:20251001T094500\r\n"
                    @"DTEND;TZID=Europe/Moscow:20251001T144500\r\n"
                    @"RRULE:FREQ=WEEKLY;BYDAY=MO,FR,SA;UNTIL=20251015T144500Z\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  [event synchronizeStartDateWithRecurrenceRule];

  testWithMessage ([[self _dateTimeString: [event startDate]
                              inTimeZone: @"Europe/Moscow"]
                     isEqualToString: @"2025-10-03 09:45"],
                    @"DTSTART must snap to the first BYDAY match (Friday)");
  testWithMessage ([[self _dateTimeString: [event endDate]
                              inTimeZone: @"Europe/Moscow"]
                     isEqualToString: @"2025-10-03 14:45"],
                    @"DTEND must keep the event duration when DTSTART snaps");
}

- (void) test_synchronizeStartDateKeepsMatchingStartDate
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6162-matching\r\n"
                    @"SUMMARY:Test\r\n"
                    @"DTSTART;TZID=Europe/Moscow:20251001T094500\r\n"
                    @"DTEND;TZID=Europe/Moscow:20251001T144500\r\n"
                    @"RRULE:FREQ=WEEKLY;BYDAY=WE,FR\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  [event synchronizeStartDateWithRecurrenceRule];

  testWithMessage ([[self _dateTimeString: [event startDate]
                              inTimeZone: @"Europe/Moscow"]
                     isEqualToString: @"2025-10-01 09:45"],
                    @"DTSTART matching BYDAY must not move");
}

- (void) test_synchronizeStartDateOnAllDayEvent
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6162-allday\r\n"
                    @"SUMMARY:Test\r\n"
                    @"DTSTART;VALUE=DATE:20251001\r\n"
                    @"DTEND;VALUE=DATE:20251002\r\n"
                    @"RRULE:FREQ=WEEKLY;BYDAY=MO,FR,SA\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  [event synchronizeStartDateWithRecurrenceRule];

  testWithMessage ([[self _dateString: [event startDate]]
                    isEqualToString: @"2025-10-03"],
                   @"all-day DTSTART must snap to the first BYDAY match");
  testWithMessage ([[self _dateString: [event endDate]]
                    isEqualToString: @"2025-10-04"],
                   @"all-day DTEND must keep the event duration when DTSTART snaps");
  testWithMessage ([event isAllDay],
                   @"a snapped all-day event must stay an all-day event");
}

- (void) test_synchronizeStartDateCrossesWeekBoundary
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6162-weekboundary\r\n"
                    @"SUMMARY:Test\r\n"
                    @"DTSTART:20251004T094500Z\r\n"
                    @"DTEND:20251004T144500Z\r\n"
                    @"RRULE:FREQ=WEEKLY;BYDAY=TU\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  [event synchronizeStartDateWithRecurrenceRule];

  testWithMessage ([[self _dateTimeString: [event startDate]]
                    isEqualToString: @"2025-10-07 09:45"],
                   @"DTSTART must snap forward to the next BYDAY match");
}

- (void) test_synchronizeStartDateIgnoresDailyRule
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6162-daily\r\n"
                    @"SUMMARY:Test\r\n"
                    @"DTSTART:20251004T094500Z\r\n"
                    @"DTEND:20251004T144500Z\r\n"
                    @"RRULE:FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  [event synchronizeStartDateWithRecurrenceRule];

  testWithMessage ([[self _dateTimeString: [event startDate]]
                    isEqualToString: @"2025-10-04 09:45"],
                   @"non weekly rules must not be touched");
}

- (void) test_synchronizeStartDateIgnoresWeeklyRuleWithoutByDay
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6162-nobyday\r\n"
                    @"SUMMARY:Test\r\n"
                    @"DTSTART:20251001T094500Z\r\n"
                    @"DTEND:20251001T144500Z\r\n"
                    @"RRULE:FREQ=WEEKLY;COUNT=3\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  [event synchronizeStartDateWithRecurrenceRule];

  testWithMessage ([[self _dateTimeString: [event startDate]]
                    isEqualToString: @"2025-10-01 09:45"],
                   @"weekly rules without BYDAY must not be touched");
}

- (void) test_synchronizeStartDateOnEventWithoutRecurrenceRule
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6162-norrule\r\n"
                    @"SUMMARY:Test\r\n"
                    @"DTSTART:20251001T094500Z\r\n"
                    @"DTEND:20251001T144500Z\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  [event synchronizeStartDateWithRecurrenceRule];

  testWithMessage ([[self _dateTimeString: [event startDate]]
                    isEqualToString: @"2025-10-01 09:45"],
                   @"events without a recurrence rule must not be touched");
}

- (void) test_synchronizeStartDateOnUnparsableByDay
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6162-garbage\r\n"
                    @"SUMMARY:Test\r\n"
                    @"DTSTART:20251001T094500Z\r\n"
                    @"DTEND:20251001T144500Z\r\n"
                    @"RRULE:FREQ=WEEKLY;BYDAY=XX\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  [event synchronizeStartDateWithRecurrenceRule];

  testWithMessage ([[self _dateTimeString: [event startDate]]
                    isEqualToString: @"2025-10-01 09:45"],
                   @"an empty BYDAY mask must not move DTSTART");
}

- (void) test_synchronizeStartDateOnOccurrence
{
  iCalCalendar *calendar;
  iCalEvent *occurrence;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  calendar = [iCalCalendar parseSingleFromSource:
                        @"BEGIN:VCALENDAR\r\n"
                        @"VERSION:2.0\r\n"
                        @"BEGIN:VEVENT\r\n"
                        @"UID:test-6162-master\r\n"
                        @"SUMMARY:Test\r\n"
                        @"DTSTART;TZID=Europe/Moscow:20251001T094500\r\n"
                        @"DTEND;TZID=Europe/Moscow:20251001T144500\r\n"
                        @"RRULE:FREQ=WEEKLY;BYDAY=MO,FR,SA\r\n"
                        @"END:VEVENT\r\n"
                        @"BEGIN:VEVENT\r\n"
                        @"UID:test-6162-master\r\n"
                        @"SUMMARY:Test\r\n"
                        @"RECURRENCE-ID;TZID=Europe/Moscow:20251003T094500\r\n"
                        @"DTSTART;TZID=Europe/Moscow:20251003T100000\r\n"
                        @"DTEND;TZID=Europe/Moscow:20251003T150000\r\n"
                        @"RRULE:FREQ=WEEKLY;BYDAY=MO,FR,SA\r\n"
                        @"END:VEVENT\r\n"
                        @"END:VCALENDAR\r\n"];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");
  testWithMessage ([[calendar events] count] == 2,
                   @"expected a master event and one occurrence");
  occurrence = [[calendar events] objectAtIndex: 1];

  [occurrence synchronizeStartDateWithRecurrenceRule];

  testWithMessage ([[self _dateTimeString: [occurrence startDate]
                              inTimeZone: @"Europe/Moscow"]
                     isEqualToString: @"2025-10-03 10:00"],
                    @"occurrences must not be snapped to the recurrence rule");
}

- (void) test_saveWeeklyRepeatSnapsTimedStartDate
{
  iCalEvent *event;
  NSArray *days;
  NSDictionary *repeat, *data;
  NSCalendarDate *octoberFirst, *octoberThird;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6162-save\r\n"
                    @"SUMMARY:Test\r\n"
                    @"DTSTART;TZID=Europe/Moscow:20251001T094500\r\n"
                    @"DTEND;TZID=Europe/Moscow:20251001T144500\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  days = [NSArray arrayWithObjects:
                    [NSDictionary dictionaryWithObject: @"MO" forKey: @"day"],
                    [NSDictionary dictionaryWithObject: @"FR" forKey: @"day"],
                    [NSDictionary dictionaryWithObject: @"SA" forKey: @"day"],
                    nil];
  repeat = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"weekly", @"frequency",
                          [NSNumber numberWithInt: 1], @"interval",
                          days, @"days",
                          nil];
  data = [NSDictionary dictionaryWithObjectsAndKeys:
                      @"2025-10-01", @"startDate",
                      @"2025-10-01", @"endDate",
                      @"09:45", @"startTime",
                      @"14:45", @"endTime",
                      repeat, @"repeat",
                      nil];

  [event setAttributes: data inContext: nil];

  testWithMessage ([[self _dateString: [event startDate]]
                    isEqualToString: @"2025-10-03"],
                   @"saving a weekly MO,FR,SA repeat must snap DTSTART to Friday");
  testWithMessage ([[self _dateString: [event endDate]]
                    isEqualToString: @"2025-10-03"],
                   @"saving a weekly MO,FR,SA repeat must snap DTEND to Friday");
  testWithMessage ([[event startDate] dayOfWeek] == iCalWeekDayFriday,
                   @"snapped DTSTART must fall on a BYDAY weekday");

  octoberFirst = [NSCalendarDate dateWithYear: 2025 month: 10 day: 1
                                        hour: 15 minute: 0 second: 0
                                    timeZone: [NSTimeZone timeZoneWithName: @"Europe/Moscow"]];
  testWithMessage (![event doesOccurOnDate: octoberFirst],
                   @"no occurrence may remain on the unsynchronized Wednesday");
  octoberThird = [NSCalendarDate dateWithYear: 2025 month: 10 day: 3
                                        hour: 15 minute: 0 second: 0
                                    timeZone: [NSTimeZone timeZoneWithName: @"Europe/Moscow"]];
  testWithMessage ([event doesOccurOnDate: octoberThird],
                   @"an occurrence must exist on the synchronized Friday");
}

- (void) test_saveWeeklyRepeatKeepsMatchingStartDate
{
  iCalEvent *event;
  NSArray *days;
  NSDictionary *repeat, *data;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6162-save-matching\r\n"
                    @"SUMMARY:Test\r\n"
                    @"DTSTART;TZID=Europe/Moscow:20251001T094500\r\n"
                    @"DTEND;TZID=Europe/Moscow:20251001T144500\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  days = [NSArray arrayWithObject:
                 [NSDictionary dictionaryWithObject: @"WE" forKey: @"day"]];
  repeat = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"weekly", @"frequency",
                          [NSNumber numberWithInt: 1], @"interval",
                          days, @"days",
                          nil];
  data = [NSDictionary dictionaryWithObjectsAndKeys:
                      @"2025-10-01", @"startDate",
                      @"2025-10-01", @"endDate",
                      @"09:45", @"startTime",
                      @"14:45", @"endTime",
                      repeat, @"repeat",
                      nil];

  [event setAttributes: data inContext: nil];

  testWithMessage ([[self _dateString: [event startDate]]
                    isEqualToString: @"2025-10-01"],
                   @"saving a weekly repeat matching DTSTART must not move DTSTART");
}

- (void) test_saveWeeklyRepeatSnapsAllDayStartDate
{
  iCalEvent *event;
  NSArray *days;
  NSDictionary *repeat, *data;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6162-save-allday\r\n"
                    @"SUMMARY:Test\r\n"
                    @"DTSTART;VALUE=DATE:20251001\r\n"
                    @"DTEND;VALUE=DATE:20251002\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  days = [NSArray arrayWithObjects:
                    [NSDictionary dictionaryWithObject: @"MO" forKey: @"day"],
                    [NSDictionary dictionaryWithObject: @"FR" forKey: @"day"],
                    [NSDictionary dictionaryWithObject: @"SA" forKey: @"day"],
                    nil];
  repeat = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"weekly", @"frequency",
                          [NSNumber numberWithInt: 1], @"interval",
                          days, @"days",
                          nil];
  data = [NSDictionary dictionaryWithObjectsAndKeys:
                      [NSNumber numberWithBool: YES], @"isAllDay",
                      @"2025-10-01", @"startDate",
                      @"2025-10-02", @"endDate",
                      repeat, @"repeat",
                      nil];

  [event setAttributes: data inContext: nil];

  testWithMessage ([[self _dateString: [event startDate]]
                    isEqualToString: @"2025-10-03"],
                   @"saving an all-day weekly MO,FR,SA repeat must snap DTSTART to Friday");
  testWithMessage ([[self _dateString: [event endDate]]
                    isEqualToString: @"2025-10-05"],
                   @"saving an all-day weekly MO,FR,SA repeat must snap DTEND accordingly");
  testWithMessage ([event isAllDay],
                   @"a snapped all-day event must stay an all-day event");
}

@end
