/* TestSOGoUserProfile.m - this file is part of SOGo
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
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUserProfile.h>

#import "SOGoTest.h"

@interface SOGoUserProfile (SOGoUserProfileTest)

- (NSString *) _convertPListToJSON: (NSString *) plistValue;

@end

@interface TestSOGoUserProfile : SOGoTest
@end

@implementation TestSOGoUserProfile

- (SOGoUserProfile *) _defaultsProfile
{
  return [SOGoUserProfile userProfileWithType: SOGoUserProfileTypeDefaults
                                      forUID: @"test-6129"];
}

- (void) test_convertPListToJSON_legacyPlistValue
{
  NSString *json;
  id parsed;

  json = [[self _defaultsProfile]
           _convertPListToJSON: @"{ SOGoTimeZone = \"Europe/Berlin\";"
                          @" Vacation = { enabled = YES; }; }"];
  parsed = [json objectFromJSONString];
  testWithMessage(parsed != nil, @"legacy plist profile must convert to JSON");
  testEquals([parsed objectForKey: @"SOGoTimeZone"], @"Europe/Berlin");
  test([[[parsed objectForKey: @"Vacation"] objectForKey: @"enabled"] boolValue]);
}

- (void) test_convertPListToJSON_legacyPlistMissingFinalSemicolon
{
  NSString *json;
  id parsed;

  json = [[self _defaultsProfile]
           _convertPListToJSON: @"{ SOGoTimeZone = \"Europe/Berlin\";"
                          @" Vacation = { enabled = YES }\n}"];
  parsed = [json objectFromJSONString];
  testWithMessage(parsed != nil,
                  @"legacy plist profile missing its final semicolons must"
                  @" still convert to JSON");
  testEquals([parsed objectForKey: @"SOGoTimeZone"], @"Europe/Berlin");
  test([[[parsed objectForKey: @"Vacation"] objectForKey: @"enabled"] boolValue]);
}

- (void) test_convertPListToJSON_unparsableValueYieldsEmptyJSON
{
  NSString *json;

  json = [[self _defaultsProfile] _convertPListToJSON: @"certainly not a"];
  testEquals(json, @"{}");
}

@end
