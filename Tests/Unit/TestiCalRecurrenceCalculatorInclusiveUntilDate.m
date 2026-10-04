/* TestiCalRecurrenceCalculatorInclusiveUntilDate.m - this file is part of SOGo
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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses/>.
 */


#import <NGCards/iCalRecurrenceRule.h>
#import <NGCards/iCalRecurrenceCalculator.h>
#import <NGCards/NSString+NGCards.h>

#import <NGExtensions/NGCalendarDateRange.h>
#import <NGExtensions/NSCalendarDate+misc.h>

#import "SOGoTest.h"

@interface TestiCalRecurrenceCalculatorInclusiveUntilDate : SOGoTest
@end

@implementation TestiCalRecurrenceCalculatorInclusiveUntilDate

- (void) test_dailyUntilOnOccurrenceDayBeforeStartTime
{
  NSArray *rules = [NSArray arrayWithObjects:
                              // bug 5946 - daily event 10:00-20:00, until set by the
                              // client at 06:00 UTC on the day of the second occurrence
                              [NSArray arrayWithObjects:
                                        @"20240601T100000Z",
                                        @"FREQ=DAILY;UNTIL=20240602T060000Z;WKST=MO",
                                        @"20240601T100000Z",
                                        @"20240602T100000Z",
                                        nil],
                              // no occurrence past the until day
                              [NSArray arrayWithObjects:
                                        @"20240601T220000Z",
                                        @"FREQ=DAILY;UNTIL=20240602T060000Z",
                                        @"20240601T220000Z",
                                        @"20240602T220000Z",
                                        nil],
                              nil];

  [self checkRules: rules];
}

- (void) test_weeklyUntilOnOccurrenceDayBeforeStartTime
{
  NSArray *rules = [NSArray arrayWithObjects:
                              [NSArray arrayWithObjects:
                                        @"20240604T100000Z",
                                        @"FREQ=WEEKLY;UNTIL=20240611T050000Z",
                                        @"20240604T100000Z",
                                        @"20240611T100000Z",
                                        nil],
                              nil];

  [self checkRules: rules];
}

- (void) test_monthlyUntilOnOccurrenceDayBeforeStartTime
{
  NSArray *rules = [NSArray arrayWithObjects:
                              [NSArray arrayWithObjects:
                                        @"20240601T100000Z",
                                        @"FREQ=MONTHLY;UNTIL=20240701T040000Z",
                                        @"20240601T100000Z",
                                        @"20240701T100000Z",
                                        nil],
                              nil];

  [self checkRules: rules];
}

- (void) test_yearlyUntilOnOccurrenceDayBeforeStartTime
{
  NSArray *rules = [NSArray arrayWithObjects:
                              [NSArray arrayWithObjects:
                                        @"20240601T100000Z",
                                        @"FREQ=YEARLY;UNTIL=20250601T040000Z",
                                        @"20240601T100000Z",
                                        @"20250601T100000Z",
                                        nil],
                              nil];

  [self checkRules: rules];
}

- (void) checkRules: (NSArray *) theRules
{
  NSString *dateFormat, *error;
  NGCalendarDateRange *firRange, *range;
  NSEnumerator *rulesList;
  NSArray *currentRule, *occurrences;
  NSCalendarDate *startDate, *endDate, *currentOccurrence;
  iCalRecurrenceRule *recurrenceRule;
  iCalRecurrenceCalculator *calculator;
  int i, j;

  dateFormat = @"%Y-%m-%d %H:%M";

  rulesList = [theRules objectEnumerator];
  while ((currentRule = [rulesList nextObject]))
    {
      startDate = [[currentRule objectAtIndex: 0] asCalendarDate];
      endDate = [startDate dateByAddingYears: 0 months: 0 days: 0 hours: 10 minutes: 0 seconds: 0];
      recurrenceRule = [iCalRecurrenceRule recurrenceRuleWithICalRepresentation: [currentRule objectAtIndex: 1]];

      firRange = [NGCalendarDateRange calendarDateRangeWithStartDate: startDate
                                                              endDate: endDate];
      calculator = [iCalRecurrenceCalculator recurrenceCalculatorForRecurrenceRule: recurrenceRule
                                        withFirstInstanceCalendarDateRange: firRange];
      range = [NGCalendarDateRange calendarDateRangeWithStartDate: startDate
                                                           endDate: [NSCalendarDate distantFuture]];
      occurrences = [calculator recurrenceRangesWithinCalendarDateRange: range];

      error = [NSString stringWithFormat: @"Unexpected number of occurrences for recurrence rule %@ (found %ld, expected %ld)",
                         [currentRule objectAtIndex: 1],
                         [occurrences count],
                         [currentRule count] - 2];
      testWithMessage([currentRule count] - [occurrences count] == 2, error);

      for (i = 2, j = 0; i < [currentRule count] && j < [occurrences count]; i++, j++)
        {
          currentOccurrence = [[currentRule objectAtIndex: i] asCalendarDate];
          error = [NSString stringWithFormat: @"Invalid occurrence for recurrence rule %@: %@ (expected date was %@)",
                             [currentRule objectAtIndex: 1],
                             [[[occurrences objectAtIndex: j] startDate] descriptionWithCalendarFormat: dateFormat],
                             [currentOccurrence descriptionWithCalendarFormat: dateFormat]];
          testWithMessage([currentOccurrence compare: [[occurrences objectAtIndex: j] startDate]] == NSOrderedSame,
                          error);
        }
    }
}

@end
