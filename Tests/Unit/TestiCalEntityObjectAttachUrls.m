/* TestiCalEntityObjectAttachUrls.m - this file is part of SOGo
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

#import <Foundation/NSURL.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>

#import "SOGoTest.h"

@interface iCalEntityObject (SOGoTestsDeclaration)
- (NSArray *) attachUrlsForEditor;
- (void) setAttachUrlsFromEditor: (NSArray *) attachUrls;
@end

@interface TestiCalEntityObjectAttachUrls : SOGoTest
@end

@implementation TestiCalEntityObjectAttachUrls

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
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

- (iCalEvent *) _eventWithAttachAndUrl
{
  return [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-6191-both\r\n"
                     @"SUMMARY:test 6191\r\n"
                     @"DTSTART;VALUE=DATE:20260430\r\n"
                     @"DTEND;VALUE=DATE:20260501\r\n"
                     @"ATTACH:https://www.example.com/doc\r\n"
                     @"URL:https://www.example.com\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];
}

- (void) test_attachUrlsForEditorFlagsUrlProperty
{
  iCalEvent *event;
  NSArray *attachUrls;
  NSDictionary *entry;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithAttachAndUrl];
  attachUrls = [event attachUrlsForEditor];

  testWithMessage ([attachUrls count] == 2,
                   @"ATTACH and URL must be exposed as two entries");
  if ([attachUrls count] == 2)
    {
      entry = [attachUrls objectAtIndex: 0];
      testEquals ([entry objectForKey: @"value"], @"https://www.example.com/doc");
      test (![[entry objectForKey: @"isUrl"] boolValue]);

      entry = [attachUrls objectAtIndex: 1];
      testEquals ([entry objectForKey: @"value"], @"https://www.example.com");
      test ([[entry objectForKey: @"isUrl"] boolValue]);
    }
}

- (void) test_attachUrlsForEditorWithoutUrlProperty
{
  iCalEvent *event;
  NSArray *attachUrls;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithContent:
                     @"BEGIN:VCALENDAR\r\n"
                     @"VERSION:2.0\r\n"
                     @"BEGIN:VEVENT\r\n"
                     @"UID:test-6191-attachonly\r\n"
                     @"SUMMARY:test 6191\r\n"
                     @"DTSTART;VALUE=DATE:20260430\r\n"
                     @"DTEND;VALUE=DATE:20260501\r\n"
                     @"ATTACH:https://www.example.com/doc\r\n"
                     @"END:VEVENT\r\n"
                     @"END:VCALENDAR\r\n"];
  attachUrls = [event attachUrlsForEditor];

  testWithMessage ([attachUrls count] == 1,
                   @"an event without URL property must expose a single entry");
  if ([attachUrls count] == 1)
    testEquals ([[attachUrls objectAtIndex: 0] objectForKey: @"value"],
                @"https://www.example.com/doc");
}

- (void) test_editedUrlIsSavedBackToUrlProperty
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithAttachAndUrl];

  [event setAttachUrlsFromEditor:
            [NSArray arrayWithObject:
              [NSDictionary dictionaryWithObjectsAndKeys:
                              @"https://www.example.com/icq", @"value",
                              [NSNumber numberWithBool: YES], @"isUrl",
                              nil]]];

  testEquals ([[event url] absoluteString], @"https://www.example.com/icq");
  testWithMessage ([[event attach] count] == 0,
                   @"an edited URL must not be saved as ATTACH");
}

- (void) test_editedUrlWithAttachKeepsAttach
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithAttachAndUrl];

  [event setAttachUrlsFromEditor:
            [NSArray arrayWithObjects:
              [NSDictionary dictionaryWithObject: @"https://www.example.com/doc"
                                          forKey: @"value"],
              [NSDictionary dictionaryWithObjectsAndKeys:
                              @"https://www.example.com/icq", @"value",
                              [NSNumber numberWithBool: YES], @"isUrl",
                              nil],
              nil]];

  testEquals ([[event url] absoluteString], @"https://www.example.com/icq");
  testWithMessage ([[event attach] count] == 1,
                   @"a resubmitted ATTACH value must be kept");
  if ([[event attach] count] == 1)
    testEquals ([[event attach] objectAtIndex: 0], @"https://www.example.com/doc");
}

- (void) test_submissionWithoutFlagsKeepsUrlProperty
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithAttachAndUrl];

  [event setAttachUrlsFromEditor:
            [NSArray arrayWithObjects:
              [NSDictionary dictionaryWithObject: @"https://www.example.com/doc"
                                          forKey: @"value"],
              [NSDictionary dictionaryWithObject: @"https://www.example.com"
                                          forKey: @"value"],
              [NSDictionary dictionaryWithObject: @"https://www.example.com/other"
                                          forKey: @"value"],
              nil]];

  testEquals ([[event url] absoluteString], @"https://www.example.com");
  testWithMessage ([[event attach] count] == 2,
                   @"a value equal to the URL property must not be duplicated as ATTACH");
  if ([[event attach] count] == 2)
    {
      testEquals ([[event attach] objectAtIndex: 0], @"https://www.example.com/doc");
      testEquals ([[event attach] objectAtIndex: 1], @"https://www.example.com/other");
    }
}

- (void) test_submissionWithoutFlagsDoesNotDeleteUrlProperty
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithAttachAndUrl];

  [event setAttachUrlsFromEditor:
            [NSArray arrayWithObject:
              [NSDictionary dictionaryWithObject: @"https://www.example.com/other"
                                          forKey: @"value"]]];

  testEquals ([[event url] absoluteString], @"https://www.example.com");
  testWithMessage ([[event attach] count] == 1,
                   @"an unflagged submission must replace the ATTACH properties");
  if ([[event attach] count] == 1)
    testEquals ([[event attach] objectAtIndex: 0], @"https://www.example.com/other");
}

- (void) test_invalidEntriesAreIgnored
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithAttachAndUrl];

  [event setAttachUrlsFromEditor:
            [NSArray arrayWithObjects:
              @"https://www.example.com",
              [NSNumber numberWithBool: YES],
              [NSDictionary dictionaryWithObject: @"x" forKey: @"other"],
              [NSDictionary dictionaryWithObject: @"" forKey: @"value"],
              [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithBool: YES], @"isUrl",
                              nil],
              [NSDictionary dictionaryWithObject: @"https://www.example.com/other"
                                          forKey: @"value"],
              nil]];

  testEquals ([[event url] absoluteString], @"https://www.example.com");
  testWithMessage ([[event attach] count] == 1,
                   @"only the valid value must be recorded as ATTACH");
  if ([[event attach] count] == 1)
    testEquals ([[event attach] objectAtIndex: 0], @"https://www.example.com/other");
}

- (void) test_emptyFlaggedUrlIsIgnored
{
  iCalEvent *event;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _eventWithAttachAndUrl];

  [event setAttachUrlsFromEditor:
            [NSArray arrayWithObject:
              [NSDictionary dictionaryWithObjectsAndKeys:
                              @"", @"value",
                              [NSNumber numberWithBool: YES], @"isUrl",
                              nil]]];

  testEquals ([[event url] absoluteString], @"https://www.example.com");
  test ([[event attach] count] == 0);
}

@end
