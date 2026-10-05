/* UIxCalWeekView.m - this file is part of SOGo
 *
 * Copyright (C) 2006 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */


#import <NGExtensions/NSCalendarDate+misc.h>


#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>

#include "UIxCalWeekView.h"

@implementation UIxCalWeekView

- (id <WOActionResults>) defaultAction
{
  [super setCurrentView: @"weekview"];

  return self;
}

- (NSCalendarDate *) startDate
{
  NSCalendarDate *date;

  date = [[context activeUser] firstDayOfWeekForDate: [super startDate]];

  return [self _nextValidDate: [date beginOfDay]];
}

- (NSCalendarDate *) endDate
{
  unsigned offset;
  SOGoUserDefaults *ud;

  ud = [[context activeUser] userDefaults];
  if ([ud calendarShouldDisplayWeekend])
    offset = 7;
  else
    offset = 5;

  return [[[self startDate] dateByAddingYears: 0 months: 0 days: offset
                                        hours: 0 minutes: 0 seconds: 0]
           endOfDay];
}

/* URLs */

- (NSDictionary *) prevWeekQueryParameters
{
  return [self _dateQueryParametersWithOffset: -7];
}

- (NSDictionary *) nextWeekQueryParameters
{
  return [self _dateQueryParametersWithOffset: 7];
}

@end /* UIxCalWeekView */
