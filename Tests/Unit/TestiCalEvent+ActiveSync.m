/* TestiCalEvent+ActiveSync.m - this file is part of SOGo
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
#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>

#import <NGObjWeb/WOContext.h>

#import "SOGoTest.h"

#import "iCalEvent+ActiveSync.h"

@interface TestiCalEvent_plus_ActiveSync : SOGoTest
@end

@implementation TestiCalEvent_plus_ActiveSync

- (iCalEvent *) _eventWithContent: (NSString *) content
{
  iCalCalendar *calendar;
  iCalEvent *event;

  calendar = [iCalCalendar parseSingleFromSource: content];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");
  event = [[calendar events] objectAtIndex: 0];
  testWithMessage (event != nil, @"no VEVENT found in iCalendar content");

  return event;
}

- (WOContext *) _contextWithProtocolVersion: (NSString *) version
{
  WOContext *context;

  context = [WOContext contextWithRequest: nil];
  [context setObject: version  forKey: @"ASProtocolVersion"];

  return context;
}

- (iCalEvent *) _attendeeEvent
{
  return [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-6156-attendee\r\n"
                     @"SUMMARY:Termin\r\n"
                     @"DTSTART:20251029T130000Z\r\n"
                     @"DTEND:20251029T140000Z\r\n"
                     @"ORGANIZER;CN=Beate Luther:mailto:beate@example.com\r\n"
                     @"ATTENDEE;CN=Office;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:office@example.com\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];
}

- (iCalEvent *) _allDayAttendeeEvent
{
  return [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-6156-allday\r\n"
                     @"SUMMARY:Termin\r\n"
                     @"DTSTART;VALUE=DATE:20251029\r\n"
                     @"DTEND;VALUE=DATE:20251030\r\n"
                     @"ORGANIZER;CN=Beate Luther:mailto:beate@example.com\r\n"
                     @"ATTENDEE;CN=Office;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:office@example.com\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];
}

- (void) test_representationsMatchWireFormat
{
  iCalEvent *event;
  WOContext *context;

  event = [self _attendeeEvent];

  context = [self _contextWithProtocolVersion: @"14.1"];
  testEquals ([event activeSyncStartTimeInContext: context], @"20251029T130000Z");
  testEquals ([event activeSyncEndTimeInContext: context], @"20251029T140000Z");

  context = [self _contextWithProtocolVersion: @"16.1"];
  testEquals ([event activeSyncStartTimeInContext: context], @"20251029T130000Z");
  testEquals ([event activeSyncEndTimeInContext: context], @"20251029T140000Z");
}

- (void) test_allDayRepresentationsAreMidnightBased
{
  iCalEvent *event;
  WOContext *context;

  event = [self _allDayAttendeeEvent];

  context = [self _contextWithProtocolVersion: @"14.1"];
  testEquals ([event activeSyncStartTimeInContext: context], @"20251029T000000Z");
  testEquals ([event activeSyncEndTimeInContext: context], @"20251030T000000Z");

  context = [self _contextWithProtocolVersion: @"16.1"];
  testEquals ([event activeSyncStartTimeInContext: context], @"20251029T000000Z");
  testEquals ([event activeSyncEndTimeInContext: context], @"20251030T000000Z");
}

- (void) test_attendeeMovingStartAndEndIsAScheduleChange
{
  WOContext *context;
  NSDictionary *changes;

  context = [self _contextWithProtocolVersion: @"14.1"];
  changes = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"20251029T090000Z", @"StartTime",
                           @"20251029T100000Z", @"EndTime",
                           @"2", @"BusyStatus",
                           nil];

  testWithMessage ([[self _attendeeEvent] hasActiveSyncScheduleChange: changes
                                                            inContext: context],
                   @"an attendee moving both Start and End must be detected");
}

- (void) test_attendeeMovingEndTimeOnlyIsAScheduleChange
{
  WOContext *context;
  NSDictionary *changes;

  context = [self _contextWithProtocolVersion: @"14.1"];
  changes = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"20251029T130000Z", @"StartTime",
                           @"20251029T170000Z", @"EndTime",
                           nil];

  testWithMessage ([[self _attendeeEvent] hasActiveSyncScheduleChange: changes
                                                            inContext: context],
                   @"an attendee moving only End must be detected");
}

- (void) test_attendeeMovingStartTimeOnlyIsAScheduleChange
{
  WOContext *context;
  NSDictionary *changes;

  context = [self _contextWithProtocolVersion: @"16.1"];
  changes = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"20251029T150000Z", @"StartTime",
                           nil];

  testWithMessage ([[self _attendeeEvent] hasActiveSyncScheduleChange: changes
                                                            inContext: context],
                   @"an attendee moving only Start must be detected");
}

- (void) test_echoedTimesAreNotAScheduleChange
{
  WOContext *context;
  NSDictionary *changes;

  context = [self _contextWithProtocolVersion: @"14.1"];
  changes = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"20251029T130000Z", @"StartTime",
                           @"20251029T140000Z", @"EndTime",
                           @"2", @"BusyStatus",
                           @"15", @"Reminder",
                           nil];

  testWithMessage (![[self _attendeeEvent] hasActiveSyncScheduleChange: changes
                                                             inContext: context],
                   @"a client resending the server's times must not be flagged");
}

- (void) test_participationOnlyChangeIsNotAScheduleChange
{
  WOContext *context;
  NSDictionary *changes;

  context = [self _contextWithProtocolVersion: @"14.1"];
  changes = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"1", @"BusyStatus",
                           @"15", @"Reminder",
                           nil];

  testWithMessage (![[self _attendeeEvent] hasActiveSyncScheduleChange: changes
                                                             inContext: context],
                   @"a pure participation-status update must not be flagged");
}

- (void) test_malformedClientTimeIsAScheduleChange
{
  WOContext *context;
  NSDictionary *changes;

  context = [self _contextWithProtocolVersion: @"14.1"];
  changes = [NSDictionary dictionaryWithObject: @"not-a-date"
                                        forKey: @"StartTime"];

  testWithMessage ([[self _attendeeEvent] hasActiveSyncScheduleChange: changes
                                                            inContext: context],
                   @"an unparseable client time must keep the server authoritative");
}

- (void) test_allDayEchoedTimesAreNotAScheduleChange
{
  WOContext *context;
  NSDictionary *changes;

  context = [self _contextWithProtocolVersion: @"14.1"];
  changes = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"20251029T000000Z", @"StartTime",
                           @"20251030T000000Z", @"EndTime",
                           nil];

  testWithMessage (![[self _allDayAttendeeEvent] hasActiveSyncScheduleChange: changes
                                                                   inContext: context],
                   @"an echoed all-day event must not be flagged");
}

- (void) test_allDayMovedTimeIsAScheduleChange
{
  WOContext *context;
  NSDictionary *changes;

  context = [self _contextWithProtocolVersion: @"16.1"];
  changes = [NSDictionary dictionaryWithObject: @"20251030T000000Z"
                                        forKey: @"StartTime"];

  testWithMessage ([[self _allDayAttendeeEvent] hasActiveSyncScheduleChange: changes
                                                                inContext: context],
                   @"a moved all-day event must be detected");
}

@end
