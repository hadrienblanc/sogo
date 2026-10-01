/* TestSOGoSieveManager.m - this file is part of SOGo
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

#import <SOGo/SOGoSieveManager.h>

#import "SOGoTest.h"

@interface SOGoSieveManager (SOGoSieveManagerTest)

- (NSString *) _extractSieveAction: (NSDictionary *) action
                           withReq: (NSMutableDictionary *) req
             delimiter: (NSString *) delimiter;

@end

@interface TestSOGoSieveManager : SOGoTest
@end

@implementation TestSOGoSieveManager

- (void) test_sieveFlagForArgument_systemFlags
{
  testEquals([SOGoSieveManager sieveFlagForArgument: @"seen" mailLabels: nil],
             @"\\Seen");
  testEquals([SOGoSieveManager sieveFlagForArgument: @"deleted" mailLabels: nil],
             @"\\Deleted");
  testEquals([SOGoSieveManager sieveFlagForArgument: @"answered" mailLabels: nil],
             @"\\Answered");
  testEquals([SOGoSieveManager sieveFlagForArgument: @"flagged" mailLabels: nil],
             @"\\Flagged");
  testEquals([SOGoSieveManager sieveFlagForArgument: @"draft" mailLabels: nil],
             @"\\Draft");
  testEquals([SOGoSieveManager sieveFlagForArgument: @"junk" mailLabels: nil],
             @"Junk");
  testEquals([SOGoSieveManager sieveFlagForArgument: @"not_junk" mailLabels: nil],
             @"NotJunk");
}

- (void) test_sieveFlagForArgument_customLabels
{
  NSDictionary *mailLabels;

  mailLabels = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSArray arrayWithObjects: @"Important", @"#ff0000", nil],
                              @"$label1",
                              nil];

  testEquals([SOGoSieveManager sieveFlagForArgument: @"$label1"
                                         mailLabels: mailLabels],
             @"$label1");
  test([SOGoSieveManager sieveFlagForArgument: @"bogus"
                                   mailLabels: mailLabels] == nil);
  test([SOGoSieveManager sieveFlagForArgument: @"Seen"
                                   mailLabels: mailLabels] == nil);
}

- (void) test_extractSieveAction_addflag
{
  SOGoSieveManager *manager;
  NSMutableDictionary *req;
  NSDictionary *action;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];
  req = [NSMutableDictionary dictionary];

  action = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"addflag", @"method",
                       @"seen", @"argument",
                       nil];
  testEquals([manager _extractSieveAction: action withReq: req delimiter: @"/"],
             @"addflag \"\\\\Seen\"");

  action = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"addflag", @"method",
                       @"flagged", @"argument",
                       nil];
  testEquals([manager _extractSieveAction: action withReq: req delimiter: @"/"],
             @"addflag \"\\\\Flagged\"");

  action = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"addflag", @"method",
                       @"junk", @"argument",
                       nil];
  testEquals([manager _extractSieveAction: action withReq: req delimiter: @"/"],
             @"addflag \"Junk\"");

  action = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"addflag", @"method",
                       @"not_junk", @"argument",
                       nil];
  testEquals([manager _extractSieveAction: action withReq: req delimiter: @"/"],
             @"addflag \"NotJunk\"");
}

- (void) test_extractSieveAction_addflagInvalidArgument
{
  SOGoSieveManager *manager;
  NSMutableDictionary *req;
  NSDictionary *action;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];
  req = [NSMutableDictionary dictionary];

  action = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"addflag", @"method",
                       @"bogus", @"argument",
                       nil];
  test([manager _extractSieveAction: action withReq: req delimiter: @"/"] == nil);
  testEquals([manager lastScriptError],
             @"Action with invalid flag argument 'bogus'");
}

@end
