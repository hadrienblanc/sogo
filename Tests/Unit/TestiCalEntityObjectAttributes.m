/* TestiCalEntityObjectAttributes.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>

#import "SOGoTest.h"

@class WOContext;

@interface iCalEntityObject (SOGoTestsDeclaration)
- (NSDictionary *) attributesInContext: (WOContext *) context;
@end

@interface TestiCalEntityObjectAttributes : SOGoTest
@end

@implementation TestiCalEntityObjectAttributes

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (void) setUp
{
  /* The attendee and organizer lookups reach SOGoUserManager and its cache;
     without a server list libmemcached aborts on a NULL host. */
  [[NSUserDefaults standardUserDefaults]
    registerDefaults: [NSDictionary dictionaryWithObject: @"127.0.0.1:11211"
                                                  forKey: @"SOGoMemcachedHost"]];
}

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

- (iCalEvent *) _invitedEvent
{
  return [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-6183-invited\r\n"
                     @"SUMMARY:test 6183\r\n"
                     @"DTSTART:20261015T100000Z\r\n"
                     @"DTEND:20261015T110000Z\r\n"
                     @"ORGANIZER;CN=Sogo Tests One:mailto:sogo-tests1@sogo.local\r\n"
                     @"ATTENDEE;CN=Sogo Tests Two;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION:mailto:sogo-tests2@sogo.local\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];
}

- (void) test_organizerIsExposedSeparatelyFromAttendees
{
  NSDictionary *data, *organizer;
  NSArray *attendees;
  NSUInteger i;
  BOOL organizerAmongAttendees;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  data = [[self _invitedEvent] attributesInContext: nil];

  organizer = [data objectForKey: @"organizer"];
  testWithMessage (organizer != nil,
                   @"the organizer must be exposed for the attendees mail composition");
  if (organizer)
    {
      testEquals ([organizer objectForKey: @"email"], @"sogo-tests1@sogo.local");
      testEquals ([organizer objectForKey: @"name"], @"Sogo Tests One");
    }

  attendees = [data objectForKey: @"attendees"];
  testWithMessage ([attendees count] == 1,
                   @"an invited event with a single attendee must expose one attendee");
  if ([attendees count] == 1)
    {
      testEquals ([[attendees objectAtIndex: 0] objectForKey: @"email"],
                  @"sogo-tests2@sogo.local");
      testEquals ([[attendees objectAtIndex: 0] objectForKey: @"partstat"],
                  @"needs-action");
    }

  organizerAmongAttendees = NO;
  for (i = 0; i < [attendees count]; i++)
    {
      if ([[[attendees objectAtIndex: i] objectForKey: @"email"]
             isEqualToString: [organizer objectForKey: @"email"]])
        organizerAmongAttendees = YES;
    }
  testWithMessage (!organizerAmongAttendees,
                   @"the organizer is serialized outside of the attendees and must be merged client-side");
}

- (void) test_organizerNameFallsBackToEmail
{
  iCalEvent *event;
  NSDictionary *data, *organizer;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                      @"BEGIN:VCALENDAR\r\n"
                      @"VERSION:2.0\r\n"
                      @"BEGIN:VEVENT\r\n"
                      @"UID:test-6183-nocn\r\n"
                      @"SUMMARY:test 6183\r\n"
                      @"DTSTART:20261015T100000Z\r\n"
                      @"DTEND:20261015T110000Z\r\n"
                      @"ORGANIZER:mailto:sogo-tests3@sogo.local\r\n"
                      @"ATTENDEE;PARTSTAT=NEEDS-ACTION:mailto:sogo-tests2@sogo.local\r\n"
                      @"END:VEVENT\r\n"
                      @"END:VCALENDAR\r\n"];
  data = [event attributesInContext: nil];

  organizer = [data objectForKey: @"organizer"];
  testWithMessage (organizer != nil,
                   @"an organizer without CN must still be exposed");
  if (organizer)
    {
      testEquals ([organizer objectForKey: @"email"], @"sogo-tests3@sogo.local");
      testEquals ([organizer objectForKey: @"name"], @"sogo-tests3@sogo.local");
    }
}

- (void) test_eventWithoutOrganizerOmitsKey
{
  iCalEvent *event;
  NSDictionary *data;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                      @"BEGIN:VCALENDAR\r\n"
                      @"VERSION:2.0\r\n"
                      @"BEGIN:VEVENT\r\n"
                      @"UID:test-6183-noorg\r\n"
                      @"SUMMARY:test 6183\r\n"
                      @"DTSTART:20261015T100000Z\r\n"
                      @"DTEND:20261015T110000Z\r\n"
                      @"ATTENDEE;PARTSTAT=ACCEPTED:mailto:sogo-tests2@sogo.local\r\n"
                      @"END:VEVENT\r\n"
                      @"END:VCALENDAR\r\n"];
  data = [event attributesInContext: nil];

  test ([data objectForKey: @"organizer"] == nil);
  testWithMessage ([[data objectForKey: @"attendees"] count] == 1,
                   @"attendees must still be exposed without an organizer");
}

@end
