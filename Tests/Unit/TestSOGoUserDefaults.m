/* TestSOGoUserDefaults.m - this file is part of SOGo
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

#import <SOGo/SOGoUserDefaults.h>
#import "SOGoTest.h"

@interface TestSOGoUserDefaults : SOGoTest
@end

@implementation TestSOGoUserDefaults

- (SOGoUserDefaults *) _defaultsWithSource: (NSDictionary *) userSource
                              parentSource: (NSDictionary *) parentSource
{
  SOGoDefaultsSource *parent;
  SOGoUserDefaults *defaults;

  parent = [SOGoDefaultsSource defaultsSourceWithSource: parentSource
                                        andParentSource: nil];
  defaults = [SOGoUserDefaults defaultsSourceWithSource: userSource
                                        andParentSource: parent];

  return defaults;
}

- (void) test_refreshViewCheckFromUserSource
{
  SOGoUserDefaults *defaults;
  NSDictionary *userSource;

  userSource = [NSDictionary dictionaryWithObject: @"every_minute"
                                           forKey: @"SOGoRefreshViewCheck"];
  defaults = [self _defaultsWithSource: userSource
                          parentSource: [NSDictionary dictionary]];

  testEquals([defaults refreshViewCheck], @"every_minute");
}

- (void) test_refreshViewCheckFallsBackToParentSource
{
  SOGoUserDefaults *defaults;
  NSDictionary *parentSource;

  parentSource = [NSDictionary dictionaryWithObject: @"every_5_minutes"
                                              forKey: @"SOGoRefreshViewCheck"];
  defaults = [self _defaultsWithSource: [NSDictionary dictionary]
                          parentSource: parentSource];

  testEquals([defaults refreshViewCheck], @"every_5_minutes");
}

- (void) test_refreshViewCheckUnset
{
  SOGoUserDefaults *defaults;

  defaults = [self _defaultsWithSource: [NSDictionary dictionary]
                          parentSource: [NSDictionary dictionary]];

  testEquals([defaults refreshViewCheck], nil);
}

- (void) test_refreshViewCheckRejectsNonStringValue
{
  SOGoUserDefaults *defaults;
  NSDictionary *userSource;

  userSource = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: 60]
                                           forKey: @"SOGoRefreshViewCheck"];
  defaults = [self _defaultsWithSource: userSource
                          parentSource: [NSDictionary dictionary]];

  testEquals([defaults refreshViewCheck], nil);
}

- (void) test_setRefreshViewCheckStoresString
{
  SOGoUserDefaults *defaults;

  defaults = [self _defaultsWithSource: [NSMutableDictionary dictionary]
                          parentSource: [NSDictionary dictionary]];
  [defaults setRefreshViewCheck: @"every_minute"];

  testEquals([defaults refreshViewCheck], @"every_minute");
}

- (void) test_migrateLegacyRefreshViewCheckKey
{
  SOGoUserDefaults *defaults;
  NSMutableDictionary *userSource;

  userSource = [NSMutableDictionary dictionaryWithObject: @"once_per_hour"
                                                   forKey: @"RefreshViewCheck"];
  defaults = [self _defaultsWithSource: userSource
                          parentSource: [NSDictionary dictionary]];

  testEquals([defaults refreshViewCheck], @"once_per_hour");
  failIf([userSource objectForKey: @"RefreshViewCheck"] != nil);
}

- (void) test_calendarAutoAddExternalInvitationsUnset
{
  SOGoUserDefaults *defaults;

  defaults = [self _defaultsWithSource: [NSDictionary dictionary]
                          parentSource: [NSDictionary dictionary]];

  test ([defaults calendarAutoAddExternalInvitations] == NO);
}

- (void) test_calendarAutoAddExternalInvitationsFallsBackToParentSource
{
  SOGoUserDefaults *defaults;
  NSDictionary *parentSource;

  parentSource = [NSDictionary dictionaryWithObject: @"YES"
                                              forKey: @"SOGoCalendarAutoAddExternalInvitations"];
  defaults = [self _defaultsWithSource: [NSDictionary dictionary]
                          parentSource: parentSource];

  test ([defaults calendarAutoAddExternalInvitations] == YES);
}

- (void) test_calendarAutoAddExternalInvitationsUserSourceWins
{
  SOGoUserDefaults *defaults;
  NSDictionary *userSource, *parentSource;

  userSource = [NSDictionary dictionaryWithObject: @"NO"
                                           forKey: @"SOGoCalendarAutoAddExternalInvitations"];
  parentSource = [NSDictionary dictionaryWithObject: @"YES"
                                              forKey: @"SOGoCalendarAutoAddExternalInvitations"];
  defaults = [self _defaultsWithSource: userSource
                          parentSource: parentSource];

  test ([defaults calendarAutoAddExternalInvitations] == NO);
}

- (void) test_setCalendarAutoAddExternalInvitationsStoresBool
{
  SOGoUserDefaults *defaults;

  defaults = [self _defaultsWithSource: [NSMutableDictionary dictionary]
                          parentSource: [NSDictionary dictionary]];
  [defaults setCalendarAutoAddExternalInvitations: YES];

  test ([defaults calendarAutoAddExternalInvitations] == YES);
}

@end
