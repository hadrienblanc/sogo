/* TestiCalEntityObjectVersionCompare.m - this file is part of SOGo
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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING. If not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>

#import "SOGoTest.h"

@interface iCalEntityObject (SOGoTestsDeclaration)
- (NSComparisonResult) compare: (iCalEntityObject *) otherObject;
@end

@interface TestiCalEntityObjectVersionCompare : SOGoTest
@end

@implementation TestiCalEntityObjectVersionCompare

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

- (iCalEvent *) _eventWithSequence: (NSString *) sequence
                       lastModified: (NSString *) lastModified
{
  NSMutableString *content;

  content = [NSMutableString stringWithString:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"
                         @"BEGIN:VEVENT\r\n"
                         @"UID:test-6037\r\n"
                         @"SUMMARY:invitation\r\n"
                         @"DTSTART:20261015T100000Z\r\n"
                         @"DTEND:20261015T110000Z\r\n"];
  if (sequence)
    [content appendFormat: @"SEQUENCE:%@\r\n", sequence];
  if (lastModified)
    [content appendFormat: @"LAST-MODIFIED:%@\r\n", lastModified];
  [content appendString: @"END:VEVENT\r\n"
                        @"END:VCALENDAR\r\n"];

  return [[[self _calendarWithContent: content] events] objectAtIndex: 0];
}

- (void) test_higherSequenceRequestIsNewer
{
  iCalEvent *storedEvent, *updateEvent;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  storedEvent = [self _eventWithSequence: @"0"
                            lastModified: @"20261014T080000Z"];
  updateEvent = [self _eventWithSequence: @"1"
                            lastModified: @"20261014T080000Z"];

  test ([storedEvent compare: updateEvent] == NSOrderedAscending);
}

- (void) test_lowerSequenceRequestIsStale
{
  iCalEvent *storedEvent, *updateEvent;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  storedEvent = [self _eventWithSequence: @"2"
                            lastModified: @"20261014T080000Z"];
  updateEvent = [self _eventWithSequence: @"1"
                            lastModified: @"20261014T090000Z"];

  test ([storedEvent compare: updateEvent] == NSOrderedDescending);
}

- (void) test_sameSequenceNewerLastModifiedIsNewer
{
  iCalEvent *storedEvent, *updateEvent;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  storedEvent = [self _eventWithSequence: @"1"
                            lastModified: @"20261014T080000Z"];
  updateEvent = [self _eventWithSequence: @"1"
                            lastModified: @"20261014T090000Z"];

  test ([storedEvent compare: updateEvent] == NSOrderedAscending);
}

- (void) test_sameSequenceSameLastModifiedIsSameVersion
{
  iCalEvent *storedEvent, *updateEvent;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  storedEvent = [self _eventWithSequence: @"1"
                            lastModified: @"20261014T080000Z"];
  updateEvent = [self _eventWithSequence: @"1"
                            lastModified: @"20261014T080000Z"];

  test ([storedEvent compare: updateEvent] == NSOrderedSame);
}

- (void) test_missingSequenceFallsBackToLastModified
{
  iCalEvent *storedEvent, *updateEvent;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  storedEvent = [self _eventWithSequence: nil
                            lastModified: @"20261014T080000Z"];
  updateEvent = [self _eventWithSequence: nil
                            lastModified: @"20261014T090000Z"];

  test ([storedEvent compare: updateEvent] == NSOrderedAscending);
}

@end
