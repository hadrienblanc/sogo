/* TestiCalToDoAttributes.m - this file is part of SOGo
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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalToDo.h>

#import <SOGo/NSCalendarDate+SOGo.h>

#import "SOGoTest.h"

@class WOContext;

@interface iCalToDo (SOGoTestsDeclaration)
- (NSDictionary *) attributesInContext: (WOContext *) context;
@end

@interface TestiCalToDoAttributes : SOGoTest
@end

@implementation TestiCalToDoAttributes

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (void) setUp
{
  [[NSUserDefaults standardUserDefaults]
    registerDefaults: [NSDictionary dictionaryWithObject: @"127.0.0.1:11211"
                                                  forKey: @"SOGoMemcachedHost"]];
}

- (iCalToDo *) _todoWithContent: (NSString *) content
{
  iCalCalendar *calendar;
  iCalToDo *todo;

  calendar = [iCalCalendar parseSingleFromSource: content];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");
  todo = [[calendar todos] objectAtIndex: 0];
  testWithMessage (todo != nil, @"no VTODO found in iCalendar content");

  return todo;
}

- (void) test_dueDateOnlyTaskExposesDueDateAndComponent
{
  iCalToDo *todo;
  NSCalendarDate *dueDate;
  NSDictionary *data;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  todo = [self _todoWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VTODO\r\n"
                     @"UID:test-5779-due\r\n"
                     @"SUMMARY:test 5779\r\n"
                     @"DUE:20261008T150000Z\r\n"
                     @"END:VTODO\r\n"
                     @"END:VCALENDAR\r\n"];
  data = [todo attributesInContext: nil];

  dueDate = [todo due];
  [dueDate setTimeZone: nil];

  testEquals ([data objectForKey: @"component"], @"vtodo");
  testEquals ([data objectForKey: @"dueDate"], [dueDate iso8601DateString]);
  test ([data objectForKey: @"startDate"] == nil);
}

- (void) test_taskWithStartAndDueDatesExposesBoth
{
  iCalToDo *todo;
  NSCalendarDate *startDate, *dueDate;
  NSDictionary *data;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  todo = [self _todoWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VTODO\r\n"
                     @"UID:test-5779-startdue\r\n"
                     @"SUMMARY:test 5779\r\n"
                     @"DTSTART:20261008T090000Z\r\n"
                     @"DUE:20261008T150000Z\r\n"
                     @"END:VTODO\r\n"
                     @"END:VCALENDAR\r\n"];
  data = [todo attributesInContext: nil];

  startDate = [todo startDate];
  [startDate setTimeZone: nil];
  dueDate = [todo due];
  [dueDate setTimeZone: nil];

  testEquals ([data objectForKey: @"startDate"], [startDate iso8601DateString]);
  testEquals ([data objectForKey: @"dueDate"], [dueDate iso8601DateString]);
}

@end
