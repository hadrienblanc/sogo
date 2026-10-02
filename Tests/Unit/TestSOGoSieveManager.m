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

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <SOGo/SOGoSieveManager.h>

#import "SOGoTest.h"

@interface SOGoSieveManager (SOGoSieveManagerTest)

- (NSString *) _extractSieveAction: (NSDictionary *) action
                            withReq: (NSMutableDictionary *) req
                          delimiter: (NSString *) delimiter;

- (NSString *) _extractSieveRule: (NSDictionary *) rule;

- (NSString *) _convertScriptToSieve: (NSDictionary *) newScript
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

- (void) test_extractSieveAction_unknownMethod
{
  SOGoSieveManager *manager;
  NSMutableDictionary *req;
  NSDictionary *action;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];
  req = [NSMutableDictionary dictionary];

  action = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"bogusmethod", @"method",
                       @"bogus", @"argument",
                       nil];
  test([manager _extractSieveAction: action withReq: req delimiter: @"/"] == nil);
  testEquals([manager lastScriptError],
             @"Action has unknown method 'bogusmethod'");
}

- (void) test_extractSieveAction_missingArgument
{
  SOGoSieveManager *manager;
  NSMutableDictionary *req;
  NSDictionary *action;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];
  req = [NSMutableDictionary dictionary];

  action = [NSDictionary dictionaryWithObject: @"fileinto" forKey: @"method"];
  test([manager _extractSieveAction: action withReq: req delimiter: @"/"] == nil);
  testEquals([manager lastScriptError],
             @"Action missing 'argument' parameter");
}

- (void) test_extractSieveAction_missingMethod
{
  SOGoSieveManager *manager;
  NSMutableDictionary *req;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];
  req = [NSMutableDictionary dictionary];

  test([manager _extractSieveAction: [NSDictionary dictionary]
                            withReq: req delimiter: @"/"] == nil);
  testEquals([manager lastScriptError],
             @"Action missing 'method' parameter");
}

- (void) test_extractSieveRule_validRule
{
  SOGoSieveManager *manager;
  NSDictionary *rule;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];

  rule = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"subject", @"field",
                       @"contains", @"operator",
                       @"hello", @"value",
                       nil];
  testEquals([manager _extractSieveRule: rule],
             @"header :contains \"subject\" \"hello\"");
  test([manager lastScriptError] == nil);
}

- (void) test_extractSieveRule_withoutField
{
  SOGoSieveManager *manager;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];

  test([manager _extractSieveRule: [NSDictionary dictionary]] == nil);
  testEquals([manager lastScriptError],
             @"Rule without any specified field.");
}

- (void) test_extractSieveRule_unknownField
{
  SOGoSieveManager *manager;
  NSDictionary *rule;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];

  rule = [NSDictionary dictionaryWithObject: @"bogus" forKey: @"field"];
  test([manager _extractSieveRule: rule] == nil);
  testEquals([manager lastScriptError],
             @"Rule based on unknown field 'bogus'");
}

- (void) test_extractSieveRule_headerWithoutCustomHeader
{
  SOGoSieveManager *manager;
  NSDictionary *rule;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];

  rule = [NSDictionary dictionaryWithObject: @"header" forKey: @"field"];
  test([manager _extractSieveRule: rule] == nil);
  testEquals([manager lastScriptError],
             @"Pseudo-header field 'header' without 'custom_header' parameter.");
}

- (void) test_extractSieveRule_withoutOperator
{
  SOGoSieveManager *manager;
  NSDictionary *rule;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];

  rule = [NSDictionary dictionaryWithObject: @"subject" forKey: @"field"];
  test([manager _extractSieveRule: rule] == nil);
  testEquals([manager lastScriptError],
             @"Rule without any specified operator");
}

- (void) test_extractSieveRule_unknownOperator
{
  SOGoSieveManager *manager;
  NSDictionary *rule;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];

  rule = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"subject", @"field",
                       @"bogus", @"operator",
                       nil];
  test([manager _extractSieveRule: rule] == nil);
  testEquals([manager lastScriptError],
             @"Rule has unknown operator 'bogus'");
}

- (void) test_extractSieveRule_withoutValue
{
  SOGoSieveManager *manager;
  NSDictionary *rule;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];

  rule = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"subject", @"field",
                       @"contains", @"operator",
                       nil];
  test([manager _extractSieveRule: rule] == nil);
  testEquals([manager lastScriptError],
             @"Rule lacks a 'value' parameter");
}

- (void) test_convertScriptToSieve_badTest
{
  SOGoSieveManager *manager;
  NSMutableDictionary *req;
  NSDictionary *script;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];
  req = [NSMutableDictionary dictionary];

  script = [NSDictionary dictionaryWithObject: @"bogus" forKey: @"match"];
  [manager _convertScriptToSieve: script withReq: req delimiter: @"/"];
  testEquals([manager lastScriptError], @"Bad test: bogus");
}

- (void) test_convertScriptToSieve_matchWithoutRule
{
  SOGoSieveManager *manager;
  NSMutableDictionary *req;
  NSDictionary *script;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];
  req = [NSMutableDictionary dictionary];

  script = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"all", @"match",
                       [NSArray array], @"rules",
                       nil];
  [manager _convertScriptToSieve: script withReq: req delimiter: @"/"];
  testEquals([manager lastScriptError],
             @"Test 'all' used without any specified rule");
}

- (void) test_scriptErrorOwnershipAcrossAllErrorBranches
{
  NSAutoreleasePool *pool;
  SOGoSieveManager *manager;
  NSMutableDictionary *req;
  NSDictionary *rule, *action, *script;

  pool = [NSAutoreleasePool new];
  req = [NSMutableDictionary dictionary];

  manager = [[SOGoSieveManager alloc] initForUser: nil];
  rule = [NSDictionary dictionaryWithObject: @"bogus" forKey: @"field"];
  test([manager _extractSieveRule: rule] == nil);
  testEquals([manager lastScriptError], @"Rule based on unknown field 'bogus'");
  [manager release];

  manager = [[SOGoSieveManager alloc] initForUser: nil];
  rule = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"subject", @"field",
                       @"bogus", @"operator",
                       nil];
  test([manager _extractSieveRule: rule] == nil);
  testEquals([manager lastScriptError], @"Rule has unknown operator 'bogus'");
  [manager release];

  manager = [[SOGoSieveManager alloc] initForUser: nil];
  action = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"bogusmethod", @"method",
                       @"bogus", @"argument",
                       nil];
  test([manager _extractSieveAction: action withReq: req delimiter: @"/"] == nil);
  testEquals([manager lastScriptError],
             @"Action has unknown method 'bogusmethod'");
  [manager release];

  manager = [[SOGoSieveManager alloc] initForUser: nil];
  action = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"addflag", @"method",
                       @"bogus", @"argument",
                       nil];
  test([manager _extractSieveAction: action withReq: req delimiter: @"/"] == nil);
  testEquals([manager lastScriptError],
             @"Action with invalid flag argument 'bogus'");
  [manager release];

  manager = [[SOGoSieveManager alloc] initForUser: nil];
  script = [NSDictionary dictionaryWithObject: @"bogus" forKey: @"match"];
  [manager _convertScriptToSieve: script withReq: req delimiter: @"/"];
  testEquals([manager lastScriptError], @"Bad test: bogus");
  [manager release];

  manager = [[SOGoSieveManager alloc] initForUser: nil];
  script = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"all", @"match",
                       [NSArray array], @"rules",
                       nil];
  [manager _convertScriptToSieve: script withReq: req delimiter: @"/"];
  testEquals([manager lastScriptError],
             @"Test 'all' used without any specified rule");
  [manager release];

  [pool release];
}

- (void) test_sieveScriptWithRequirements_resetsPreviousError
{
  SOGoSieveManager *manager;
  NSMutableDictionary *req;
  NSDictionary *action;
  NSString *sieveScript;

  manager = [[[SOGoSieveManager alloc] initForUser: nil] autorelease];
  req = [NSMutableDictionary dictionary];

  action = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"addflag", @"method",
                       @"bogus", @"argument",
                       nil];
  test([manager _extractSieveAction: action withReq: req delimiter: @"/"] == nil);
  test([manager lastScriptError] != nil);

  sieveScript = [manager sieveScriptWithRequirements: req delimiter: @"/"];
  testEquals(sieveScript, @"");
  test([manager lastScriptError] == nil);
}

@end
