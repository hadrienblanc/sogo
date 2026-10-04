/* TestiCalTimeZoneSystemFallback.m - this file is part of SOGo
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

static NSString *tzMacMoscow =
  @"BEGIN:VCALENDAR\r\n"
  @"PRODID:-//Apple Inc.//Mac OS X 14.6.1//EN\r\n"
  @"VERSION:2.0\r\n"
  @"CALSCALE:GREGORIAN\r\n"
  @"BEGIN:VTIMEZONE\r\n"
  @"TZID:Europe/Moscow\r\n"
  @"BEGIN:STANDARD\r\n"
  @"DTSTART:20010101T000000\r\n"
  @"TZNAME:GMT+3\r\n"
  @"TZOFFSETFROM:+023017\r\n"
  @"TZOFFSETTO:+023017\r\n"
  @"END:STANDARD\r\n"
  @"END:VTIMEZONE\r\n"
  @"BEGIN:VEVENT\r\n"
  @"UID:test-6042-mac-moscow\r\n"
  @"DTSTAMP:20240923T161603Z\r\n"
  @"SUMMARY:Meeting\r\n"
  @"DTSTART;TZID=Europe/Moscow:20261020T120000\r\n"
  @"DTEND;TZID=Europe/Moscow:20261020T130000\r\n"
  @"END:VEVENT\r\n"
  @"END:VCALENDAR\r\n";

static NSString *tzCustomZone =
  @"BEGIN:VCALENDAR\r\n"
  @"VERSION:2.0\r\n"
  @"BEGIN:VTIMEZONE\r\n"
  @"TZID:Test/Sogo6042\r\n"
  @"BEGIN:STANDARD\r\n"
  @"DTSTART:19700101T000000\r\n"
  @"TZNAME:SO6042\r\n"
  @"TZOFFSETFROM:+0230\r\n"
  @"TZOFFSETTO:+0230\r\n"
  @"END:STANDARD\r\n"
  @"END:VTIMEZONE\r\n"
  @"BEGIN:VEVENT\r\n"
  @"UID:test-6042-custom-zone\r\n"
  @"DTSTAMP:20240923T161603Z\r\n"
  @"SUMMARY:Meeting\r\n"
  @"DTSTART;TZID=Test/Sogo6042:20261020T120000\r\n"
  @"DTEND;TZID=Test/Sogo6042:20261020T130000\r\n"
  @"END:VEVENT\r\n"
  @"END:VCALENDAR\r\n";

@interface TestiCalTimeZoneSystemFallback : SOGoTest
@end

@implementation TestiCalTimeZoneSystemFallback

- (void) test_macLmtTimezoneOffset
{
  iCalTimeZone *timeZone;
  iCalTimeZonePeriod *period;

  timeZone = [iCalTimeZone timeZoneForName: @"Europe/Moscow"];
  testWithMessage (timeZone != nil,
                   @"Europe/Moscow must resolve on the server side");

  period = [timeZone periodForDate: [@"20261020T120000" asCalendarDate]];
  testWithMessage ([period secondsOffsetFromGMT] == 10800,
                   @"Moscow must be +0300 in 2026, not the 1880 LMT +023017");
}

- (void) test_macLmtEventDates
{
  iCalCalendar *calendar;
  iCalEvent *event;

  calendar = [iCalCalendar parseSingleFromSource: tzMacMoscow];
  event = [[calendar events] lastObject];
  testWithMessage ((NSInteger) [[event startDate] timeIntervalSince1970]
                     == 1792486800,
                   @"12:00 Moscow on 2026-10-20 must be stored as 09:00 UTC");
  testWithMessage ((NSInteger) [[event endDate] timeIntervalSince1970]
                     == 1792490400,
                   @"13:00 Moscow on 2026-10-20 must be stored as 10:00 UTC");
}

- (void) test_dstOffsets
{
  iCalTimeZone *timeZone;
  iCalTimeZonePeriod *period;

  timeZone = [iCalTimeZone timeZoneForName: @"Europe/Berlin"];
  testWithMessage (timeZone != nil,
                   @"Europe/Berlin must resolve on the server side");

  period = [timeZone periodForDate: [@"20250715T120000" asCalendarDate]];
  testWithMessage ([period secondsOffsetFromGMT] == 7200,
                   @"Berlin must be +0200 in summer");

  period = [timeZone periodForDate: [@"20260115T120000" asCalendarDate]];
  testWithMessage ([period secondsOffsetFromGMT] == 3600,
                   @"Berlin must be +0100 in winter");
}

- (void) test_inlineTimezoneStillUsedForUnknownTzId
{
  iCalCalendar *calendar;
  iCalEvent *event;

  calendar = [iCalCalendar parseSingleFromSource: tzCustomZone];
  event = [[calendar events] lastObject];
  testWithMessage ((NSInteger) [[event startDate] timeIntervalSince1970]
                     == 1792488600,
                   @"12:00 at +0230 must be stored as 09:30 UTC");
}

@end
