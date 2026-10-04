/* TestiCalRepeatableEntityObjectRecurrenceDates.m - this file is part of SOGo
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
 * Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/NSCalendarDate+NGCards.h>
#import <NGCards/NSString+NGCards.h>

#import "SOGoTest.h"

@interface TestiCalRepeatableEntityObjectRecurrenceDates : SOGoTest
@end

@implementation TestiCalRepeatableEntityObjectRecurrenceDates

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

- (NSArray *) _recurrenceDateTimesOfEvent: (iCalEvent *) event
{
  return [self _recurrenceDateTimesOfEvent: event
                              withTimeZone: [NSTimeZone timeZoneWithName: @"Europe/Berlin"]];
}

- (NSArray *) _recurrenceDateTimesOfEvent: (iCalEvent *) event
                             withTimeZone: (id) timeZone
{
  NSMutableArray *dateTimes;
  NSEnumerator *e;
  NSCalendarDate *date;

  dateTimes = [NSMutableArray array];
  e = [[event recurrenceDatesWithTimeZone: timeZone] objectEnumerator];
  while ((date = [e nextObject]))
    [dateTimes addObject: [date iCalFormattedDateTimeString]];

  return dateTimes;
}

- (void) test_allDayEventKeepsUtcRecurrenceDateInstants
{
  NSArray *expectedDateTimes;
  iCalEvent *event;

  event = [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-5963-legacy\r\n"
                     @"SUMMARY:test-5963\r\n"
                     @"RDATE:20260430T220000Z\r\n"
                     @"RDATE:20260507T220000Z\r\n"
                     @"DTSTART;VALUE=DATE:20260424\r\n"
                     @"DTEND;VALUE=DATE:20260425\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];

  expectedDateTimes = [NSArray arrayWithObjects: @"20260430T220000", @"20260507T220000", nil];
  testEquals ([self _recurrenceDateTimesOfEvent: event], expectedDateTimes);
}

- (void) test_allDayEventShiftsDateRecurrenceValuesToLocalMidnight
{
  NSArray *expectedDateTimes;
  iCalEvent *event;

  event = [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-5963-datevalue\r\n"
                     @"SUMMARY:test-5963\r\n"
                     @"RDATE;VALUE=DATE:20260501\r\n"
                     @"DTSTART;VALUE=DATE:20260424\r\n"
                     @"DTEND;VALUE=DATE:20260425\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];

  expectedDateTimes = [NSArray arrayWithObject: @"20260430T220000"];
  testEquals ([self _recurrenceDateTimesOfEvent: event], expectedDateTimes);
}

- (void) test_allDayEventShiftsUtcMidnightRecurrenceDatesToLocalMidnight
{
  NSArray *expectedDateTimes;
  iCalEvent *event;

  event = [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-5963-midnight\r\n"
                     @"SUMMARY:test-5963\r\n"
                     @"RDATE:20260501T000000Z\r\n"
                     @"DTSTART;VALUE=DATE:20260424\r\n"
                     @"DTEND;VALUE=DATE:20260425\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];

  expectedDateTimes = [NSArray arrayWithObject: @"20260430T220000"];
  testEquals ([self _recurrenceDateTimesOfEvent: event], expectedDateTimes);
}

- (void) test_timedEventKeepsShiftedRecurrenceDates
{
  NSArray *expectedDateTimes;
  iCalEvent *event;

  event = [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-5963-timed\r\n"
                     @"SUMMARY:test-5963\r\n"
                     @"RDATE:20260430T220000Z\r\n"
                     @"DTSTART:20260424T100000Z\r\n"
                     @"DTEND:20260424T110000Z\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];

  expectedDateTimes = [NSArray arrayWithObject: @"20260430T200000"];
  testEquals ([self _recurrenceDateTimesOfEvent: event], expectedDateTimes);
}

- (void) test_utcRecurrenceDatesFollowEventTimeZoneAcrossDstChanges
{
  NSArray *expectedDateTimes;
  iCalDateTime *dtstart;
  iCalEvent *event;

  event = [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"PRODID:-//Inverse inc./SOGo 5.9.1//EN\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VTIMEZONE\r\n"
                     @"TZID:Europe/Berlin\r\n"
                     @"LAST-MODIFIED:20230523T092157Z\r\n"
                     @"X-LIC-LOCATION:Europe/Berlin\r\n"
                     @"BEGIN:DAYLIGHT\r\n"
                     @"TZNAME:CEST\r\n"
                     @"TZOFFSETFROM:+0100\r\n"
                     @"TZOFFSETTO:+0200\r\n"
                     @"DTSTART:19700329T020000\r\n"
                     @"RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU\r\n"
                     @"END:DAYLIGHT\r\n"
                     @"BEGIN:STANDARD\r\n"
                     @"TZNAME:CET\r\n"
                     @"TZOFFSETFROM:+0200\r\n"
                     @"TZOFFSETTO:+0100\r\n"
                     @"DTSTART:19701025T030000\r\n"
                     @"RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU\r\n"
                     @"END:STANDARD\r\n"
                     @"END:VTIMEZONE\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-5914-berlin\r\n"
                     @"SUMMARY:Test-Event\r\n"
                     @"CLASS:PUBLIC\r\n"
                     @"DTSTART;TZID=Europe/Berlin:20240117T091500\r\n"
                     @"DTEND;TZID=Europe/Berlin:20240117T103000\r\n"
                     @"TRANSP:OPAQUE\r\n"
                     @"CREATED:20240117T093732Z\r\n"
                     @"DTSTAMP:20240117T093732Z\r\n"
                     @"LAST-MODIFIED:20240117T094552Z\r\n"
                     @"RDATE:20240313T081500Z\r\n"
                     @"RDATE:20240508T071500Z\r\n"
                     @"RDATE:20240703T071500Z\r\n"
                     @"RDATE:20240828T071500Z\r\n"
                     @"RDATE:20241023T071500Z\r\n"
                     @"RDATE:20241218T081500Z\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];

  dtstart = (iCalDateTime *) [event uniqueChildWithTag: @"dtstart"];
  testWithMessage ([[dtstart timeZone] isKindOfClass: [iCalTimeZone class]],
                   @"the event timezone must resolve as an iCalTimeZone");

  expectedDateTimes = [NSArray arrayWithObjects:
                                @"20240313T091500",
                                @"20240508T091500",
                                @"20240703T091500",
                                @"20240828T091500",
                                @"20241023T091500",
                                @"20241218T091500",
                                nil];
  testEquals ([self _recurrenceDateTimesOfEvent: event
                                   withTimeZone: [dtstart timeZone]],
              expectedDateTimes);
}

@end
