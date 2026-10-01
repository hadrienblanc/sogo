/* TestNSString+Imap4LabelName.m - this file is part of SOGo
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

/* This file is encoded in utf-8. */

#import <Foundation/NSCharacterSet.h>

#import <SOGo/NSString+Utilities.h>
#import "SOGoTest.h"

@interface TestNSString_plus_Imap4LabelName : SOGoTest
@end

@implementation TestNSString_plus_Imap4LabelName

- (void) test_atomSafeLabelNamesAreKeptAsIs
{
  testEquals([@"testlabel" stringByEncodingImap4LabelName], @"testlabel");
  testEquals([@"$Label1" stringByEncodingImap4LabelName], @"$Label1");
  testEquals([@"R&D" stringByEncodingImap4LabelName], @"R&D");
  testEquals([@"a-b_c.d" stringByEncodingImap4LabelName], @"a-b_c.d");
}

- (void) test_nonAtomLabelNamesAreEncoded
{
  testEquals([@"тест" stringByEncodingImap4LabelName],
             @"_u7_0442043504410442");
  testEquals([@"café" stringByEncodingImap4LabelName],
             @"_u7_00630061006600e9");
  test([[@"hello world" stringByEncodingImap4LabelName]
         hasPrefix: @"_u7_"]);
  test([[@"100% ready" stringByEncodingImap4LabelName]
         hasPrefix: @"_u7_"]);
  test([[@"(important)" stringByEncodingImap4LabelName]
         hasPrefix: @"_u7_"]);
  testEquals([@"👍" stringByEncodingImap4LabelName], @"_u7_d83ddc4d");
}

- (void) test_encodedLabelNamesDecodeToOriginalNames
{
  NSArray *names;
  NSString *name, *keyword;
  NSEnumerator *e;

  names = [NSArray arrayWithObjects: @"тест", @"café", @"hello world",
                     @"100% тест", @"日本語", @"👍", @"важно (тест)", nil];
  e = [names objectEnumerator];
  while ((name = [e nextObject]))
    {
      keyword = [name stringByEncodingImap4LabelName];
      testEquals([keyword stringByDecodingImap4LabelName], name);
    }
}

- (void) test_uppercaseHexIsDecoded
{
  testEquals([@"_u7_00630061006600E9" stringByDecodingImap4LabelName],
             @"café");
}

- (void) test_imapKeywordsAreDecodedOnlyWithValidMarker
{
  testEquals([@"testlabel" stringByDecodingImap4LabelName], @"testlabel");
  testEquals([@"$Label1" stringByDecodingImap4LabelName], @"$Label1");
  testEquals([@"&BCYENQRBBEw-" stringByDecodingImap4LabelName],
             @"&BCYENQRBBEw-");
  testEquals([@"_u7_" stringByDecodingImap4LabelName], @"_u7_");
  testEquals([@"_u7_xyz" stringByDecodingImap4LabelName], @"_u7_xyz");
  testEquals([@"_u7_123" stringByDecodingImap4LabelName], @"_u7_123");
  testEquals([@"_u7_12345" stringByDecodingImap4LabelName], @"_u7_12345");
  testEquals([@"_u7_0442_0435" stringByDecodingImap4LabelName],
             @"_u7_0442_0435");
}

- (void) test_encodedKeywordsOnlyContainImapAtomCharacters
{
  NSCharacterSet *atomUnsafe;
  NSArray *names;
  NSString *name, *keyword;
  NSEnumerator *e;
  NSUInteger i;

  atomUnsafe = [NSCharacterSet characterSetWithCharactersInString:
                                 @"(){}%*\"\\] "];
  names = [NSArray arrayWithObjects: @"тест", @"hello world",
                     @"100% готово", nil];
  e = [names objectEnumerator];
  while ((name = [e nextObject]))
    {
      keyword = [name stringByEncodingImap4LabelName];
      for (i = 0; i < [keyword length]; i++)
        failIf([atomUnsafe characterIsMember: [keyword characterAtIndex: i]]);
    }
}

@end
