/* TestSOGoAppointmentFolderCalDAVQuery.m - this file is part of SOGo
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

#import <DOM/DOMElement.h>
#import <DOM/DOMSaxBuilder.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <Appointments/SOGoAppointmentFolder.h>

#import "SOGoTest.h"

@class WOContext;

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

@interface TestQueryUser : NSObject
@end

@implementation TestQueryUser

- (NSString *) login
{
  return @"sogo1";
}

@end

@interface TestQueryContext : NSObject
{
  TestQueryUser *user;
}
- (id) initWithUser: (TestQueryUser *) newUser;
@end

@implementation TestQueryContext

- (id) initWithUser: (TestQueryUser *) newUser
{
  if ((self = [super init]))
    user = [newUser retain];

  return self;
}

- (void) dealloc
{
  [user release];
  [super dealloc];
}

- (TestQueryUser *) activeUser
{
  return user;
}

- (id) request
{
  return nil;
}

@end

@interface SOGoAppointmentFolder (CalDAVQueryTests)
- (NSArray *) _parseCalendarFilters: (id <DOMElement>) parentNode;
- (NSString *) _composeAdditionalFilters: (NSDictionary *) filter;
@end

@interface TestSOGoAppointmentFolderCalDAVQuery : SOGoTest
{
  SOGoAppointmentFolder *folder;
}
@end

@implementation TestSOGoAppointmentFolderCalDAVQuery

- (void) setUp
{
  TestQueryContext *context;

  testWithMessage (LoadAppointmentsBundle (),
                   @"Appointments bundle could not be loaded");

  folder = [[SOGoAppointmentFolder alloc] init];
  context = [[[TestQueryContext alloc]
               initWithUser: [[[TestQueryUser alloc] init] autorelease]]
              autorelease];
  [folder setContext: (WOContext *) context];
}

- (void) tearDown
{
  [folder release];
}

- (NSArray *) _filtersFromXML: (NSString *) theXML
{
  DOMSaxBuilder *builder;
  id dom;

  builder = [[[DOMSaxBuilder alloc] init] autorelease];
  dom = [builder buildFromData: [theXML dataUsingEncoding: NSUTF8StringEncoding]];

  return [folder _parseCalendarFilters: [dom documentElement]];
}

- (void) test_bareVcalendarCompFilterMatchesAllObjects
{
  NSArray *filters;
  NSDictionary *baseFilter, *cyclicFilter;

  filters = [self _filtersFromXML:
                      @"<C:calendar-query xmlns:D=\"DAV:\""
                      @" xmlns:C=\"urn:ietf:params:xml:ns:caldav\">"
                      @"<C:filter><C:comp-filter name=\"VCALENDAR\"/></C:filter>"
                      @"</C:calendar-query>"];

  testEquals([NSNumber numberWithUnsignedInt: [filters count]],
             [NSNumber numberWithUnsignedInt: 2]);

  baseFilter = [filters objectAtIndex: 0];
  test([baseFilter objectForKey: @"name"] == nil);
  test([baseFilter objectForKey: @"start"] == nil);
  test([baseFilter objectForKey: @"end"] == nil);
  testEquals([baseFilter objectForKey: @"iscycle"], [NSNumber numberWithBool: NO]);

  cyclicFilter = [filters objectAtIndex: 1];
  testEquals([cyclicFilter objectForKey: @"iscycle"],
             [NSNumber numberWithBool: YES]);
}

- (void) test_nestedEventCompFilterIsUnchanged
{
  NSArray *filters;
  NSDictionary *baseFilter, *cyclicFilter;

  filters = [self _filtersFromXML:
                      @"<C:calendar-query xmlns:D=\"DAV:\""
                      @" xmlns:C=\"urn:ietf:params:xml:ns:caldav\">"
                      @"<C:filter><C:comp-filter name=\"VCALENDAR\">"
                      @"<C:comp-filter name=\"VEVENT\">"
                      @"<C:time-range start=\"20260701T000000Z\""
                      @" end=\"20260801T000000Z\"/>"
                      @"</C:comp-filter></C:comp-filter></C:filter>"
                      @"</C:calendar-query>"];

  testEquals([NSNumber numberWithUnsignedInt: [filters count]],
             [NSNumber numberWithUnsignedInt: 2]);

  baseFilter = [filters objectAtIndex: 0];
  testEquals([baseFilter objectForKey: @"name"], @"vevent");
  test([baseFilter objectForKey: @"start"] != nil);
  test([baseFilter objectForKey: @"end"] != nil);
  testEquals([baseFilter objectForKey: @"iscycle"], [NSNumber numberWithBool: NO]);

  cyclicFilter = [filters objectAtIndex: 1];
  testEquals([cyclicFilter objectForKey: @"name"], @"vevent");
  testEquals([cyclicFilter objectForKey: @"iscycle"],
             [NSNumber numberWithBool: YES]);
}

- (void) test_classPropFilterComposesClassificationSQL
{
  NSArray *filters;
  NSDictionary *baseFilter;

  filters = [self _filtersFromXML:
                      @"<C:calendar-query xmlns:D=\"DAV:\""
                      @" xmlns:C=\"urn:ietf:params:xml:ns:caldav\">"
                      @"<C:filter><C:comp-filter name=\"VCALENDAR\">"
                      @"<C:comp-filter name=\"VEVENT\">"
                      @"<C:prop-filter name=\"CLASS\">"
                      @"<C:text-match collation=\"i;octet\">CONFIDENTIAL"
                      @"</C:text-match>"
                      @"</C:prop-filter>"
                      @"</C:comp-filter></C:comp-filter></C:filter>"
                      @"</C:calendar-query>"];

  baseFilter = [filters objectAtIndex: 0];
  testEquals([baseFilter objectForKey: @"class"], @"CONFIDENTIAL");
  testEquals([folder _composeAdditionalFilters: baseFilter],
             @"(c_classification = 2) AND (c_iscycle = '0')");
}

- (void) test_classificationValuesMapToSQL
{
  testEquals([folder _composeAdditionalFilters:
                       [NSDictionary dictionaryWithObject: @"PUBLIC"
                                                  forKey: @"class"]],
             @"(c_classification = 0)");
  testEquals([folder _composeAdditionalFilters:
                       [NSDictionary dictionaryWithObject: @"PRIVATE"
                                                  forKey: @"class"]],
             @"(c_classification = 1)");
  testEquals([folder _composeAdditionalFilters:
                       [NSDictionary dictionaryWithObject: @"confidential"
                                                  forKey: @"class"]],
             @"(c_classification = 2)");
  testEquals([folder _composeAdditionalFilters:
                       [NSDictionary dictionaryWithObject: @"TOPSECRET"
                                                  forKey: @"class"]],
             @"(c_classification = -1)");
  testEquals([folder _composeAdditionalFilters:
                       [NSDictionary dictionaryWithObject: @"NULL"
                                                  forKey: @"class"]],
             @"(c_classification = -1)");
  test([folder _composeAdditionalFilters:
          [NSDictionary dictionaryWithObject: @"" forKey: @"class"]] == nil);
}

- (void) test_classFilterCombinesWithCyclicFilter
{
  NSDictionary *cyclicFilter;

  cyclicFilter = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"CONFIDENTIAL", @"class",
                              [NSNumber numberWithBool: YES], @"iscycle",
                              nil];

  testEquals([folder _composeAdditionalFilters: cyclicFilter],
             @"(c_classification = 2) AND (c_iscycle = '1')");
}

@end
