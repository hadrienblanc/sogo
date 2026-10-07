/* TestiCalEventChangesSequence.m - this file is part of SOGo
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGCards/iCalEventChanges.h>

#import "SOGoTest.h"

@interface iCalEventChanges (SOGoTestsDeclaration)
- (BOOL) sequenceShouldBeIncreased;
@end

@interface TestiCalEventChangesSequence : SOGoTest
@end

@implementation TestiCalEventChangesSequence

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

- (iCalEvent *) _eventWithSummary: (NSString *) summary
                          location: (NSString *) location
                       description: (NSString *) description
                          priority: (NSString *) priority
{
  NSMutableString *content;
  iCalCalendar *calendar;

  content = [NSMutableString stringWithString:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"
                         @"BEGIN:VEVENT\r\n"
                         @"UID:test-5774\r\n"
                         @"SEQUENCE:0\r\n"];
  [content appendFormat: @"SUMMARY:%@\r\n", summary];
  if (location)
    [content appendFormat: @"LOCATION:%@\r\n", location];
  if (description)
    [content appendFormat: @"DESCRIPTION:%@\r\n", description];
  if (priority)
    [content appendFormat: @"PRIORITY:%@\r\n", priority];
  [content appendString: @"DTSTART:20261015T100000Z\r\n"];
  [content appendString: @"DTEND:20261015T110000Z\r\n"];
  [content appendString: @"ORGANIZER;CN=Jean Dupont:mailto:jean@example.org\r\n"];
  [content appendString: @"ATTENDEE;CN=Mailbox One;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:mailbox-one@example.org\r\n"];
  [content appendString: @"END:VEVENT\r\n"
                        @"END:VCALENDAR\r\n"];

  calendar = [iCalCalendar parseSingleFromSource: content];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");

  return [[calendar events] objectAtIndex: 0];
}

- (void) test_descriptionOnlyChangeRequiresSequenceIncrease
{
  iCalEvent *oldEvent, *newEvent;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  oldEvent = [self _eventWithSummary: @"planning"
                             location: @"room 1"
                          description: @"initial agenda"
                             priority: nil];
  newEvent = [self _eventWithSummary: @"planning"
                             location: @"room 1"
                          description: @"revised agenda"
                             priority: nil];

  test ([[iCalEventChanges changesFromEvent: oldEvent  toEvent: newEvent]
          sequenceShouldBeIncreased] == YES);
}

- (void) test_summaryOnlyChangeRequiresSequenceIncrease
{
  iCalEvent *oldEvent, *newEvent;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  oldEvent = [self _eventWithSummary: @"planning"
                             location: @"room 1"
                          description: @"agenda"
                             priority: nil];
  newEvent = [self _eventWithSummary: @"roadmap"
                             location: @"room 1"
                          description: @"agenda"
                             priority: nil];

  test ([[iCalEventChanges changesFromEvent: oldEvent  toEvent: newEvent]
          sequenceShouldBeIncreased] == YES);
}

- (void) test_locationOnlyChangeRequiresSequenceIncrease
{
  iCalEvent *oldEvent, *newEvent;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  oldEvent = [self _eventWithSummary: @"planning"
                             location: @"room 1"
                          description: @"agenda"
                             priority: nil];
  newEvent = [self _eventWithSummary: @"planning"
                             location: @"room 2"
                          description: @"agenda"
                             priority: nil];

  test ([[iCalEventChanges changesFromEvent: oldEvent  toEvent: newEvent]
          sequenceShouldBeIncreased] == YES);
}

- (void) test_unchangedEventRequiresNoSequenceIncrease
{
  iCalEvent *oldEvent, *newEvent;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  oldEvent = [self _eventWithSummary: @"planning"
                             location: @"room 1"
                          description: @"agenda"
                             priority: nil];
  newEvent = [self _eventWithSummary: @"planning"
                             location: @"room 1"
                          description: @"agenda"
                             priority: nil];

  test ([[iCalEventChanges changesFromEvent: oldEvent  toEvent: newEvent]
          sequenceShouldBeIncreased] == NO);
}

- (void) test_priorityOnlyChangeRequiresNoSequenceIncrease
{
  iCalEvent *oldEvent, *newEvent;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  oldEvent = [self _eventWithSummary: @"planning"
                             location: @"room 1"
                          description: @"agenda"
                             priority: @"5"];
  newEvent = [self _eventWithSummary: @"planning"
                             location: @"room 1"
                          description: @"agenda"
                             priority: @"1"];

  test ([[iCalEventChanges changesFromEvent: oldEvent  toEvent: newEvent]
          sequenceShouldBeIncreased] == NO);
}

@end
