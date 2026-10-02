/* TestNGVList.m - this file is part of SOGo
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
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <NGCards/CardVersitRenderer.h>
#import <NGCards/NGVCardReference.h>
#import <NGCards/NGVList.h>

#import "SOGoTest.h"

@interface TestNGVList : SOGoTest
@end

@implementation TestNGVList

- (void) test_cardReferenceForReference
{
  NGVList *list;
  NGVCardReference *ref1, *ref2, *found;

  list = [[[NGVList alloc] initWithUid: @"list-uid"] autorelease];

  ref1 = [NGVCardReference elementWithTag: @"card"];
  [ref1 setFn: @"John Doe"];
  [ref1 setEmail: @"john.private@example.com"];
  [ref1 setReference: @"john.vcf"];
  [list addCardReference: ref1];

  ref2 = [NGVCardReference elementWithTag: @"card"];
  [ref2 setFn: @"Jane Doe"];
  [ref2 setEmail: @"jane@example.com"];
  [ref2 setReference: @"jane.vcf"];
  [list addCardReference: ref2];

  test([[list cardReferences] count] == 2);

  found = [list cardReferenceForReference: @"john.vcf"];
  test(found == ref1);
  testEquals([found email], @"john.private@example.com");
  testEquals([found fn], @"John Doe");

  found = [list cardReferenceForReference: @"jane.vcf"];
  test(found == ref2);

  test([list cardReferenceForReference: @"nobody.vcf"] == nil);
}

- (void) test_selectedEmailRoundTrip
{
  CardVersitRenderer *renderer;
  NGVList *list;
  NGVCardReference *ref;
  NSString *versit, *rendered;

  versit = @"BEGIN:VLIST\r\n"
           @"UID:list-uid\r\n"
           @"VERSION:1.0\r\n"
           @"CARD;FN=John Doe;EMAIL=board@example.com:john.vcf\r\n"
           @"FN:Test List\r\n"
           @"END:VLIST";

  list = [NGVList parseSingleFromSource: versit];
  test(list != nil);

  ref = [list cardReferenceForReference: @"john.vcf"];
  test(ref != nil);
  testEquals([ref reference], @"john.vcf");
  testEquals([ref fn], @"John Doe");
  testEquals([ref email], @"board@example.com");

  renderer = [[[CardVersitRenderer alloc] init] autorelease];

  rendered = [renderer render: list];
  list = [NGVList parseSingleFromSource: rendered];
  ref = [list cardReferenceForReference: @"john.vcf"];
  test(ref != nil);
  testEquals([ref email], @"board@example.com");

  [ref setEmail: @"john.private@example.com"];
  rendered = [renderer render: list];
  list = [NGVList parseSingleFromSource: rendered];
  ref = [list cardReferenceForReference: @"john.vcf"];
  test(ref != nil);
  testEquals([ref email], @"john.private@example.com");
}

- (void) test_deleteCardReferenceKeepsOthers
{
  NGVList *list;
  NGVCardReference *ref1, *ref2;

  list = [[[NGVList alloc] initWithUid: @"list-uid"] autorelease];

  ref1 = [NGVCardReference elementWithTag: @"card"];
  [ref1 setEmail: @"john.private@example.com"];
  [ref1 setReference: @"john.vcf"];
  [list addCardReference: ref1];

  ref2 = [NGVCardReference elementWithTag: @"card"];
  [ref2 setEmail: @"jane@example.com"];
  [ref2 setReference: @"jane.vcf"];
  [list addCardReference: ref2];

  [list deleteCardReference: ref1];

  test([[list cardReferences] count] == 1);
  test([list cardReferenceForReference: @"john.vcf"] == nil);
  testEquals([[list cardReferenceForReference: @"jane.vcf"] email],
             @"jane@example.com");
}

@end
