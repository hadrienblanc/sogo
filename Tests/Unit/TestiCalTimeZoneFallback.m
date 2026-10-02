/* TestiCalTimeZoneFallback.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Alinto
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

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalTimeZone.h>
#import <NGCards/iCalTimeZonePeriod.h>
#import <NGCards/NSString+NGCards.h>

#import "SOGoTest.h"

static NSString *tzMozilla =
  @"BEGIN:VCALENDAR\r\n"
  @"VERSION:2.0\r\n"
  @"BEGIN:VTIMEZONE\r\n"
  @"TZID:America/Sao_Paulo\r\n"
  @"X-TZINFO:America/Sao_Paulo[2024b]\r\n"
  @"BEGIN:STANDARD\r\n"
  @"TZOFFSETTO:-030000\r\n"
  @"TZOFFSETFROM:-030628\r\n"
  @"TZNAME:America/Sao_Paulo(STD)\r\n"
  @"DTSTART:19140101T000000\r\n"
  @"RDATE:19140101T000000\r\n"
  @"END:STANDARD\r\n"
  @"BEGIN:DAYLIGHT\r\n"
  @"TZOFFSETTO:-020000\r\n"
  @"TZOFFSETFROM:-030000\r\n"
  @"TZNAME:America/Sao_Paulo(DST)\r\n"
  @"DTSTART:19311003T110000\r\n"
  @"RDATE:19311003T110000\r\n"
  @"END:DAYLIGHT\r\n"
  @"BEGIN:STANDARD\r\n"
  @"TZOFFSETTO:-030000\r\n"
  @"TZOFFSETFROM:-020000\r\n"
  @"TZNAME:America/Sao_Paulo(STD)\r\n"
  @"DTSTART:19320401T000000\r\n"
  @"RDATE:19320401T000000\r\n"
  @"END:STANDARD\r\n"
  @"BEGIN:DAYLIGHT\r\n"
  @"TZOFFSETTO:-020000\r\n"
  @"TZOFFSETFROM:-030000\r\n"
  @"TZNAME:America/Sao_Paulo(DST)\r\n"
  @"DTSTART:20081019T000000\r\n"
  @"RRULE:FREQ=YEARLY;UNTIL=20171015T000000;BYMONTH=10;BYDAY=3SU\r\n"
  @"END:DAYLIGHT\r\n"
  @"BEGIN:DAYLIGHT\r\n"
  @"TZOFFSETTO:-020000\r\n"
  @"TZOFFSETFROM:-030000\r\n"
  @"TZNAME:America/Sao_Paulo(DST)\r\n"
  @"DTSTART:20181104T000000\r\n"
  @"RDATE:20181104T000000\r\n"
  @"END:DAYLIGHT\r\n"
  @"BEGIN:STANDARD\r\n"
  @"TZOFFSETTO:-030000\r\n"
  @"TZOFFSETFROM:-020000\r\n"
  @"TZNAME:America/Sao_Paulo(STD)\r\n"
  @"DTSTART:20160221T000000\r\n"
  @"RRULE:FREQ=YEARLY;UNTIL=20190217T000000;BYMONTH=2;BYDAY=3SU\r\n"
  @"END:STANDARD\r\n"
  @"END:VTIMEZONE\r\n"
  @"BEGIN:VEVENT\r\n"
  @"UID:test-6133-mozilla\r\n"
  @"DTSTAMP:20250611T193820Z\r\n"
  @"SUMMARY:Meeting\r\n"
  @"DTSTART;TZID=America/Sao_Paulo:20250624T110000\r\n"
  @"DTEND;TZID=America/Sao_Paulo:20250624T120000\r\n"
  @"END:VEVENT\r\n"
  @"END:VCALENDAR\r\n";

static NSString *tzEvolution =
  @"BEGIN:VCALENDAR\r\n"
  @"CALSCALE:GREGORIAN\r\n"
  @"VERSION:2.0\r\n"
  @"BEGIN:VTIMEZONE\r\n"
  @"TZID:America/Sao_Paulo\r\n"
  @"X-LIC-LOCATION:America/Sao_Paulo\r\n"
  @"BEGIN:STANDARD\r\n"
  @"TZNAME:-03\r\n"
  @"TZOFFSETFROM:-0200\r\n"
  @"TZOFFSETTO:-0300\r\n"
  @"DTSTART:20130217T000000\r\n"
  @"RRULE:FREQ=YEARLY;UNTIL=20190217T020000Z;BYDAY=SU;"
  @"BYMONTHDAY=17,18,19,21,22;BYMONTH=2\r\n"
  @"END:STANDARD\r\n"
  @"BEGIN:DAYLIGHT\r\n"
  @"TZNAME:-02\r\n"
  @"TZOFFSETFROM:-0300\r\n"
  @"TZOFFSETTO:-0200\r\n"
  @"DTSTART:20181104T000000\r\n"
  @"END:DAYLIGHT\r\n"
  @"END:VTIMEZONE\r\n"
  @"BEGIN:VEVENT\r\n"
  @"UID:test-6133-evolution\r\n"
  @"DTSTAMP:20250710T000756Z\r\n"
  @"SUMMARY:Meeting\r\n"
  @"DTSTART;TZID=America/Sao_Paulo:20250710T100000\r\n"
  @"DTEND;TZID=America/Sao_Paulo:20250710T103000\r\n"
  @"END:VEVENT\r\n"
  @"END:VCALENDAR\r\n";

static NSString *tzBerlin =
  @"BEGIN:VCALENDAR\r\n"
  @"VERSION:2.0\r\n"
  @"BEGIN:VTIMEZONE\r\n"
  @"TZID:Europe/Berlin\r\n"
  @"BEGIN:DAYLIGHT\r\n"
  @"TZOFFSETFROM:+0100\r\n"
  @"TZOFFSETTO:+0200\r\n"
  @"TZNAME:CEST\r\n"
  @"DTSTART:19700329T020000\r\n"
  @"RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU\r\n"
  @"END:DAYLIGHT\r\n"
  @"BEGIN:STANDARD\r\n"
  @"TZOFFSETFROM:+0200\r\n"
  @"TZOFFSETTO:+0100\r\n"
  @"TZNAME:CET\r\n"
  @"DTSTART:19701025T030000\r\n"
  @"RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU\r\n"
  @"END:STANDARD\r\n"
  @"END:VTIMEZONE\r\n"
  @"END:VCALENDAR\r\n";

@interface TestiCalTimeZoneFallback : SOGoTest
@end

@implementation TestiCalTimeZoneFallback

- (void) test_offsetBeyondLastTransition
{
  iCalCalendar *calendar;
  iCalTimeZone *timeZone;
  iCalTimeZonePeriod *period;
  NSCalendarDate *date;

  calendar = [iCalCalendar parseSingleFromSource: tzMozilla];
  timeZone = [calendar timeZoneWithId: @"America/Sao_Paulo"];

  date = [@"20250624T110000" asCalendarDate];
  period = [timeZone periodForDate: date];
  testWithMessage ([period secondsOffsetFromGMT] == -10800,
                   @"Sao Paulo must be -0300 in 2025 (no DST since 2019)");

  date = [@"20190310T110000" asCalendarDate];
  period = [timeZone periodForDate: date];
  testWithMessage ([period secondsOffsetFromGMT] == -10800,
                   @"Sao Paulo must be -0300 right after the final 2019 transition");

  date = [@"20181110T110000" asCalendarDate];
  period = [timeZone periodForDate: date];
  testWithMessage ([period secondsOffsetFromGMT] == -7200,
                   @"Sao Paulo must still honor the 2018 daylight period");

  date = [@"20150624T110000" asCalendarDate];
  period = [timeZone periodForDate: date];
  testWithMessage ([period secondsOffsetFromGMT] == -10800,
                   @"Sao Paulo must be -0300 during southern winter 2015");

  calendar = [iCalCalendar parseSingleFromSource: tzEvolution];
  timeZone = [calendar timeZoneWithId: @"America/Sao_Paulo"];

  date = [@"20250710T100000" asCalendarDate];
  period = [timeZone periodForDate: date];
  testWithMessage ([period secondsOffsetFromGMT] == -10800,
                   @"Evolution-style Sao Paulo must be -0300 in 2025");

  date = [@"20181110T100000" asCalendarDate];
  period = [timeZone periodForDate: date];
  testWithMessage ([period secondsOffsetFromGMT] == -7200,
                   @"Evolution-style Sao Paulo must be -0200 during DST 2018");
}

- (void) test_eventStartDateBeyondLastTransition
{
  iCalCalendar *calendar;
  iCalEvent *event;

  calendar = [iCalCalendar parseSingleFromSource: tzMozilla];
  event = [[calendar events] lastObject];
  testWithMessage ((NSInteger) [[event startDate] timeIntervalSince1970]
                     == 1750773600,
                   @"11:00 Sao Paulo on 2025-06-24 must be stored as 14:00 UTC");
  testWithMessage ((NSInteger) [[event endDate] timeIntervalSince1970]
                     == 1750777200,
                   @"12:00 Sao Paulo on 2025-06-24 must be stored as 15:00 UTC");

  calendar = [iCalCalendar parseSingleFromSource: tzEvolution];
  event = [[calendar events] lastObject];
  testWithMessage ((NSInteger) [[event startDate] timeIntervalSince1970]
                     == 1752152400,
                   @"10:00 Sao Paulo on 2025-07-10 must be stored as 13:00 UTC");
  testWithMessage ((NSInteger) [[event endDate] timeIntervalSince1970]
                     == 1752154200,
                   @"10:30 Sao Paulo on 2025-07-10 must be stored as 13:30 UTC");
}

- (void) test_offsetWithRecurringRules
{
  iCalCalendar *calendar;
  iCalTimeZone *timeZone;
  iCalTimeZonePeriod *period;

  calendar = [iCalCalendar parseSingleFromSource: tzBerlin];
  timeZone = [calendar timeZoneWithId: @"Europe/Berlin"];

  period = [timeZone periodForDate: [@"20250624T110000" asCalendarDate]];
  testWithMessage ([period secondsOffsetFromGMT] == 7200,
                   @"Berlin must be +0200 in summer");

  period = [timeZone periodForDate: [@"20250124T110000" asCalendarDate]];
  testWithMessage ([period secondsOffsetFromGMT] == 3600,
                   @"Berlin must be +0100 in winter");
}

@end
