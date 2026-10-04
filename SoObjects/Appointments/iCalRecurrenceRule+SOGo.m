/* iCalRecurrenceRule+SOGo.m - this file is part of SOGo
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
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSString.h>

#import "iCalRecurrenceRule+SOGo.h"

@implementation iCalRecurrenceRule (SOGoExtensions)

- (NSString *) repeatLabelKey
{
  NSString *frequency;

  frequency = [self frequencyForValue: [self frequency]];

  if ([frequency isEqualToString: @"WEEKLY"] && [self repeatInterval] == 2)
    return @"repeat_BI-WEEKLY";

  if ([frequency isEqualToString: @"DAILY"]
      || [frequency isEqualToString: @"WEEKLY"]
      || [frequency isEqualToString: @"MONTHLY"]
      || [frequency isEqualToString: @"YEARLY"])
    return [NSString stringWithFormat: @"repeat_%@", frequency];

  return @"repeat_CUSTOM";
}

@end
