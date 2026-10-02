/* TestiCalToDo+ActiveSync.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalDateTime.h>
#import <NGCards/iCalToDo.h>

#import <NGObjWeb/WOContext.h>

#import "SOGoTest.h"

#import "iCalToDo+ActiveSync.h"

@interface TestiCalToDo_plus_ActiveSync : SOGoTest
@end

@implementation TestiCalToDo_plus_ActiveSync

- (iCalToDo *) _todo
{
  iCalCalendar *calendar;
  iCalToDo *todo;

  calendar = [iCalCalendar parseSingleFromSource:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"
                         @"BEGIN:VTODO\r\n"
                         @"UID:test-5911\r\n"
                         @"SUMMARY:ticket 5911\r\n"
                         @"END:VTODO\r\n"
                         @"END:VCALENDAR\r\n"];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");
  todo = [[calendar todos] objectAtIndex: 0];
  testWithMessage (todo != nil, @"no VTODO found in iCalendar content");

  return todo;
}

- (WOContext *) _context
{
  WOContext *context;

  context = [WOContext contextWithRequest: nil];
  [context setObject: @"16.1"  forKey: @"ASProtocolVersion"];

  return context;
}

- (void) test_completedTaskStoresUtcDateTime
{
  iCalToDo *todo;
  iCalDateTime *completed;

  todo = [self _todo];
  [todo takeActiveSyncValues:
          [NSDictionary dictionaryWithObjectsAndKeys:
                           @"1", @"Complete",
                           @"2024-01-04T08:35:00.000Z", @"DateCompleted",
                           nil]
                      inContext: [self _context]];

  completed = (iCalDateTime *) [todo uniqueChildWithTag: @"completed"];
  testEquals ([completed flattenedValuesForKey: @""], @"20240104T083500Z");
  testWithMessage (![completed isAllDay],
                   @"COMPLETED must be a DATE-TIME as per RFC 5545 §3.8.2.1");
  testEquals ([todo status], @"COMPLETED");
}

- (void) test_recompletingRewritesDateOnlyCompletedAsUtcDateTime
{
  iCalToDo *todo;
  iCalDateTime *completed;

  todo = [self _todo];
  [todo takeActiveSyncValues:
          [NSDictionary dictionaryWithObjectsAndKeys:
                           @"1", @"Complete",
                           @"2024-01-04T08:35:00.000Z", @"DateCompleted",
                           nil]
                      inContext: [self _context]];

  completed = (iCalDateTime *) [todo uniqueChildWithTag: @"completed"];
  [completed setDate: [@"2024-01-04T09:35:00.000Z" calendarDate]];

  [todo takeActiveSyncValues:
          [NSDictionary dictionaryWithObjectsAndKeys:
                           @"1", @"Complete",
                           @"2024-01-04T10:35:00.000Z", @"DateCompleted",
                           nil]
                      inContext: [self _context]];

  testEquals ([completed flattenedValuesForKey: @""], @"20240104T103500Z");
  testWithMessage(![completed isAllDay],
                  @"a rewrite must drop the VALUE=DATE parameter");
}

- (void) test_uncompletedTaskDropsCompletedAndStatus
{
  iCalToDo *todo;

  todo = [self _todo];
  [todo takeActiveSyncValues:
          [NSDictionary dictionaryWithObjectsAndKeys:
                           @"1", @"Complete",
                           @"2024-01-04T08:35:00.000Z", @"DateCompleted",
                           nil]
                      inContext: [self _context]];

  [todo takeActiveSyncValues:
          [NSDictionary dictionaryWithObject: @"0"
                                      forKey: @"Complete"]
                      inContext: [self _context]];

  testWithMessage ([todo completed] == nil,
                   @"uncompleting a task must clear COMPLETED");
  testEquals ([todo status], @"IN-PROCESS");
}

@end
