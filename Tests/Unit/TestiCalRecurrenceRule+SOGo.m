/* TestiCalRecurrenceRule+SOGo.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING. If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalRecurrenceRule.h>

#import "SOGoTest.h"

@interface iCalRecurrenceRule (SOGoTestsDeclaration)
- (NSString *) repeatLabelKey;
@end

@interface TestiCalRecurrenceRule_plus_SOGo : SOGoTest
@end

@implementation TestiCalRecurrenceRule_plus_SOGo

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (iCalRecurrenceRule *) _ruleWithContent: (NSString *) rrule
{
  iCalCalendar *calendar;
  iCalEvent *event;

  calendar = [iCalCalendar parseSingleFromSource:
                         [NSString stringWithFormat:
                           @"BEGIN:VCALENDAR\r\n"
                           @"VERSION:2.0\r\n"
                           @"BEGIN:VEVENT\r\n"
                           @"UID:test-5992\r\n"
                           @"SUMMARY:invitation\r\n"
                           @"DTSTART;TZID=W. Europe Standard Time:20240730T130000\r\n"
                           @"DTEND;TZID=W. Europe Standard Time:20240730T140000\r\n"
                           @"RRULE:%@\r\n"
                           @"END:VEVENT\r\n"
                           @"END:VCALENDAR\r\n",
                           rrule]];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");
  event = [[calendar events] objectAtIndex: 0];
  testWithMessage ([[event recurrenceRules] count] == 1,
                   @"expected exactly one recurrence rule");

  return [[event recurrenceRules] objectAtIndex: 0];
}

- (void) test_outlookBiWeeklyRuleYieldsBiWeeklyLabelKey
{
  iCalRecurrenceRule *rule;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  rule = [self _ruleWithContent:
                  @"FREQ=WEEKLY;UNTIL=20241119T120000Z;INTERVAL=2;BYDAY=TU;WKST=MO"];

  test ([rule repeatInterval] == 2);
  test ([[rule repeatLabelKey] isEqualToString: @"repeat_BI-WEEKLY"]);
}

- (void) test_weeklyRuleYieldsWeeklyLabelKey
{
  iCalRecurrenceRule *rule;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  rule = [self _ruleWithContent: @"FREQ=WEEKLY;BYDAY=TU"];

  test ([[rule repeatLabelKey] isEqualToString: @"repeat_WEEKLY"]);
}

- (void) test_everyThreeWeeksRuleYieldsWeeklyLabelKey
{
  iCalRecurrenceRule *rule;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  rule = [self _ruleWithContent: @"FREQ=WEEKLY;INTERVAL=3"];

  test ([[rule repeatLabelKey] isEqualToString: @"repeat_WEEKLY"]);
}

- (void) test_dailyRuleYieldsDailyLabelKey
{
  iCalRecurrenceRule *rule;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  rule = [self _ruleWithContent: @"FREQ=DAILY"];

  test ([[rule repeatLabelKey] isEqualToString: @"repeat_DAILY"]);
}

- (void) test_monthlyRuleYieldsMonthlyLabelKey
{
  iCalRecurrenceRule *rule;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  rule = [self _ruleWithContent: @"FREQ=MONTHLY"];

  test ([[rule repeatLabelKey] isEqualToString: @"repeat_MONTHLY"]);
}

- (void) test_yearlyRuleYieldsYearlyLabelKey
{
  iCalRecurrenceRule *rule;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  rule = [self _ruleWithContent: @"FREQ=YEARLY"];

  test ([[rule repeatLabelKey] isEqualToString: @"repeat_YEARLY"]);
}

- (void) test_unsupportedFrequencyYieldsCustomLabelKey
{
  iCalRecurrenceRule *rule;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  rule = [self _ruleWithContent: @"FREQ=HOURLY"];

  test ([[rule repeatLabelKey] isEqualToString: @"repeat_CUSTOM"]);
}

- (void) test_outlookRuleUntilDateBound
{
  iCalRecurrenceRule *rule;
  NSCalendarDate *untilDate;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  rule = [self _ruleWithContent:
                  @"FREQ=WEEKLY;UNTIL=20241119T120000Z;INTERVAL=2;BYDAY=TU;WKST=MO"];
  untilDate = [rule untilDate];
  [untilDate setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];

  test (untilDate != nil);
  test ([untilDate yearOfCommonEra] == 2024);
  test ([untilDate monthOfYear] == 11);
  test ([untilDate dayOfMonth] == 19);
  test (![rule hasRepeatCount]);
}

- (void) test_countBoundedRuleExposesRepeatCount
{
  iCalRecurrenceRule *rule;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  rule = [self _ruleWithContent: @"FREQ=DAILY;COUNT=10"];

  test ([rule hasRepeatCount]);
  test ([rule repeatCount] == 10);
  test ([rule untilDate] == nil);
  test ([[rule repeatLabelKey] isEqualToString: @"repeat_DAILY"]);
}

- (void) test_unboundedRuleHasNeitherCountNorUntil
{
  iCalRecurrenceRule *rule;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  rule = [self _ruleWithContent: @"FREQ=DAILY"];

  test (![rule hasRepeatCount]);
  test ([rule untilDate] == nil);
}

- (void) test_recurrenceDatesOnlyEventIsRecurrentWithoutRule
{
  iCalCalendar *calendar;
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  calendar = [iCalCalendar parseSingleFromSource:
                          @"BEGIN:VCALENDAR\r\n"
                          @"VERSION:2.0\r\n"
                          @"BEGIN:VEVENT\r\n"
                          @"UID:test-5992-rdate\r\n"
                          @"SUMMARY:invitation\r\n"
                          @"DTSTART;TZID=W. Europe Standard Time:20240730T130000\r\n"
                          @"DTEND;TZID=W. Europe Standard Time:20240730T140000\r\n"
                          @"RDATE;TZID=W. Europe Standard Time:20240813T130000\r\n"
                          @"END:VEVENT\r\n"
                          @"END:VCALENDAR\r\n"];
  event = [[calendar events] objectAtIndex: 0];

  test ([event isRecurrent]);
  test ([[event recurrenceRules] count] == 0);
}

@end
