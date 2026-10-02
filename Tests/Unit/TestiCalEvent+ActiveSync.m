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
#import <NGCards/NSString+NGCards.h>

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

- (void) test_missingAttendeeRoleDefaultsToRequiredOnTheWire
{
  iCalEvent *event;
  WOContext *context;
  NSString *s;

  event = [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-6132-norole\r\n"
                     @"SUMMARY:Termin\r\n"
                     @"DTSTART:20251029T130000Z\r\n"
                     @"DTEND:20251029T140000Z\r\n"
                     @"ORGANIZER;CN=Beate Luther:mailto:beate@example.com\r\n"
                     @"ATTENDEE;CN=Office;RSVP=TRUE:mailto:office@example.com\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];

  context = [self _contextWithProtocolVersion: @"14.1"];
  s = [event activeSyncRepresentationInContext: context];

  testWithMessage ([s rangeOfString:
                      @"<Attendee_Type xmlns=\"Calendar:\">1</Attendee_Type>"].length > 0,
                   @"an absent ROLE defaults to REQ-PARTICIPANT (RFC 5545) "
                   @"and must map to a required attendee");
  testWithMessage ([s rangeOfString:
                      @"<Attendee_Status xmlns=\"Calendar:\">5</Attendee_Status>"].length > 0,
                   @"an absent PARTSTAT defaults to NEEDS-ACTION (RFC 5545) "
                   @"and must map to attendee status 5");
}

- (void) test_explicitOptionalAttendeeRoleStaysOptionalOnTheWire
{
  iCalEvent *event;
  WOContext *context;
  NSString *s;

  event = [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-6132-optrole\r\n"
                     @"SUMMARY:Termin\r\n"
                     @"DTSTART:20251029T130000Z\r\n"
                     @"DTEND:20251029T140000Z\r\n"
                     @"ORGANIZER;CN=Beate Luther:mailto:beate@example.com\r\n"
                     @"ATTENDEE;CN=Office;ROLE=OPT-PARTICIPANT;RSVP=TRUE:mailto:office@example.com\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];

  context = [self _contextWithProtocolVersion: @"14.1"];
  s = [event activeSyncRepresentationInContext: context];

  testWithMessage ([s rangeOfString:
                      @"<Attendee_Type xmlns=\"Calendar:\">2</Attendee_Type>"].length > 0,
                   @"an explicit OPT-PARTICIPANT role must still map to an "
                   @"optional attendee");
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

- (iCalEvent *) _structuredLocationEvent
{
  return [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-6236-structured\r\n"
                     @"SUMMARY:Dinner in Oslo\r\n"
                     @"DTSTART:20260811T190000Z\r\n"
                     @"DTEND:20260811T210000Z\r\n"
                     @"LOCATION:Oslo S\r\n"
                     @"GEO:59.911081;10.749770\r\n"
                     @"X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-ADDRESS=\"Jernbanetorget 1\\nOslo\\n\\n0154\\nNorway\";X-TITLE=\"Oslo S\":geo:59.911081,10.749770\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];
}

- (iCalEvent *) _minimalEvent
{
  return [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-6236-minimal\r\n"
                     @"SUMMARY:Termin\r\n"
                     @"DTSTART:20260811T190000Z\r\n"
                     @"DTEND:20260811T210000Z\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];
}

- (void) test_structuredLocationIsExposedOnTheWire
{
  iCalEvent *event;
  WOContext *context;
  NSString *s;

  event = [self _structuredLocationEvent];
  context = [self _contextWithProtocolVersion: @"16.1"];
  s = [event activeSyncRepresentationInContext: context];

  testWithMessage ([s rangeOfString: @"<Location xmlns=\"AirSyncBase:\">"].length > 0,
                   @"EAS 16.x must carry an AirSyncBase Location element");
  testWithMessage ([s rangeOfString: @"<DisplayName>Oslo S</DisplayName>"].length > 0,
                   @"LOCATION must map to DisplayName");
  testWithMessage ([s rangeOfString: @"<Street>Jernbanetorget 1</Street>"].length > 0,
                   @"X-ADDRESS street line must map to Street");
  testWithMessage ([s rangeOfString: @"<City>Oslo</City>"].length > 0,
                   @"X-ADDRESS city line must map to City");
  testWithMessage ([s rangeOfString: @"<PostalCode>0154</PostalCode>"].length > 0,
                   @"X-ADDRESS postal code line must map to PostalCode");
  testWithMessage ([s rangeOfString: @"<Country>Norway</Country>"].length > 0,
                   @"X-ADDRESS country line must map to Country");
  testWithMessage ([s rangeOfString: @"<State>"].length == 0,
                   @"an empty address component must be omitted");
  testWithMessage ([s rangeOfString: @"<Latitude>59.911081</Latitude>"].length > 0,
                   @"GEO latitude must map to Latitude");
  testWithMessage ([s rangeOfString: @"<Longitude>10.749770</Longitude>"].length > 0,
                   @"GEO longitude must map to Longitude");
  testWithMessage ([s rangeOfString: @"<LocationUri>geo:59.911081,10.749770</LocationUri>"].length > 0,
                   @"the structured-location URI must map to LocationUri");
}

- (void) test_locationStaysFlatBeforeProtocol16
{
  iCalEvent *event;
  WOContext *context;
  NSString *s;

  event = [self _structuredLocationEvent];
  context = [self _contextWithProtocolVersion: @"14.1"];
  s = [event activeSyncRepresentationInContext: context];

  testWithMessage ([s rangeOfString: @"<Location xmlns=\"Calendar:\">Oslo S</Location>"].length > 0,
                   @"EAS 14.1 must keep the flat text location");
  testWithMessage ([s rangeOfString: @"<Location xmlns=\"AirSyncBase:\">"].length == 0,
                   @"no structured location must be emitted before EAS 16.0");
}

- (void) test_structuredLocationRoundTrip
{
  WOContext *context;
  NSDictionary *location;
  CardElement *structured;
  iCalEvent *event;
  NSString *s;

  context = [self _contextWithProtocolVersion: @"16.1"];

  location = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Oslo S", @"DisplayName",
                           @"Jernbanetorget 1", @"Street",
                           @"Oslo", @"City",
                           @"Norway", @"Country",
                           @"0154", @"PostalCode",
                           @"59.911081", @"Latitude",
                           @"10.749770", @"Longitude",
                           nil];

  event = [self _minimalEvent];
  [event takeActiveSyncValues: [NSDictionary dictionaryWithObject: location
                                                           forKey: @"Location"]
                    inContext: context];

  testEquals ([event location], @"Oslo S");
  testEquals ([[event firstChildWithTag: @"geo"] flattenedValuesForKey: @""],
              @"59.911081;10.749770");

  structured = [event firstChildWithTag: @"x-apple-structured-location"];
  testWithMessage (structured != nil,
                   @"a structured location received from EAS must be preserved");
  testEquals ([structured flattenedValuesForKey: @""], @"geo:59.911081,10.749770");
  testEquals ([structured value: 0 ofAttribute: @"X-ADDRESS"],
              @"\"Jernbanetorget 1\nOslo\n\n0154\nNorway\"");
  testEquals ([structured value: 0 ofAttribute: @"X-TITLE"], @"\"Oslo S\"");
  s = [[structured versitString] stringByReplacingString: @"\r\n " withString: @""];
  testWithMessage (([s hasPrefix: @"X-APPLE-STRUCTURED-LOCATION;"]
                    && [s rangeOfString: @"VALUE=URI"].length
                    && [s rangeOfString: @"X-ADDRESS=\"Jernbanetorget 1\\nOslo\\n\\n0154\\nNorway\""].length
                    && [s rangeOfString: @"X-TITLE=\"Oslo S\""].length
                    && [s hasSuffix: @":geo:59.911081,10.749770"]),
                   @"the stored location must render as an Apple-compatible "
                   @"structured-location property");

  s = [event activeSyncRepresentationInContext: context];
  testWithMessage (([s rangeOfString: @"<DisplayName>Oslo S</DisplayName>"].length
                    && [s rangeOfString: @"<Street>Jernbanetorget 1</Street>"].length
                    && [s rangeOfString: @"<City>Oslo</City>"].length
                    && [s rangeOfString: @"<Country>Norway</Country>"].length
                    && [s rangeOfString: @"<PostalCode>0154</PostalCode>"].length
                    && [s rangeOfString: @"<Latitude>59.911081</Latitude>"].length
                    && [s rangeOfString: @"<Longitude>10.749770</Longitude>"].length
                    && [s rangeOfString: @"<LocationUri>geo:59.911081,10.749770</LocationUri>"].length),
                   @"the structured location must survive an EAS round trip");
}

- (void) test_displayNameOnlyLocationRoundTrip
{
  WOContext *context;
  NSDictionary *location;
  iCalEvent *event;

  context = [self _contextWithProtocolVersion: @"16.1"];
  location = [NSDictionary dictionaryWithObject: @"Somewhere"
                                        forKey: @"DisplayName"];

  event = [self _minimalEvent];
  [event takeActiveSyncValues: [NSDictionary dictionaryWithObject: location
                                                           forKey: @"Location"]
                    inContext: context];

  testEquals ([event location], @"Somewhere");
  testWithMessage ([event firstChildWithTag: @"geo"] == nil,
                   @"no GEO must be invented without coordinates");
  testWithMessage ([event firstChildWithTag: @"x-apple-structured-location"] == nil,
                   @"no structured-location property must be invented");
}

- (void) test_plainLocationUpdateDropsStaleStructuredData
{
  WOContext *context;
  NSDictionary *location;
  iCalEvent *event;

  context = [self _contextWithProtocolVersion: @"16.1"];

  event = [self _structuredLocationEvent];
  location = [NSDictionary dictionaryWithObject: @"Somewhere"
                                        forKey: @"DisplayName"];
  [event takeActiveSyncValues: [NSDictionary dictionaryWithObject: location
                                                           forKey: @"Location"]
                    inContext: context];

  testEquals ([event location], @"Somewhere");
  testWithMessage ([event firstChildWithTag: @"geo"] == nil,
                   @"a plain-text location update must drop a stale GEO");
  testWithMessage ([event firstChildWithTag: @"x-apple-structured-location"] == nil,
                   @"a plain-text location update must drop a stale structured location");
}

- (void) test_locationUriWithoutCoordinatesRoundTrip
{
  WOContext *context;
  NSDictionary *location;
  CardElement *structured;
  iCalEvent *event;
  NSString *s;

  context = [self _contextWithProtocolVersion: @"16.1"];

  location = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"HQ", @"DisplayName",
                           @"1 Main Street", @"Street",
                           @"Oslo", @"City",
                           @"https://maps.example.com/hq", @"LocationUri",
                           nil];

  event = [self _minimalEvent];
  [event takeActiveSyncValues: [NSDictionary dictionaryWithObject: location
                                                           forKey: @"Location"]
                    inContext: context];

  structured = [event firstChildWithTag: @"x-apple-structured-location"];
  testWithMessage (structured != nil,
                   @"missing coordinates must not prevent the structured location");
  testEquals ([structured flattenedValuesForKey: @""], @"https://maps.example.com/hq");

  s = [event activeSyncRepresentationInContext: context];
  testWithMessage (([s rangeOfString: @"<LocationUri>https://maps.example.com/hq</LocationUri>"].length
                    && [s rangeOfString: @"<Street>1 Main Street</Street>"].length
                    && [s rangeOfString: @"<Latitude>"].length == 0),
                   @"address and URI must survive without coordinates");
}

- (void) test_geoOnlyEventExposesCoordinatesWithoutDisplayName
{
  iCalEvent *event;
  WOContext *context;
  NSString *s;

  event = [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-6236-geoonly\r\n"
                     @"SUMMARY:Termin\r\n"
                     @"DTSTART:20260811T190000Z\r\n"
                     @"DTEND:20260811T210000Z\r\n"
                     @"GEO:59.911081;10.749770\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];

  context = [self _contextWithProtocolVersion: @"16.1"];
  s = [event activeSyncRepresentationInContext: context];

  testWithMessage ([s rangeOfString: @"<Location xmlns=\"AirSyncBase:\">"].length > 0,
                   @"a GEO-only event must still expose a Location");
  testWithMessage ([s rangeOfString: @"<Latitude>59.911081</Latitude>"].length > 0,
                   @"a GEO-only event must expose its latitude");
  testWithMessage ([s rangeOfString: @"<DisplayName>"].length == 0,
                   @"no DisplayName must be invented");
}

- (void) test_appleThreeLineAddressMapsToStreetCityCountry
{
  iCalEvent *event;
  WOContext *context;
  NSString *s;

  event = [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-6236-apple3\r\n"
                     @"SUMMARY:Termin\r\n"
                     @"DTSTART:20260811T190000Z\r\n"
                     @"DTEND:20260811T210000Z\r\n"
                     @"X-APPLE-STRUCTURED-LOCATION;VALUE=URI;X-ADDRESS=\"Jernbanetorget 1\\n0154 Oslo\\nNorway\";X-TITLE=\"Oslo S\":geo:59.911081,10.749770\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];

  context = [self _contextWithProtocolVersion: @"16.1"];
  s = [event activeSyncRepresentationInContext: context];

  testWithMessage ([s rangeOfString: @"<DisplayName>Oslo S</DisplayName>"].length > 0,
                   @"X-TITLE must provide DisplayName when LOCATION is absent");
  testWithMessage (([s rangeOfString: @"<Street>Jernbanetorget 1</Street>"].length
                    && [s rangeOfString: @"<City>0154 Oslo</City>"].length
                    && [s rangeOfString: @"<Country>Norway</Country>"].length),
                   @"Apple's three-line address must map to Street, City, Country");
  testWithMessage (([s rangeOfString: @"<State>"].length == 0
                    && [s rangeOfString: @"<PostalCode>"].length == 0),
                   @"no invented components for a three-line address");
}

- (void) test_invalidGeoValueIsIgnored
{
  iCalEvent *event;
  WOContext *context;
  NSString *s;

  event = [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-6236-badgeo\r\n"
                     @"SUMMARY:Termin\r\n"
                     @"DTSTART:20260811T190000Z\r\n"
                     @"DTEND:20260811T210000Z\r\n"
                     @"LOCATION:Oslo S\r\n"
                     @"GEO:nonsense\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];

  context = [self _contextWithProtocolVersion: @"16.1"];
  s = [event activeSyncRepresentationInContext: context];

  testWithMessage (([s rangeOfString: @"<Latitude>"].length == 0
                    && [s rangeOfString: @"<Longitude>"].length == 0),
                   @"an unparseable GEO must not produce coordinates");
  testWithMessage ([s rangeOfString: @"<DisplayName>Oslo S</DisplayName>"].length > 0,
                   @"an unparseable GEO must not prevent the location");
}

- (void) test_flatLocationAcceptedBeforeProtocol16
{
  WOContext *context;
  iCalEvent *event;

  context = [self _contextWithProtocolVersion: @"14.1"];

  event = [self _minimalEvent];
  [event takeActiveSyncValues: [NSDictionary dictionaryWithObject: @"Oslo S"
                                                           forKey: @"Location"]
                    inContext: context];

  testEquals ([event location], @"Oslo S");
  testWithMessage ([event firstChildWithTag: @"x-apple-structured-location"] == nil,
                   @"no structured location must be stored before EAS 16.0");
}

@end
