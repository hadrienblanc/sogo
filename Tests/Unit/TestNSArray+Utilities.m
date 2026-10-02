/* TestNSArray+Utilities.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>
#import "SOGoTest.h"

@interface TestNSArray_plus_Utilities : SOGoTest
@end

@implementation TestNSArray_plus_Utilities

- (void) test_stringsWithoutHTMLInjection
{
  NSArray *categories, *sanitized;

  categories = [NSArray arrayWithObjects: @"Colleague", @"Client", @"Famille", nil];
  sanitized = [categories stringsWithoutHTMLInjection: YES stripAngular: NO];
  failIf([sanitized count] != 3);
  testEquals([sanitized objectAtIndex: 0], @"Colleague");
  testEquals([sanitized objectAtIndex: 2], @"Famille");

  categories = [NSArray arrayWithObjects: @"<script>alert(1)</script>", nil];
  sanitized = [categories stringsWithoutHTMLInjection: YES stripAngular: NO];
  testEquals([sanitized objectAtIndex: 0], @" alert(1) ");

  categories = [NSArray arrayWithObjects: @"<img src=x onerror=alert(1)>", nil];
  sanitized = [categories stringsWithoutHTMLInjection: YES stripAngular: NO];
  testEquals([sanitized objectAtIndex: 0], @" ");

  categories = [NSArray arrayWithObjects: @"fb <foo@bar.com>", nil];
  sanitized = [categories stringsWithoutHTMLInjection: YES stripAngular: NO];
  testEquals([sanitized objectAtIndex: 0], @"fb <foo@bar.com>");
}

- (void) test_stringsWithoutHTMLInjectionKeepsNonStrings
{
  NSArray *categories, *sanitized;
  NSNumber *rank;

  rank = [NSNumber numberWithInt: 5];
  categories = [NSArray arrayWithObjects: @"<b>test-6158</b>", rank, nil];
  sanitized = [categories stringsWithoutHTMLInjection: YES stripAngular: NO];
  failIf([sanitized count] != 2);
  testEquals([sanitized objectAtIndex: 0], @" test-6158 ");
  testEquals([sanitized objectAtIndex: 1], rank);
}

- (void) test_stringsWithoutHTMLInjectionAfterJSONDecoding
{
  NSString *json;
  NSArray *expected;
  id parsed;
  NSArray *sanitized;

  json = @"{ \"SOGoContactsCategories\": [\"\\u003cscript\\u003ealert('test-6158')\\u003c/script\\u003e\", \"Ami\"] }";
  testWithMessage([[json stringWithoutHTMLInjection: NO stripAngular: NO] objectFromJSONString] != nil,
                  @"raw JSON payload must stay parsable after the pre-parse pass");
  parsed = [json objectFromJSONString];
  expected = [NSArray arrayWithObjects: @"<script>alert('test-6158')</script>", @"Ami", nil];
  testEquals([parsed objectForKey: @"SOGoContactsCategories"], expected);

  sanitized = [[parsed objectForKey: @"SOGoContactsCategories"] stringsWithoutHTMLInjection: YES stripAngular: NO];
  testEquals([sanitized objectAtIndex: 0], @" alert('test-6158') ");
  testEquals([sanitized objectAtIndex: 1], @"Ami");
}

@end
