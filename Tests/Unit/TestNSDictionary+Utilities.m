/* TestNSDictionary+Utilities.m - this file is part of SOGo
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
 * Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <SOGo/NSDictionary+Utilities.h>

#import "SOGoTest.h"

@interface TestNSDictionary_plus_Utilities : SOGoTest
@end

@implementation TestNSDictionary_plus_Utilities

- (void) test_caseInsensitiveDisplayNameCompareSortsByDisplayName
{
  NSArray *users, *sortedUsers;

  users = [NSArray arrayWithObjects:
                     [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"jsmith", @"c_uid",
                                 @"Smith, John", @"cn",
                                 nil],
                     [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"aardvark", @"c_uid",
                                 @"aardvark, al", @"cn",
                                 nil],
                     [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"smartin", @"c_uid",
                                 @"Martin, Sue", @"cn",
                                 nil],
                     nil];
  sortedUsers = [users sortedArrayUsingSelector: @selector (caseInsensitiveDisplayNameCompare:)];

  testEquals([[sortedUsers objectAtIndex: 0] objectForKey: @"c_uid"], @"aardvark");
  testEquals([[sortedUsers objectAtIndex: 1] objectForKey: @"c_uid"], @"smartin");
  testEquals([[sortedUsers objectAtIndex: 2] objectForKey: @"c_uid"], @"jsmith");
}

- (void) test_caseInsensitiveDisplayNameComparePutsAlphabeticallyFirstFirst
{
  NSArray *users, *sortedUsers;

  users = [NSArray arrayWithObjects:
                     [NSDictionary dictionaryWithObject: @"Zuniga, Pedro" forKey: @"cn"],
                     [NSDictionary dictionaryWithObject: @"Smith, John" forKey: @"cn"],
                     nil];
  sortedUsers = [users sortedArrayUsingSelector: @selector (caseInsensitiveDisplayNameCompare:)];

  testWithMessage ([[[sortedUsers objectAtIndex: 0] objectForKey: @"cn"]
                     isEqualToString: @"Smith, John"],
                   @"usersSearch results ordered through "
                   @"caseInsensitiveDisplayNameCompare put the alphabetically first "
                   @"cn at index 0 (bug 6002)");
}

@end
