/* TestiCalEntityObjectEmailAlarms.m - this file is part of SOGo
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
 * along with this program; if not, see <http://www.gnu.org/licenses/>.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>

#import <GDLContentStore/GCSAlarmsFolder.h>
#import <GDLContentStore/GCSFolderManager.h>

#import "SOGoTest.h"

@class SOGoUser;

@interface iCalEntityObject (SOGoTestsDeclaration)
- (void) updateNextAlarmDateInRow: (NSMutableDictionary *) row
                      forContainer: (id) theContainer
                   nameInContainer: (NSString *) nameInContainer;
@end

static NSMutableArray *test6131AlarmsFolderCalls = nil;

@implementation GCSAlarmsFolder (SOGoTestsOverride)

- (NSDictionary *) recordForEntryWithCName: (NSString *) cname
                           inCalendarAtPath: (NSString *) path
{
  [test6131AlarmsFolderCalls addObject:
               [NSDictionary dictionaryWithObjectsAndKeys:
                          @"record", @"op", cname, @"cname", path, @"path", nil]];

  return nil;
}

- (void) writeRecordForEntryWithCName: (NSString *) cname
                      inCalendarAtPath: (NSString *) path
                                forUID: (NSString *) uid
                          recurrenceId: (NSCalendarDate *) recId
                           alarmNumber: (NSNumber *) alarmNbr
                          andAlarmDate: (NSCalendarDate *) alarmDate
{
  [test6131AlarmsFolderCalls addObject:
               [NSDictionary dictionaryWithObjectsAndKeys:
                          @"write", @"op", cname, @"cname", path, @"path", nil]];
}

- (void) deleteRecordForEntryWithCName: (NSString *) cname
                       inCalendarAtPath: (NSString *) path
{
  [test6131AlarmsFolderCalls addObject:
               [NSDictionary dictionaryWithObjectsAndKeys:
                          @"delete", @"op", cname, @"cname", path, @"path", nil]];
}

@end

@interface Test6131CalendarContainer : NSObject
{
  NSString *path;
}
+ (id) containerWithPath: (NSString *) newPath;
- (NSString *) ocsPath;
@end

@implementation Test6131CalendarContainer

+ (id) containerWithPath: (NSString *) newPath
{
  Test6131CalendarContainer *container;

  container = [self new];
  container->path = [newPath retain];

  return [container autorelease];
}

- (void) dealloc
{
  [path release];
  [super dealloc];
}

- (NSString *) ocsPath
{
  return path;
}

@end

@interface TestiCalEntityObjectEmailAlarms : SOGoTest
@end

@implementation TestiCalEntityObjectEmailAlarms

+ (void) initialize
{
  NSUserDefaults *ud;

  if (self == [TestiCalEntityObjectEmailAlarms class])
    {
      ud = [NSUserDefaults standardUserDefaults];
      [ud registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"YES", @"SOGoEnableEMailAlarms",
                                     @"mysql://sogo:sogo@127.0.0.1:1/sogo/sogo_alarms_folder",
                                     @"OCSEMailAlarmsFolderURL",
                                     @"mysql://sogo:sogo@127.0.0.1:1/sogo/sogo_folder_info",
                                     @"OCSFolderInfoURL",
                                     @"127.0.0.1:11211", @"SOGoMemcachedHost",
                                     nil]];
    }
}

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

- (iCalEvent *) _orphanedOccurrenceWithExpiredEmailAlarm
{
  iCalCalendar *calendar;
  iCalEvent *event;

  calendar = [iCalCalendar parseSingleFromSource:
                         @"BEGIN:VCALENDAR\r\n"
                         @"VERSION:2.0\r\n"
                         @"BEGIN:VEVENT\r\n"
                         @"UID:test-6131-orphan\r\n"
                         @"SUMMARY:Test Evt Sogo Alarm Issue\r\n"
                         @"DTSTART:20250628T063000Z\r\n"
                         @"DTEND:20250628T073000Z\r\n"
                         @"RECURRENCE-ID:20250628T063000Z\r\n"
                         @"BEGIN:VALARM\r\n"
                         @"TRIGGER;VALUE=DURATION;RELATED=START:-P1W\r\n"
                         @"ACTION:EMAIL\r\n"
                         @"ATTENDEE;CN=SOGo:mailto:sogo@example.org\r\n"
                         @"SUMMARY:Test Evt Sogo Alarm Issue\r\n"
                         @"END:VALARM\r\n"
                         @"END:VEVENT\r\n"
                         @"END:VCALENDAR\r\n"];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");
  event = [[calendar events] objectAtIndex: 0];
  testWithMessage (event != nil, @"no VEVENT found in iCalendar content");
  testWithMessage (![event isRecurrent] && [event recurrenceId] != nil,
                   @"fixture must be an orphaned occurrence");

  return event;
}

- (void) setUp
{
  GCSAlarmsFolder *af;

  test6131AlarmsFolderCalls = [NSMutableArray array];
  [test6131AlarmsFolderCalls retain];

  af = [[GCSFolderManager defaultFolderManager] alarmsFolder];
  testWithMessage (af != nil,
                   @"emails alarms folder must be available for the test "
                   @"to be significant");
}

- (void) tearDown
{
  [test6131AlarmsFolderCalls release];
  test6131AlarmsFolderCalls = nil;
}

- (void) test_emailAlarmsFolderUntouchedWithoutContainer
{
  iCalEvent *event;
  NSMutableDictionary *row;
  NSString *message;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _orphanedOccurrenceWithExpiredEmailAlarm];
  row = [NSMutableDictionary dictionary];

  [event updateNextAlarmDateInRow: row
                      forContainer: nil
                   nameInContainer: nil];

  message = [NSString stringWithFormat:
                      @"flattening records must not touch the email alarms "
                      @"folder, got: %@",
                      test6131AlarmsFolderCalls];
  testWithMessage ([test6131AlarmsFolderCalls count] == 0, message);
  testWithMessage ([[row objectForKey: @"c_nextalarm"] intValue] == 0,
                   @"c_nextalarm must be reset when the email alarm is skipped");
}

- (void) test_emailAlarmsFolderUntouchedWithoutContainerAndWithName
{
  iCalEvent *event;
  NSMutableDictionary *row;
  NSString *message;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _orphanedOccurrenceWithExpiredEmailAlarm];
  row = [NSMutableDictionary dictionary];

  [event updateNextAlarmDateInRow: row
                      forContainer: nil
                   nameInContainer: @"test-6131-orphan.ics"];

  message = [NSString stringWithFormat:
                      @"flattening records must not touch the email alarms "
                      @"folder, got: %@",
                      test6131AlarmsFolderCalls];
  testWithMessage ([test6131AlarmsFolderCalls count] == 0, message);
}

- (void) test_expiredEmailAlarmDeletedWithContainer
{
  iCalEvent *event;
  NSMutableDictionary *row;
  NSArray *expected;
  NSString *message;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _orphanedOccurrenceWithExpiredEmailAlarm];
  row = [NSMutableDictionary dictionary];

  [event updateNextAlarmDateInRow: row
                      forContainer: [Test6131CalendarContainer
                                      containerWithPath:
                                        @"/SOGo/sogo-tests1/calendar/personal"]
                   nameInContainer: @"test-6131-orphan.ics"];

  expected = [NSArray arrayWithObject:
                       [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"delete", @"op",
                                  @"test-6131-orphan.ics", @"cname",
                                  @"/SOGo/sogo-tests1/calendar/personal", @"path",
                                  nil]];
  message = [NSString stringWithFormat:
                      @"saving must delete the expired alarm record exactly "
                      @"once with the container coordinates, got: %@",
                      test6131AlarmsFolderCalls];
  testWithMessage ([test6131AlarmsFolderCalls isEqualTo: expected], message);
}

- (void) test_emailAlarmsFolderUntouchedWhenDisabled
{
  iCalEvent *event;
  NSMutableDictionary *row;
  NSUserDefaults *ud;
  NSString *message;

  if (!LoadAppointmentsBundle ())
    {
      testWithMessage (NO, @"Appointments.SOGo bundle unavailable");
      return;
    }

  event = [self _orphanedOccurrenceWithExpiredEmailAlarm];
  row = [NSMutableDictionary dictionary];

  ud = [NSUserDefaults standardUserDefaults];
  [ud setObject: @"NO" forKey: @"SOGoEnableEMailAlarms"];
  [event updateNextAlarmDateInRow: row
                      forContainer: [Test6131CalendarContainer
                                      containerWithPath:
                                        @"/SOGo/sogo-tests1/calendar/personal"]
                   nameInContainer: @"test-6131-orphan.ics"];
  [ud removeObjectForKey: @"SOGoEnableEMailAlarms"];

  message = [NSString stringWithFormat:
                      @"disabled email alarms must not touch the email alarms "
                      @"folder, got: %@",
                      test6131AlarmsFolderCalls];
  testWithMessage ([test6131AlarmsFolderCalls count] == 0, message);
}

@end
