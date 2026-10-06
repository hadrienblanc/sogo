/* TestSOGoCalendarComponentICalAttachment.m - this file is part of SOGo
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

#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>
#import <NGExtensions/NGBase64Coding.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimePartGenerator.h>

#import <Appointments/SOGoCalendarComponent.h>

#import "SOGoTest.h"

@interface SOGoCalendarComponent (SOGoTestsDeclaration)
- (NGMimeBodyPart *) _bodyPartForICalObject: (iCalRepeatableEntityObject *) object;
@end

@interface TestSOGoCalendarComponentICalAttachment : SOGoTest
@end

@implementation TestSOGoCalendarComponentICalAttachment

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (iCalEvent *) _requestEvent
{
  iCalCalendar *calendar;

  calendar = [iCalCalendar parseSingleFromSource:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"
                         @"METHOD:REQUEST\r\n"
                         @"BEGIN:VEVENT\r\n"
                         @"UID:test-5827\r\n"
                         @"SUMMARY:test 5827\r\n"
                         @"DTSTART:20301105T100000Z\r\n"
                         @"DTEND:20301105T110000Z\r\n"
                         @"ORGANIZER:mailto:organizer@example.org\r\n"
                         @"ATTENDEE:mailto:attendee@example.org\r\n"
                         @"END:VEVENT\r\n"
                         @"END:VCALENDAR\r\n"];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");

  return [[calendar events] objectAtIndex: 0];
}

- (NGMimeBodyPart *) _bodyPartForRequestEvent
{
  SOGoCalendarComponent *component;
  NGMimeBodyPart *bodyPart;

  component = [[SOGoCalendarComponent alloc] init];
  bodyPart = [component _bodyPartForICalObject: [self _requestEvent]];
  [component release];

  return bodyPart;
}

- (void) test_icalBodyPartIsMarkedBase64
{
  NGMimeBodyPart *bodyPart;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  bodyPart = [self _bodyPartForRequestEvent];

  testEquals([[bodyPart headerForKey: @"content-transfer-encoding"] lowercaseString],
             @"base64");
}

- (void) test_generatedMimeCarriesBase64ICalObject
{
  NGMimeBodyPart *bodyPart;
  NSData *mimeData, *payloadData;
  NSString *mimeString, *payloadString, *expectedPayload;
  NSRange separatorRange;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  bodyPart = [self _bodyPartForRequestEvent];
  mimeData = [[NGMimePartGenerator mimePartGenerator]
                 generateMimeFromPart: bodyPart];
  mimeString = [[[NSString alloc] initWithData: mimeData
                                      encoding: NSUTF8StringEncoding] autorelease];

  test([[mimeString lowercaseString]
          rangeOfString: @"content-transfer-encoding: base64"].location
         != NSNotFound);
  test([[mimeString lowercaseString] rangeOfString: @"quoted-printable"].location
         == NSNotFound);

  separatorRange = [mimeString rangeOfString: @"\r\n\r\n"];
  testWithMessage (separatorRange.location != NSNotFound,
                   @"generated MIME part holds a body");
  if (separatorRange.location == NSNotFound)
    return;

  payloadString = [mimeString substringFromIndex: separatorRange.location + 4];
  payloadData = [[payloadString dataUsingEncoding: NSUTF8StringEncoding]
                  dataByDecodingBase64];
  payloadString = [[[NSString alloc] initWithData: payloadData
                                         encoding: NSUTF8StringEncoding] autorelease];
  expectedPayload
    = [NSString stringWithFormat: @"%@\r\n",
                      [[[self _requestEvent] parent] versitString]];

  testEquals(payloadString, expectedPayload);
}

@end
