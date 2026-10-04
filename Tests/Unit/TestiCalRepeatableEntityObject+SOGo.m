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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalRecurrenceRule.h>

#import <SOGo/SOGoUserDefaults.h>

#import "SOGoTest.h"

@interface iCalRepeatableEntityObject (SOGoTestsDeclaration)
- (void) setAttributes: (NSDictionary *) data
             inContext: (id) context;
- (NSDictionary *) attributesInContext: (id) context;
@end

@interface TestiCalRepeatableEntityObjectUser : NSObject
@end

@implementation TestiCalRepeatableEntityObjectUser

- (SOGoUserDefaults *) userDefaults
{
  return [SOGoUserDefaults defaultsSourceWithSource:
                       [NSDictionary dictionaryWithObject: @"Europe/Berlin"
                                                   forKey: @"SOGoTimeZone"]
                                   andParentSource: [NSDictionary dictionary]];
}

@end

@interface TestiCalRepeatableEntityObjectContext : NSObject
@end

@implementation TestiCalRepeatableEntityObjectContext

- (TestiCalRepeatableEntityObjectUser *) activeUser
{
  TestiCalRepeatableEntityObjectUser *user;

  user = [[TestiCalRepeatableEntityObjectUser alloc] init];

  return [user autorelease];
}

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

- (NSArray *) _customDates: (NSArray *) dateStrings
{
  NSMutableArray *dates;
  NSUInteger i, count;
  NSString *currentDate;

  dates = [NSMutableArray arrayWithCapacity: [dateStrings count]];
  count = [dateStrings count];
  for (i = 0; i < count; i++)
    {
      currentDate = [dateStrings objectAtIndex: i];
      [dates addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                    currentDate, @"date",
                                    @"00:00", @"time",
                                    nil]];
    }

  return dates;
}

- (NSDictionary *) _repeatDataWithDates: (NSArray *) dates
                               isAllDay: (BOOL) isAllDay
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithBool: isAllDay], @"isAllDay",
                       @"2026-04-24", @"startDate",
                       @"2026-04-24", @"endDate",
                       [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"custom", @"frequency",
                         dates, @"dates",
                         nil],
                       @"repeat",
                       nil];
}

- (NSArray *) _rdateValuesOfEvent: (iCalEvent *) event
{
  NSMutableArray *values;
  NSEnumerator *rdates;
  iCalDateTime *rdateTime;

  values = [NSMutableArray array];
  rdates = [[event childrenWithTag: @"rdate"] objectEnumerator];
  while ((rdateTime = [rdates nextObject]))
    [values addObject: [rdateTime flattenedValuesForKey: @""]];

  return values;
}

- (void) test_saveCustomRepeatRemovesRecurrenceRule
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

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

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

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

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

- (void) test_saveAllDayCustomRepeatKeepsRecurrenceDays
{
  iCalEvent *event;
  NSArray *rdates;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6194-edit\r\n"
                    @"SUMMARY:test-6194\r\n"
                    @"DTSTART;VALUE=DATE:20260424\r\n"
                    @"DTEND;VALUE=DATE:20260425\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  [event setAttributes: [self _repeatDataWithDates:
                                   [self _customDates: [NSArray arrayWithObjects:
                                                        @"2026-05-01", @"2026-05-07",
                                                        @"2026-03-30", nil]]
                                                      isAllDay: YES]
                  inContext: [[[TestiCalRepeatableEntityObjectContext alloc] init]
                               autorelease]];

  rdates = [self _rdateValuesOfEvent: event];
  testWithMessage ([rdates count] == 3,
                   @"three custom recurrence dates must be recorded");
  if ([rdates count] == 3)
    {
      testEquals ([rdates objectAtIndex: 0], @"20260501");
      testEquals ([rdates objectAtIndex: 1], @"20260507");
      testEquals ([rdates objectAtIndex: 2], @"20260330");
    }
}

- (void) test_saveAllDayCustomRepeatOnTimedEventKeepsRecurrenceDays
{
  iCalEvent *event;
  NSArray *rdates;
  NSString *rdate;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6194-create\r\n"
                    @"SUMMARY:test-6194\r\n"
                    @"DTSTART:20260424T100000Z\r\n"
                    @"DTEND:20260424T110000Z\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  [event setAttributes: [self _repeatDataWithDates:
                                   [self _customDates: [NSArray arrayWithObjects:
                                                        @"2026-05-01", @"2026-05-07", nil]]
                                                      isAllDay: YES]
                  inContext: [[[TestiCalRepeatableEntityObjectContext alloc] init]
                               autorelease]];

  testWithMessage ([event isAllDay],
                   @"the event must have been converted to an all-day event");

  rdates = [self _rdateValuesOfEvent: event];
  testWithMessage ([rdates count] == 2,
                   @"two custom recurrence dates must be recorded");
  if ([rdates count] == 2)
    {
      rdate = [rdates objectAtIndex: 0];
      testEquals (rdate, @"20260501");
      rdate = [rdates objectAtIndex: 1];
      testEquals (rdate, @"20260507");
    }
}

- (void) test_saveAllDayCustomRepeatOnCreationRendersDateRecurrenceValues
{
  NSArray *expectedLines;
  iCalEvent *event;
  NSMutableArray *rdateLines;
  NSEnumerator *e;
  NSString *line;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-5963-create\r\n"
                     @"SUMMARY:test-5963\r\n"
                     @"DTSTART:20260424T100000Z\r\n"
                     @"DTEND:20260424T110000Z\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];

  [event setAttributes: [self _repeatDataWithDates:
                                 [self _customDates: [NSArray arrayWithObjects:
                                                      @"2026-05-01", @"2026-05-07", nil]]
                                                    isAllDay: YES]
                  inContext: [[[TestiCalRepeatableEntityObjectContext alloc] init]
                               autorelease]];

  rdateLines = [NSMutableArray array];
  e = [[[[event parent] versitString] componentsSeparatedByString: @"\r\n"] objectEnumerator];
  while ((line = [e nextObject]))
    if ([line hasPrefix: @"RDATE"])
      [rdateLines addObject: line];

  expectedLines = [NSArray arrayWithObjects:
                             @"RDATE;VALUE=DATE:20260501",
                             @"RDATE;VALUE=DATE:20260507",
                             nil];
  testEquals (rdateLines, expectedLines);
}

- (void) test_saveTimedCustomRepeatKeepsWallClock
{
  iCalEvent *event;
  NSDictionary *data, *repeat;
  NSArray *dates;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6194-timed\r\n"
                    @"SUMMARY:test-6194\r\n"
                    @"DTSTART:20260424T100000Z\r\n"
                    @"DTEND:20260424T110000Z\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];

  [event setAttributes: [self _repeatDataWithDates:
                                   [self _customDates: [NSArray arrayWithObject: @"2026-05-01"]]
                                                      isAllDay: NO]
                  inContext: [[[TestiCalRepeatableEntityObjectContext alloc] init]
                               autorelease]];

  testWithMessage (![event isAllDay],
                   @"the event must remain a timed event");

  data = [event attributesInContext:
                   [[[TestiCalRepeatableEntityObjectContext alloc] init]
                     autorelease]];
  repeat = [data objectForKey: @"repeat"];
  testWithMessage ([repeat objectForKey: @"dates"] != nil,
                   @"the recurrence dates must be exposed");
  dates = [repeat objectForKey: @"dates"];
  testWithMessage ([dates count] == 1,
                   @"one custom recurrence date must be recorded");
  if ([dates count] == 1)
    testEquals ([dates objectAtIndex: 0], @"2026-05-01T00:00+02:00");
}

- (void) test_allDayEventExposesRecurrenceDatesInUserTimezone
{
  iCalEvent *event;
  NSDictionary *data, *repeat;
  NSArray *dates;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6194-read\r\n"
                    @"SUMMARY:test-6194\r\n"
                    @"RDATE;VALUE=DATE:20260501\r\n"
                    @"RDATE;VALUE=DATE:20260507\r\n"
                    @"DTSTART;VALUE=DATE:20260424\r\n"
                    @"DTEND;VALUE=DATE:20260425\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];
  data = [event attributesInContext:
                   [[[TestiCalRepeatableEntityObjectContext alloc] init]
                     autorelease]];

  repeat = [data objectForKey: @"repeat"];
  testWithMessage ([repeat objectForKey: @"dates"] != nil,
                   @"the recurrence dates must be exposed");
  dates = [repeat objectForKey: @"dates"];
  testWithMessage ([dates count] == 2,
                   @"both recurrence dates must be exposed");
  if ([dates count] == 2)
    {
      testEquals ([dates objectAtIndex: 0], @"2026-05-01T00:00+02:00");
      testEquals ([dates objectAtIndex: 1], @"2026-05-07T00:00+02:00");
    }
}

- (void) test_allDayEventExposesUtcMidnightRecurrenceDatesInUserTimezone
{
  iCalEvent *event;
  NSDictionary *data, *repeat;
  NSArray *dates;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6194-midnight\r\n"
                    @"SUMMARY:test-6194\r\n"
                    @"RDATE:20260501T000000Z\r\n"
                    @"DTSTART;VALUE=DATE:20260424\r\n"
                    @"DTEND;VALUE=DATE:20260425\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];
  data = [event attributesInContext:
                   [[[TestiCalRepeatableEntityObjectContext alloc] init]
                     autorelease]];

  repeat = [data objectForKey: @"repeat"];
  testWithMessage ([repeat objectForKey: @"dates"] != nil,
                   @"the recurrence dates must be exposed");
  dates = [repeat objectForKey: @"dates"];
  testWithMessage ([dates count] == 1,
                   @"the recurrence date must be exposed");
  if ([dates count] == 1)
    testEquals ([dates objectAtIndex: 0], @"2026-05-01T00:00+02:00");
}

- (void) test_allDayEventExposesLegacyUtcRecurrenceDatesAsWallClock
{
  iCalEvent *event;
  NSDictionary *data, *repeat;
  NSArray *dates;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6194-legacy\r\n"
                    @"SUMMARY:test-6194\r\n"
                    @"RDATE:20260430T220000Z\r\n"
                    @"RDATE:20260507T220000Z\r\n"
                    @"DTSTART;VALUE=DATE:20260424\r\n"
                    @"DTEND;VALUE=DATE:20260425\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];
  data = [event attributesInContext:
                   [[[TestiCalRepeatableEntityObjectContext alloc] init]
                     autorelease]];

  repeat = [data objectForKey: @"repeat"];
  testWithMessage ([repeat objectForKey: @"dates"] != nil,
                   @"the recurrence dates must be exposed");
  dates = [repeat objectForKey: @"dates"];
  testWithMessage ([dates count] == 2,
                   @"both recurrence dates must be exposed");
  if ([dates count] == 2)
    {
      testEquals ([dates objectAtIndex: 0], @"2026-05-01T00:00+02:00");
      testEquals ([dates objectAtIndex: 1], @"2026-05-08T00:00+02:00");
    }
}

- (void) test_allDayCustomRepeatRoundTripKeepsRecurrenceDays
{
  iCalEvent *event;
  NSDictionary *data, *repeat;
  NSArray *dates;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                    @"BEGIN:VCALENDAR\r\n"
                    @"VERSION:2.0\r\n"
                    @"BEGIN:VEVENT\r\n"
                    @"UID:test-6194-roundtrip\r\n"
                    @"SUMMARY:test-6194\r\n"
                    @"RDATE;VALUE=DATE:20260501\r\n"
                    @"DTSTART;VALUE=DATE:20260424\r\n"
                    @"DTEND;VALUE=DATE:20260425\r\n"
                    @"END:VEVENT\r\n"
                    @"END:VCALENDAR\r\n"];
  data = [event attributesInContext:
                   [[[TestiCalRepeatableEntityObjectContext alloc] init]
                     autorelease]];
  repeat = [data objectForKey: @"repeat"];
  dates = [repeat objectForKey: @"dates"];
  testWithMessage ([dates count] == 1,
                   @"one recurrence date must be exposed");
  if ([dates count] == 1)
    {
      NSString *iso8601Date;

      iso8601Date = [dates objectAtIndex: 0];
      testEquals ([iso8601Date substringToIndex: 10], @"2026-05-01");

      [event setAttributes: [self _repeatDataWithDates:
                                       [NSArray arrayWithObject:
                                         [NSDictionary dictionaryWithObjectsAndKeys:
                                           [iso8601Date substringToIndex: 10], @"date",
                                           @"00:00", @"time",
                                           nil]]
                                                        isAllDay: YES]
                      inContext: [[[TestiCalRepeatableEntityObjectContext alloc] init]
                                   autorelease]];

      testEquals ([self _rdateValuesOfEvent: event], [NSArray arrayWithObject: @"20260501"]);
    }
}

@end
