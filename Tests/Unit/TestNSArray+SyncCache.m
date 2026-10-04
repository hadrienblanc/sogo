/* TestNSArray+SyncCache.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any
 * later version.
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import "NSArray+SyncCache.h"
#import "SOGoTest.h"

@interface TestNSArray_plus_SyncCache : SOGoTest
@end

@implementation TestNSArray_plus_SyncCache

- (NSArray *) _componentsWithLastModified: (NSArray *) theTimestamps
{
  NSMutableArray *components;
  int i;

  components = [NSMutableArray array];

  for (i = 0; i < [theTimestamps count]; i++)
    [components addObject: [NSDictionary dictionaryWithObject: [theTimestamps objectAtIndex: i]
                                                      forKey: @"c_lastmodified"]];

  return components;
}

- (void) test_syncKeyAdvancesAfterIndexRefusesCutInsideSameSecondRun
{
  NSArray *components;

  components = [self _componentsWithLastModified:
                  [NSArray arrayWithObjects: @"1722201660", @"1722201671", @"1722201671", @"1722201671", @"1722201699", nil]];

  test([components syncKeyAdvancesAfterIndex: 1] == NO);
  test([components syncKeyAdvancesAfterIndex: 2] == NO);
}

- (void) test_syncKeyAdvancesAfterIndexAllowsCutOnTimestampBoundary
{
  NSArray *components;

  components = [self _componentsWithLastModified:
                  [NSArray arrayWithObjects: @"1722201660", @"1722201671", @"1722201671", @"1722201671", @"1722201699", nil]];

  test([components syncKeyAdvancesAfterIndex: 0] == YES);
  test([components syncKeyAdvancesAfterIndex: 3] == YES);
}

- (void) test_syncKeyAdvancesAfterIndexAllowsCutAfterLastComponent
{
  NSArray *components;

  components = [self _componentsWithLastModified:
                  [NSArray arrayWithObjects: @"1722201671", @"1722201671", nil]];

  test([components syncKeyAdvancesAfterIndex: 1] == YES);
}

- (void) test_syncKeyAdvancesAfterIndexAllowsCutWithoutProcessedComponent
{
  NSArray *components;

  components = [self _componentsWithLastModified:
                  [NSArray arrayWithObjects: @"1722201671", @"1722201672", nil]];

  test([components syncKeyAdvancesAfterIndex: -1] == YES);
}

@end
