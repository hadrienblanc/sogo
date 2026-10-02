/* TestSOGoFreeBusyObject.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses/>.
 */

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSTimeZone.h>

#import <Appointments/SOGoFreeBusyObject.h>

#import "SOGoTest.h"

@interface TestSOGoFreeBusyObject : SOGoTest
@end

@implementation TestSOGoFreeBusyObject

- (NSCalendarDate *) _dateWithYear: (int) year
                             month: (int) month
                               day: (int) day
                              hour: (int) hour
                            minute: (int) minute
                        timeZoneId: (NSString *) tzId
{
  return [NSCalendarDate dateWithYear: year month: month day: day
                                hour: hour minute: minute second: 0
                              timeZone: [NSTimeZone timeZoneWithName: tzId]];
}

- (NSArray *) _infosFrom: (int) startYear
                 startDay: (int) startDay
               startHour: (int) startHour
                 startMin: (int) startMin
                     toDay: (int) endDay
                   toHour: (int) endHour
                     toMin: (int) endMin
               ownerZone: (NSString *) ownerZoneId
                 viewZone: (NSString *) viewZoneId
{
  return [SOGoFreeBusyObject busyOffHoursInfosFrom:
                     [self _dateWithYear: startYear month: 10 day: startDay
                                   hour: startHour minute: startMin
                               timeZoneId: viewZoneId]
                                             to:
                     [self _dateWithYear: startYear month: 10 day: endDay
                                   hour: endHour minute: endMin
                               timeZoneId: viewZoneId]
                                   dayStartHour: 10
                                     dayEndHour: 18
                                 ownerTimeZone: [NSTimeZone timeZoneWithName: ownerZoneId]
                                   viewTimeZone: [NSTimeZone timeZoneWithName: viewZoneId]];
}

- (NSString *) _wallClock: (NSCalendarDate *) theDate
{
  return [NSString stringWithFormat: @"%04d-%02d-%02d %02d:%02d %@",
                   (int) [theDate yearOfCommonEra],
                   (int) [theDate monthOfYear],
                   (int) [theDate dayOfMonth],
                   (int) [theDate hourOfDay],
                   (int) [theDate minuteOfHour],
                   [[theDate timeZone] name]];
}

- (void) test_busyOffHoursShiftedToViewerTimezone
{
  NSArray *infos;
  NSDictionary *info;

  infos = [self _infosFrom: 2026 startDay: 15 startHour: 0 startMin: 0
                     toDay: 15 toHour: 23 toMin: 59
               ownerZone: @"Europe/Lisbon"
                 viewZone: @"Europe/Warsaw"];

  testEquals([NSNumber numberWithUnsignedInt: [infos count]],
             [NSNumber numberWithUnsignedInt: 2]);

  info = [infos objectAtIndex: 0];
  testEquals([NSNumber numberWithBool: [[info objectForKey: @"c_isopaque"] boolValue]],
             [NSNumber numberWithBool: YES]);
  testEquals([self _wallClock: [info objectForKey: @"startDate"]],
             @"2026-10-15 00:00 Europe/Warsaw");
  testEquals([self _wallClock: [info objectForKey: @"endDate"]],
             @"2026-10-15 11:00 Europe/Warsaw");

  info = [infos objectAtIndex: 1];
  testEquals([self _wallClock: [info objectForKey: @"startDate"]],
             @"2026-10-15 19:00 Europe/Warsaw");
  testEquals([self _wallClock: [info objectForKey: @"endDate"]],
             @"2026-10-15 23:59 Europe/Warsaw");
}

- (void) test_busyOffHoursSameTimezone
{
  NSArray *infos;
  NSDictionary *info;

  infos = [self _infosFrom: 2026 startDay: 15 startHour: 0 startMin: 0
                     toDay: 15 toHour: 23 toMin: 59
               ownerZone: @"Europe/Lisbon"
                 viewZone: @"Europe/Lisbon"];

  testEquals([NSNumber numberWithUnsignedInt: [infos count]],
             [NSNumber numberWithUnsignedInt: 2]);

  info = [infos objectAtIndex: 0];
  testEquals([self _wallClock: [info objectForKey: @"startDate"]],
             @"2026-10-15 00:00 Europe/Lisbon");
  testEquals([self _wallClock: [info objectForKey: @"endDate"]],
             @"2026-10-15 10:00 Europe/Lisbon");

  info = [infos objectAtIndex: 1];
  testEquals([self _wallClock: [info objectForKey: @"startDate"]],
             @"2026-10-15 18:00 Europe/Lisbon");
  testEquals([self _wallClock: [info objectForKey: @"endDate"]],
             @"2026-10-15 23:59 Europe/Lisbon");
}

- (void) test_busyOffHoursWeekendFullyBusy
{
  NSArray *infos;
  NSDictionary *info;
  unsigned int i;

  infos = [self _infosFrom: 2026 startDay: 16 startHour: 0 startMin: 0
                     toDay: 19 toHour: 0 toMin: 0
               ownerZone: @"Europe/Lisbon"
                 viewZone: @"Europe/Lisbon"];

  testEquals([NSNumber numberWithUnsignedInt: [infos count]],
             [NSNumber numberWithUnsignedInt: 6]);

  info = [infos objectAtIndex: 0];
  testEquals([self _wallClock: [info objectForKey: @"startDate"]],
             @"2026-10-16 00:00 Europe/Lisbon");
  testEquals([self _wallClock: [info objectForKey: @"endDate"]],
             @"2026-10-16 10:00 Europe/Lisbon");

  info = [infos objectAtIndex: 1];
  testEquals([self _wallClock: [info objectForKey: @"startDate"]],
             @"2026-10-16 18:00 Europe/Lisbon");
  testEquals([self _wallClock: [info objectForKey: @"endDate"]],
             @"2026-10-17 10:00 Europe/Lisbon");

  info = [infos objectAtIndex: 2];
  testEquals([self _wallClock: [info objectForKey: @"startDate"]],
             @"2026-10-17 10:00 Europe/Lisbon");
  testEquals([self _wallClock: [info objectForKey: @"endDate"]],
             @"2026-10-17 18:00 Europe/Lisbon");

  info = [infos objectAtIndex: 3];
  testEquals([self _wallClock: [info objectForKey: @"startDate"]],
             @"2026-10-17 18:00 Europe/Lisbon");
  testEquals([self _wallClock: [info objectForKey: @"endDate"]],
             @"2026-10-18 10:00 Europe/Lisbon");

  info = [infos objectAtIndex: 4];
  testEquals([self _wallClock: [info objectForKey: @"startDate"]],
             @"2026-10-18 10:00 Europe/Lisbon");
  testEquals([self _wallClock: [info objectForKey: @"endDate"]],
             @"2026-10-18 18:00 Europe/Lisbon");

  info = [infos objectAtIndex: 5];
  testEquals([self _wallClock: [info objectForKey: @"startDate"]],
             @"2026-10-18 18:00 Europe/Lisbon");
  testEquals([self _wallClock: [info objectForKey: @"endDate"]],
             @"2026-10-19 00:00 Europe/Lisbon");

  testEquals([self _wallClock: [[infos objectAtIndex: 1] objectForKey: @"startDate"]],
             @"2026-10-16 18:00 Europe/Lisbon");

  for (i = 2; i < [infos count]; i++)
    test([[[infos objectAtIndex: i] objectForKey: @"startDate"] isEqual:
           [[infos objectAtIndex: (i - 1)] objectForKey: @"endDate"]]);
}

- (void) test_busyOffHoursWindowStartingDuringOffHours
{
  NSArray *infos;
  NSDictionary *info;

  infos = [self _infosFrom: 2026 startDay: 15 startHour: 6 startMin: 30
                     toDay: 15 toHour: 23 toMin: 59
               ownerZone: @"Europe/Lisbon"
                 viewZone: @"Europe/Lisbon"];

  testEquals([NSNumber numberWithUnsignedInt: [infos count]],
             [NSNumber numberWithUnsignedInt: 2]);

  info = [infos objectAtIndex: 0];
  testEquals([self _wallClock: [info objectForKey: @"startDate"]],
             @"2026-10-15 06:30 Europe/Lisbon");
  testEquals([self _wallClock: [info objectForKey: @"endDate"]],
             @"2026-10-15 10:00 Europe/Lisbon");

  info = [infos objectAtIndex: 1];
  testEquals([self _wallClock: [info objectForKey: @"startDate"]],
             @"2026-10-15 18:00 Europe/Lisbon");
  testEquals([self _wallClock: [info objectForKey: @"endDate"]],
             @"2026-10-15 23:59 Europe/Lisbon");
}

- (void) test_busyOffHoursWindowStartingInsideWorkingHours
{
  NSArray *infos;
  NSDictionary *info;

  infos = [self _infosFrom: 2026 startDay: 15 startHour: 10 startMin: 30
                     toDay: 15 toHour: 23 toMin: 59
               ownerZone: @"Europe/Lisbon"
                 viewZone: @"Europe/Lisbon"];

  testEquals([NSNumber numberWithUnsignedInt: [infos count]],
             [NSNumber numberWithUnsignedInt: 1]);

  info = [infos objectAtIndex: 0];
  testEquals([self _wallClock: [info objectForKey: @"startDate"]],
             @"2026-10-15 18:00 Europe/Lisbon");
  testEquals([self _wallClock: [info objectForKey: @"endDate"]],
             @"2026-10-15 23:59 Europe/Lisbon");
}

@end
