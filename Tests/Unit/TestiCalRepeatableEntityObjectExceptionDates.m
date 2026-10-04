/* TestiCalRepeatableEntityObjectExceptionDates.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/NSString+NGCards.h>

#import "SOGoTest.h"

@interface TestiCalRepeatableEntityObjectExceptionDates : SOGoTest
@end

@implementation TestiCalRepeatableEntityObjectExceptionDates

- (iCalEvent *) _weeklyEventWithExdates: (NSString *) exdateLines
{
  iCalCalendar *calendar;
  iCalEvent *event;

  calendar = [iCalCalendar parseSingleFromSource:
                           [NSString stringWithFormat:
                                     @"BEGIN:VCALENDAR\r\n"
                                     @"VERSION:2.0\r\n"
                                     @"BEGIN:VTIMEZONE\r\n"
                                     @"TZID:Test/Simple\r\n"
                                     @"BEGIN:STANDARD\r\n"
                                     @"TZOFFSETTO:+020000\r\n"
                                     @"TZOFFSETFROM:+020000\r\n"
                                     @"TZNAME:Test/Simple(STD)\r\n"
                                     @"DTSTART:19700101T000000\r\n"
                                     @"RDATE:19700101T000000\r\n"
                                     @"END:STANDARD\r\n"
                                     @"END:VTIMEZONE\r\n"
                                     @"BEGIN:VEVENT\r\n"
                                     @"UID:test-6062-exdates\r\n"
                                     @"DTSTAMP:20241101T073655Z\r\n"
                                     @"DTSTART:20241001T090000Z\r\n"
                                     @"DTEND:20241001T093000Z\r\n"
                                     @"RRULE:FREQ=WEEKLY\r\n"
                                     @"SUMMARY:test 6062\r\n"
                                     @"%@\r\n"
                                     @"END:VEVENT\r\n"
                                     @"END:VCALENDAR\r\n",
                                     exdateLines]];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");
  event = [[calendar events] objectAtIndex: 0];
  testWithMessage (event != nil, @"no VEVENT found in iCalendar content");

  return event;
}

- (NSArray *) _exdateLinesOfRenderedCalendar: (iCalEvent *) event
{
  NSMutableArray *lines;
  NSEnumerator *e;
  NSString *line;

  lines = [NSMutableArray array];
  e = [[[[event parent] versitString] componentsSeparatedByString: @"\r\n"] objectEnumerator];
  while ((line = [e nextObject]))
    if ([line hasPrefix: @"EXDATE"])
      [lines addObject: line];

  return lines;
}

- (void) test_addToExceptionDatesIgnoresDuplicateDates
{
  NSArray *expectedLines;
  iCalEvent *event;

  event = [self _weeklyEventWithExdates: @"EXDATE:20241015T070000Z"];

  [event addToExceptionDates: [@"20241015T070000Z" asCalendarDate]];
  testEquals ([self _exdateLinesOfRenderedCalendar: event],
              [NSArray arrayWithObject: @"EXDATE:20241015T070000Z"]);

  [event addToExceptionDates: [@"20241022T070000Z" asCalendarDate]];
  expectedLines = [NSArray arrayWithObjects: @"EXDATE:20241015T070000Z", @"EXDATE:20241022T070000Z", nil];
  testEquals ([self _exdateLinesOfRenderedCalendar: event], expectedLines);
}

- (void) test_addToExceptionDatesIgnoresDuplicatesAcrossRepresentations
{
  iCalEvent *event;

  event = [self _weeklyEventWithExdates: @"EXDATE;TZID=Test/Simple:20241015T090000"];

  [event addToExceptionDates: [[@"20241015T090000" asCalendarDate] addTimeInterval: -7200]];
  testEquals ([self _exdateLinesOfRenderedCalendar: event],
              [NSArray arrayWithObject: @"EXDATE;TZID=Test/Simple:20241015T090000"]);

  [event addToExceptionDates: [@"20241022T070000Z" asCalendarDate]];
  testWithMessage ([[event exceptionDates] count] == 2, @"a distinct exception date must be stored");
}

- (void) test_exceptionDatesReturnsEachExcludedDateOnce
{
  NSArray *expectedDates;
  iCalEvent *event;

  expectedDates = [NSArray arrayWithObjects: @"20241015T070000Z", @"20241022T070000Z", @"20241029T070000Z", nil];

  event = [self _weeklyEventWithExdates:
                     @"EXDATE:20241015T070000Z\r\n"
                     @"EXDATE:20241015T070000Z\r\n"
                     @"EXDATE:20241022T070000Z,20241029T070000Z\r\n"
                     @"EXDATE;TZID=Test/Simple:20241015T090000"];

  testEquals ([event exceptionDates], expectedDates);
}

- (void) test_rewriteKeepsPackedExceptionDatesAndDropsDuplicates
{
  NSArray *expectedDates, *expectedLines, *currentDates;
  NSMutableArray *newDates;
  NSEnumerator *e;
  iCalEvent *event;
  iCalDateTime *child;
  unsigned int i;

  expectedDates = [NSArray arrayWithObjects: @"20241015T070000Z", @"20241022T070000Z", @"20241029T070000Z", nil];
  expectedLines = [NSArray arrayWithObjects: @"EXDATE:20241015T070000Z", @"EXDATE:20241022T070000Z", @"EXDATE:20241029T070000Z", nil];

  event = [self _weeklyEventWithExdates:
                     @"EXDATE:20241015T070000Z\r\n"
                     @"EXDATE:20241015T070000Z\r\n"
                     @"EXDATE:20241022T070000Z,20241029T070000Z\r\n"
                     @"EXDATE;TZID=Test/Simple:20241015T090000"];

  newDates = [NSMutableArray array];
  e = [[event childrenWithTag: @"exdate"] objectEnumerator];
  while ((child = [e nextObject]))
    {
      currentDates = [child dateTimes];
      for (i = 0; i < [currentDates count]; i++)
        [newDates addObject: [currentDates objectAtIndex: i]];
    }

  [event removeAllExceptionDates];
  for (i = 0; i < [newDates count]; i++)
    [event addToExceptionDates: [newDates objectAtIndex: i]];

  testEquals ([self _exdateLinesOfRenderedCalendar: event], expectedLines);
  testEquals ([event exceptionDates], expectedDates);
}

@end
