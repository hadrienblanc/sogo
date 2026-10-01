/* TestNSCalendarDateClamping.m - this file is part of SOGo
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
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#include <limits.h>

#import <Foundation/NSCalendarDate.h>

#import <NGCards/NSString+NGCards.h>

#import <SOGo/NSCalendarDate+SOGo.h>

#import "SOGoTest.h"

@interface TestNSCalendarDateClamping : SOGoTest
@end

@implementation TestNSCalendarDateClamping

- (void) test_clampBelowIntMin
{
  NSCalendarDate *date, *clamped;

  date = [NSCalendarDate dateWithTimeIntervalSince1970: -3000000000.0];
  clamped = [date dateByClampingToInt32EpochRange];
  testWithMessage ((long long) [clamped timeIntervalSince1970]
                   == (long long) INT_MIN,
                   ([NSString stringWithFormat:
                              @"expected %lld, got %lld",
                              (long long) INT_MIN,
                              (long long) [clamped timeIntervalSince1970]]));

  date = [NSCalendarDate dateWithTimeIntervalSince1970: -2147483649.0];
  clamped = [date dateByClampingToInt32EpochRange];
  testWithMessage ((long long) [clamped timeIntervalSince1970]
                   == (long long) INT_MIN,
                   ([NSString stringWithFormat:
                              @"expected %lld, got %lld",
                              (long long) INT_MIN,
                              (long long) [clamped timeIntervalSince1970]]));
}

- (void) test_clampAboveIntMax
{
  NSCalendarDate *date, *clamped;

  date = [NSCalendarDate dateWithTimeIntervalSince1970: 3000000000.0];
  clamped = [date dateByClampingToInt32EpochRange];
  testWithMessage ((long long) [clamped timeIntervalSince1970]
                   == (long long) INT_MAX,
                   ([NSString stringWithFormat:
                              @"expected %lld, got %lld",
                              (long long) INT_MAX,
                              (long long) [clamped timeIntervalSince1970]]));

  date = [NSCalendarDate dateWithTimeIntervalSince1970: 2147483648.0];
  clamped = [date dateByClampingToInt32EpochRange];
  testWithMessage ((long long) [clamped timeIntervalSince1970]
                   == (long long) INT_MAX,
                   ([NSString stringWithFormat:
                              @"expected %lld, got %lld",
                              (long long) INT_MAX,
                              (long long) [clamped timeIntervalSince1970]]));
}

- (void) test_noClampInsideRange
{
  NSCalendarDate *date, *clamped;

  date = [NSCalendarDate dateWithTimeIntervalSince1970: (double) INT_MIN];
  clamped = [date dateByClampingToInt32EpochRange];
  testWithMessage ((long long) [clamped timeIntervalSince1970]
                   == (long long) INT_MIN,
                   ([NSString stringWithFormat:
                              @"expected %lld, got %lld",
                              (long long) INT_MIN,
                              (long long) [clamped timeIntervalSince1970]]));

  date = [NSCalendarDate dateWithTimeIntervalSince1970: (double) INT_MAX];
  clamped = [date dateByClampingToInt32EpochRange];
  testWithMessage ((long long) [clamped timeIntervalSince1970]
                   == (long long) INT_MAX,
                   ([NSString stringWithFormat:
                              @"expected %lld, got %lld",
                              (long long) INT_MAX,
                              (long long) [clamped timeIntervalSince1970]]));

  date = [NSCalendarDate dateWithTimeIntervalSince1970: 1577836800.0];
  clamped = [date dateByClampingToInt32EpochRange];
  testWithMessage ((long long) [clamped timeIntervalSince1970]
                   == 1577836800LL,
                   ([NSString stringWithFormat:
                              @"expected %lld, got %lld",
                              1577836800LL,
                              (long long) [clamped timeIntervalSince1970]]));
}

- (void) test_clampOnDAVTimeRangeEdges
{
  NSString *timeRangeStarts[] = { @"18850626T155414Z",
                                  @"19011213T214551Z",
                                  @"19011213T214552Z",
                                  @"20200101T000000Z",
                                  @"99991231T235959Z" };
  long long expectedBounds[] = { (long long) INT_MIN, 0, 0, 1577836800LL,
                                 (long long) INT_MAX };
  unsigned count, max;
  NSCalendarDate *parsed, *validated;

  max = sizeof (timeRangeStarts) / sizeof (NSString *);
  for (count = 0; count < max; count++)
    {
      parsed = [timeRangeStarts[count] asCalendarDate];
      validated = [parsed dateByClampingToInt32EpochRange];
      testWithMessage (((long long) [validated timeIntervalSince1970]
                        >= (long long) INT_MIN)
                       && ((long long) [validated timeIntervalSince1970]
                           <= (long long) INT_MAX),
                       ([NSString stringWithFormat:
                                  @"time-range start %@ validated to %lld,"
                                  @" outside of the int32 range",
                                  timeRangeStarts[count],
                                  (long long) [validated
                                    timeIntervalSince1970]]));
      if (expectedBounds[count] != 0)
        testWithMessage ((long long) [validated timeIntervalSince1970]
                         == expectedBounds[count],
                         ([NSString stringWithFormat:
                                    @"time-range start %@ validated to %lld,"
                                    @" expected %lld",
                                    timeRangeStarts[count],
                                    (long long) [validated
                                      timeIntervalSince1970],
                                    expectedBounds[count]]));
    }
}

- (void) test_clampOnDistantLimits
{
  NSCalendarDate *validated;

  validated = [[NSCalendarDate distantPast] dateByClampingToInt32EpochRange];
  testWithMessage (((long long) [validated timeIntervalSince1970]
                    >= (long long) INT_MIN)
                   && ((long long) [validated timeIntervalSince1970]
                       <= (long long) INT_MAX),
                   @"distantPast is not within the int32 range");

  validated = [[NSCalendarDate distantFuture] dateByClampingToInt32EpochRange];
  testWithMessage (((long long) [validated timeIntervalSince1970]
                    >= (long long) INT_MIN)
                   && ((long long) [validated timeIntervalSince1970]
                       <= (long long) INT_MAX),
                   @"distantFuture is not within the int32 range");
}

@end
