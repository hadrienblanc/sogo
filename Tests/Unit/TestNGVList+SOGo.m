/* TestNGVList+SOGo.m - this file is part of SOGo
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
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGCards/NGVList.h>

#import <Contacts/NGVList+SOGo.h>

#import "SOGoTest.h"

@interface TestNGVList_plus_SOGo : SOGoTest
@end

static BOOL
LoadContactsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Contacts"
                       markerClass: @"SOGoContactGCSFolder"];
}

@implementation TestNGVList_plus_SOGo

- (NGVList *) _listWithSource: (NSString *) source
{
  NGVList *list;

  testWithMessage (LoadContactsBundle (),
                   @"Contacts bundle could not be loaded");

  list = [NGVList parseSingleFromSource: source];
  testWithMessage ([list isKindOfClass: [NGVList class]],
                   @"VLIST source could not be parsed");

  return list;
}

- (NSDictionary *) _quickRecordForSource: (NSString *) source
{
  NGVList *list;

  list = [self _listWithSource: source];

  return [list quickRecordFromContent: source
                            container: nil
                      nameInContainer: @"list-uid.vlf"];
}

- (void) test_quickRecordKeepsFnAsCn
{
  NSDictionary *record;

  record = [self _quickRecordForSource:
             @"BEGIN:VLIST\r\n"
             @"UID:list-uid\r\n"
             @"VERSION:1.0\r\n"
             @"FN:Sales Team\r\n"
             @"NICKNAME:sales\r\n"
             @"END:VLIST"];

  testEquals([record objectForKey: @"c_cn"], @"Sales Team");
  testEquals([record objectForKey: @"c_component"], @"vlist");
}

- (void) test_quickRecordFallsBackToNicknameWhenFnIsMissing
{
  NSDictionary *record;

  record = [self _quickRecordForSource:
             @"BEGIN:VLIST\r\n"
             @"UID:list-uid\r\n"
             @"VERSION:1.0\r\n"
             @"NICKNAME:sales\r\n"
             @"END:VLIST"];

  testEquals([record objectForKey: @"c_cn"], @"sales");
  testEquals([record objectForKey: @"c_component"], @"vlist");
}

- (void) test_quickRecordFallsBackToNicknameWhenFnIsEmpty
{
  NSDictionary *record;

  record = [self _quickRecordForSource:
             @"BEGIN:VLIST\r\n"
             @"UID:list-uid\r\n"
             @"VERSION:1.0\r\n"
             @"FN:\r\n"
             @"NICKNAME:sales\r\n"
             @"END:VLIST"];

  testEquals([record objectForKey: @"c_cn"], @"sales");
  testEquals([record objectForKey: @"c_component"], @"vlist");
}

- (void) test_quickRecordWithoutFnOrNicknameHasNoCn
{
  NSDictionary *record;

  record = [self _quickRecordForSource:
             @"BEGIN:VLIST\r\n"
             @"UID:list-uid\r\n"
             @"VERSION:1.0\r\n"
             @"DESCRIPTION:plain list\r\n"
             @"END:VLIST"];

  test([record objectForKey: @"c_cn"] == nil);
  testEquals([record objectForKey: @"c_component"], @"vlist");
}

@end
