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
  NSMutableArray *dateTimes;
  NSEnumerator *e;
  NSCalendarDate *date;

  dateTimes = [NSMutableArray array];
  e = [[event recurrenceDatesWithTimeZone:
                    [NSTimeZone timeZoneWithName: @"Europe/Berlin"]] objectEnumerator];
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

@end
