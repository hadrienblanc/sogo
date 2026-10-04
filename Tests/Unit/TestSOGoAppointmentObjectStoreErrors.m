/* TestSOGoAppointmentObjectStoreErrors.m - this file is part of SOGo
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

#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>

#import <Appointments/SOGoAppointmentObject.h>

#import "SOGoTest.h"

@interface SOGoAppointmentObject (StoreErrorsTestsDeclaration)
- (NSException *) _handleAddedUsers: (NSArray *) attendees
                          fromEvent: (iCalEvent *) newEvent
                              force: (BOOL) forceSave;
@end

@interface TestSOGoAppointmentObjectStoreErrorsStub : SOGoAppointmentObject
{
  NSException *storeError;
}

- (void) setStoreError: (NSException *) newStoreError;

@end

@implementation TestSOGoAppointmentObjectStoreErrorsStub

- (void) dealloc
{
  [storeError release];
  [super dealloc];
}

- (void) setStoreError: (NSException *) newStoreError
{
  ASSIGN (storeError, newStoreError);
}

- (NSException *) saveComponent: (id) theComponent
                    baseVersion: (unsigned int) newVersion
{
  return storeError;
}

- (NSException *) _handleAddedUsers: (NSArray *) attendees
                          fromEvent: (iCalEvent *) newEvent
                              force: (BOOL) forceSave
{
  return nil;
}

- (void) sendReceiptEmailForObject: (iCalEntityObject *) object
		     addedAttendees: (NSArray *) theAddedAttendees
		   deletedAttendees: (NSArray *) theDeletedAttendees
		   updatedAttendees: (NSArray *) theUpdatedAttendees
			  operation: (SOGoComponentOperation) theOperation
{
}

@end

@interface TestSOGoAppointmentObjectStoreErrors : SOGoTest
@end

@implementation TestSOGoAppointmentObjectStoreErrors

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (iCalCalendar *) _calendar
{
  iCalCalendar *calendar;

  calendar = [iCalCalendar parseSingleFromSource:
                        @"BEGIN:VCALENDAR\r\n"
                        @"VERSION:2.0\r\n"
                        @"BEGIN:VEVENT\r\n"
                        @"UID:test-6050.ics\r\n"
                        @"SUMMARY:Test\r\n"
                        @"DTSTART:20301105T100000Z\r\n"
                        @"DTEND:20301105T110000Z\r\n"
                        @"END:VEVENT\r\n"
                        @"END:VCALENDAR\r\n"];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");

  return calendar;
}

- (TestSOGoAppointmentObjectStoreErrorsStub *) _object
{
  TestSOGoAppointmentObjectStoreErrorsStub *object;

  object = [TestSOGoAppointmentObjectStoreErrorsStub objectWithName: @"test-6050.ics"
                                                        andContent: nil
                                                       inContainer: nil];
  [object setIsNew: YES];
  [object setStoreError: nil];

  return object;
}

- (void) test_saveCalendarSurfacesStoreError
{
  TestSOGoAppointmentObjectStoreErrorsStub *object;
  NSException *error;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  object = [self _object];
  error = [NSException exceptionWithName: @"StoreError"
                                   reason: @"Incorrect string value"
                                 userInfo: nil];
  [object setStoreError: error];

  test ([object saveCalendar: [self _calendar]] == error);
}

- (void) test_saveCalendarReturnsNilWhenStoreSucceeds
{
  TestSOGoAppointmentObjectStoreErrorsStub *object;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  object = [self _object];

  test ([object saveCalendar: [self _calendar]] == nil);
}

- (void) test_saveComponentSurfacesStoreError
{
  TestSOGoAppointmentObjectStoreErrorsStub *object;
  NSException *error;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  object = [self _object];
  error = [NSException exceptionWithName: @"StoreError"
                                   reason: @"Incorrect string value"
                                 userInfo: nil];
  [object setStoreError: error];

  test ([object saveComponent: [[self _calendar] firstChildWithTag: @"vevent"]
                        force: NO] == error);
}

- (void) test_saveComponentReturnsNilWhenStoreSucceeds
{
  TestSOGoAppointmentObjectStoreErrorsStub *object;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  object = [self _object];

  test ([object saveComponent: [[self _calendar] firstChildWithTag: @"vevent"]
                        force: NO] == nil);
}

@end
