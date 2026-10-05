/*
  Copyright (C) 2004 SKYRIX Software AG
  Copyright (C) 2006-2016 Inverse inc.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSDictionary.h>

#import <NGExtensions/NSCalendarDate+misc.h>

#import "UIxCalDayView.h"

@implementation UIxCalDayView

- (id <WOActionResults>) defaultAction
{
  [super setCurrentView: @"dayview"];

  return self;
}

/* URLs */

- (NSDictionary *) prevDayQueryParameters
{
  return [self _dateQueryParametersWithOffset: [self _nextValidOffset: -1]];
}

- (NSDictionary *) nextDayQueryParameters
{
  return [self _dateQueryParametersWithOffset: [self _nextValidOffset: +1]];
}

/* fetching */

- (NSCalendarDate *) startDate
{
  return [[self selectedDate] beginOfDay];
}

/* appointments */

- (NSString *) _dayNameWithOffsetFromToday: (int) offset
{
  NSCalendarDate *date;

  date = [[self selectedDate] dateByAddingYears: 0
                                         months: 0
                                           days: offset];

  return [self localizedNameForDayOfWeek: [date dayOfWeek]];
}

- (NSString *) yesterdayName
{
  return [self _dayNameWithOffsetFromToday: [self _nextValidOffset: -1]];
}

- (NSString *) tomorrowName
{
  return [self _dayNameWithOffsetFromToday: [self _nextValidOffset: +1]];
}

@end
