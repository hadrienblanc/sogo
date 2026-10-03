/* TestiCalEntityObjectResetCreationMetadata.m - this file is part of SOGo
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
#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalToDo.h>

#import "SOGoTest.h"

@interface iCalEntityObject (SOGoTestsDeclaration)
- (void) resetCreationMetadata;
@end

@interface TestiCalEntityObjectResetCreationMetadata : SOGoTest
@end

@implementation TestiCalEntityObjectResetCreationMetadata

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (iCalCalendar *) _calendarWithContent: (NSString *) content
{
  iCalCalendar *calendar;

  calendar = [iCalCalendar parseSingleFromSource: content];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");

  return calendar;
}

- (iCalEvent *) _copiedEventWithSequence
{
  iCalEvent *event;

  event = [[[self _calendarWithContent:
                          @"BEGIN:VCALENDAR\r\n"
                          @"VERSION:2.0\r\n"
                          @"BEGIN:VEVENT\r\n"
                          @"UID:test-6085-event\r\n"
                          @"SUMMARY:test 6085\r\n"
                          @"CLASS:PUBLIC\r\n"
                          @"TRANSP:OPAQUE\r\n"
                          @"DTSTART;TZID=Europe/Berlin:20260204T220000\r\n"
                          @"DTEND;TZID=Europe/Berlin:20260204T230000\r\n"
                          @"CREATED:20250204T214712Z\r\n"
                          @"DTSTAMP:20250204T214712Z\r\n"
                          @"LAST-MODIFIED:20250204T215223Z\r\n"
                          @"SEQUENCE:4\r\n"
                          @"END:VEVENT\r\n"
                          @"END:VCALENDAR\r\n"] events] objectAtIndex: 0];
  testWithMessage (event != nil, @"no VEVENT found in iCalendar content");
  [event resetCreationMetadata];

  return event;
}

- (void) test_sequenceIsRemoved
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _copiedEventWithSequence];

  testEquals ([NSNumber numberWithUnsignedInt: [[event childrenWithTag: @"sequence"] count]],
              [NSNumber numberWithUnsignedInt: 0]);
}

- (void) test_datesAreRenewedAtCopyTime
{
  NSCalendarDate *reference;
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  reference = [[NSCalendarDate calendarDate] addTimeInterval: -60];
  event = [self _copiedEventWithSequence];

  testWithMessage ([[event created] compare: reference] != NSOrderedAscending,
                   @"CREATED must be renewed at copy time");
  testWithMessage ([[event lastModified] compare: reference] != NSOrderedAscending,
                   @"LAST-MODIFIED must be renewed at copy time");
  testWithMessage ([[event timeStampAsDate] compare: reference] != NSOrderedAscending,
                   @"DTSTAMP must be renewed at copy time");
  testEquals ([event created], [event lastModified]);
  testEquals ([event created], [event timeStampAsDate]);
}

- (void) test_versitRenderingHasNoSequence
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _copiedEventWithSequence];

  test ([[[event parent] versitString] rangeOfString: @"SEQUENCE"].location
          == NSNotFound);
}

- (void) test_eventWithoutSequenceStaysWithoutSequence
{
  iCalCalendar *calendar;
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  calendar = [self _calendarWithContent:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"
                         @"BEGIN:VEVENT\r\n"
                         @"UID:test-6085-nosequence\r\n"
                         @"SUMMARY:test 6085\r\n"
                         @"DTSTART;VALUE=DATE:20260430\r\n"
                         @"DTEND;VALUE=DATE:20260501\r\n"
                         @"CREATED:20250204T214712Z\r\n"
                         @"DTSTAMP:20250204T214712Z\r\n"
                         @"LAST-MODIFIED:20250204T215223Z\r\n"
                         @"END:VEVENT\r\n"
                         @"END:VCALENDAR\r\n"];
  event = [[calendar events] objectAtIndex: 0];
  [event resetCreationMetadata];

  testEquals ([NSNumber numberWithUnsignedInt: [[event childrenWithTag: @"sequence"] count]],
              [NSNumber numberWithUnsignedInt: 0]);
}

- (void) test_todoMetadataIsReset
{
  iCalCalendar *calendar;
  iCalToDo *todo;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  calendar = [self _calendarWithContent:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"
                         @"BEGIN:VTODO\r\n"
                         @"UID:test-6085-todo\r\n"
                         @"SUMMARY:test 6085\r\n"
                         @"DTSTART;VALUE=DATE:20260430\r\n"
                         @"DUE;VALUE=DATE:20260501\r\n"
                         @"CREATED:20250204T214712Z\r\n"
                         @"DTSTAMP:20250204T214712Z\r\n"
                         @"LAST-MODIFIED:20250204T215223Z\r\n"
                         @"SEQUENCE:4\r\n"
                         @"END:VTODO\r\n"
                         @"END:VCALENDAR\r\n"];
  todo = [[calendar todos] objectAtIndex: 0];
  [todo resetCreationMetadata];

  testEquals ([NSNumber numberWithUnsignedInt: [[todo childrenWithTag: @"sequence"] count]],
              [NSNumber numberWithUnsignedInt: 0]);
  testWithMessage ([todo created] != nil, @"CREATED must remain defined on a copied task");
  testWithMessage ([todo lastModified] != nil, @"LAST-MODIFIED must remain defined on a copied task");
  test ([[[todo parent] versitString] rangeOfString: @"SEQUENCE"].location
          == NSNotFound);
}

@end
