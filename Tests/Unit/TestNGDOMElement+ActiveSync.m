/* TestNGDOMElement+ActiveSync.m - this file is part of SOGo
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

#import <DOM/DOMDocument.h>
#import <DOM/DOMElement.h>
#import <DOM/DOMSaxBuilder.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import "NGDOMElement+ActiveSync.h"
#import "SOGoTest.h"

@interface TestNGDOMElement_plus_ActiveSync : SOGoTest
@end

@implementation TestNGDOMElement_plus_ActiveSync

- (NSDictionary *) _applicationDataFromXML: (NSString *) theXML
{
  DOMSaxBuilder *builder;
  id dom;

  builder = [[[DOMSaxBuilder alloc] init] autorelease];
  dom = [builder buildFromData: [theXML dataUsingEncoding: NSUTF8StringEncoding]];

  return [(NGDOMElement *) [dom documentElement] applicationData];
}

- (NSString *) _outlook2021ApplicationDataXML
{
  return
    @"<ApplicationData xmlns=\"AirSync:\">\n"
    @" <Subject xmlns=\"Calendar:\">Test meeting</Subject>\n"
    @" <StartTime xmlns=\"Calendar:\">2024-03-06T10:00:00.000Z</StartTime>\n"
    @" <EndTime xmlns=\"Calendar:\">2024-03-06T11:00:00.000Z</EndTime>\n"
    @" <Attendees xmlns=\"Calendar:\">\n"
    @"  <Attendee>\n"
    @"   <Attendee_Email>a@example.com</Attendee_Email>\n"
    @"   <Attendee_Name>Alice</Attendee_Name>\n"
    @"   <Attendee_Status>3</Attendee_Status>\n"
    @"   <Attendee_Type>1</Attendee_Type>\n"
    @"  </Attendee>\n"
    @"  <Attendee>\n"
    @"   <Attendee_Email>b@example.com</Attendee_Email>\n"
    @"   <Attendee_Name>Bob</Attendee_Name>\n"
    @"   <Attendee_Status>5</Attendee_Status>\n"
    @"   <Attendee_Type>1</Attendee_Type>\n"
    @"  </Attendee>\n"
    @" </Attendees>\n"
    @" <Location xmlns=\"AirSyncBase:\">\n"
    @"  <DisplayName>Konferenzraum 4</DisplayName>\n"
    @" </Location>\n"
    @" <ClientUid xmlns=\"Calendar:\">040000008200E00074C5B7101A82E00800000000F07EF645B062DB01</ClientUid>\n"
    @"</ApplicationData>";
}

- (void) test_applicationDataExtractsClientUidAsString
{
  NSDictionary *data;

  data = [self _applicationDataFromXML: [self _outlook2021ApplicationDataXML]];

  testEquals([data objectForKey: @"ClientUid"],
             @"040000008200E00074C5B7101A82E00800000000F07EF645B062DB01");
}

- (void) test_applicationDataExtractsStructuredLocationAsDictionary
{
  NSDictionary *data;

  data = [self _applicationDataFromXML: [self _outlook2021ApplicationDataXML]];

  test([[data objectForKey: @"Location"] isKindOfClass: [NSDictionary class]]);
  testEquals([[data objectForKey: @"Location"] objectForKey: @"DisplayName"],
             @"Konferenzraum 4");
}

- (void) test_applicationDataExtractsPlainTextLocationAsString
{
  NSDictionary *data;

  data = [self _applicationDataFromXML:
           @"<ApplicationData xmlns=\"AirSync:\">\n"
           @" <Location xmlns=\"Calendar:\">Konferenzraum 4</Location>\n"
           @"</ApplicationData>"];

  test([[data objectForKey: @"Location"] isKindOfClass: [NSString class]]);
  testEquals([data objectForKey: @"Location"], @"Konferenzraum 4");
}

- (void) test_applicationDataExtractsAllAttendeesAsArray
{
  NSDictionary *data;
  NSArray *attendees;

  data = [self _applicationDataFromXML: [self _outlook2021ApplicationDataXML]];
  attendees = [data objectForKey: @"Attendees"];

  test([attendees isKindOfClass: [NSArray class]]);
  test([attendees count] == 2);
  testEquals([[attendees objectAtIndex: 0] objectForKey: @"Attendee_Email"], @"a@example.com");
  testEquals([[attendees objectAtIndex: 0] objectForKey: @"Attendee_Name"], @"Alice");
  testEquals([[attendees objectAtIndex: 0] objectForKey: @"Attendee_Status"], @"3");
  testEquals([[attendees objectAtIndex: 1] objectForKey: @"Attendee_Email"], @"b@example.com");
  testEquals([[attendees objectAtIndex: 1] objectForKey: @"Attendee_Name"], @"Bob");
}

- (void) test_applicationDataExtractsSingleAttendeeAsArray
{
  NSDictionary *data;
  NSArray *attendees;

  data = [self _applicationDataFromXML:
           @"<ApplicationData xmlns=\"AirSync:\">\n"
           @" <Attendees xmlns=\"Calendar:\">\n"
           @"  <Attendee>\n"
           @"   <Attendee_Email>a@example.com</Attendee_Email>\n"
           @"   <Attendee_Name>Alice</Attendee_Name>\n"
           @"   <Attendee_Status>3</Attendee_Status>\n"
           @"   <Attendee_Type>1</Attendee_Type>\n"
           @"  </Attendee>\n"
           @" </Attendees>\n"
           @"</ApplicationData>"];
  attendees = [data objectForKey: @"Attendees"];

  test([attendees isKindOfClass: [NSArray class]]);
  test([attendees count] == 1);
  testEquals([[attendees objectAtIndex: 0] objectForKey: @"Attendee_Email"], @"a@example.com");
}

- (void) test_applicationDataExtractsCategoriesAsStringArray
{
  NSDictionary *data;
  NSArray *categories;

  data = [self _applicationDataFromXML:
           @"<ApplicationData xmlns=\"AirSync:\">\n"
           @" <Categories xmlns=\"Calendar:\">\n"
           @"  <Category>Projekt</Category>\n"
           @"  <Category>Review</Category>\n"
           @" </Categories>\n"
           @"</ApplicationData>"];
  categories = [data objectForKey: @"Categories"];

  test([categories isKindOfClass: [NSArray class]]);
  test([categories count] == 2);
  testEquals([categories objectAtIndex: 0], @"Projekt");
  testEquals([categories objectAtIndex: 1], @"Review");
}

- (void) test_applicationDataExtractsNestedBodyAsDictionary
{
  NSDictionary *data;

  data = [self _applicationDataFromXML:
           @"<ApplicationData xmlns=\"AirSync:\">\n"
           @" <Body xmlns=\"AirSyncBase:\">\n"
           @"  <Type>1</Type>\n"
           @"  <EstimatedDataSize>23</EstimatedDataSize>\n"
           @"  <Data>Beschreibung des Termins</Data>\n"
           @" </Body>\n"
           @"</ApplicationData>"];

  testEquals([[data objectForKey: @"Body"] objectForKey: @"Type"], @"1");
  testEquals([[data objectForKey: @"Body"] objectForKey: @"Data"], @"Beschreibung des Termins");
}

- (void) test_applicationDataExtractsReminderAndSubjectFromOutlook2021Payload
{
  NSDictionary *data;

  data = [self _applicationDataFromXML:
           [self _outlook2021ApplicationDataXML]];

  testEquals([data objectForKey: @"Subject"], @"Test meeting");
  testEquals([data objectForKey: @"StartTime"], @"2024-03-06T10:00:00.000Z");
  testEquals([data objectForKey: @"EndTime"], @"2024-03-06T11:00:00.000Z");
}

@end
