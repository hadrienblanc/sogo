/* TestNGVCard+SOGo.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGCards/NGVCard.h>

#import <Contacts/NSDictionary+LDIF.h>
#import <Contacts/NGVCard+SOGo.h>

#import "SOGoTest.h"

@interface TestNGVCard_plus_SOGo : SOGoTest
@end

static BOOL
LoadContactsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Contacts"
                       markerClass: @"SOGoContactGCSFolder"];
}

@implementation TestNGVCard_plus_SOGo

- (NGVCard *) _cardWithSource: (NSString *) source
{
  NGVCard *card;

  testWithMessage (LoadContactsBundle (),
                   @"Contacts bundle could not be loaded");

  card = [NGVCard parseSingleFromSource: source];
  testWithMessage ([card isKindOfClass: [NGVCard class]],
                   @"vCard source could not be parsed");

  return card;
}

- (void) test_asLDIFRecordExportsAllPhonesOfSameType
{
  NGVCard *card;
  NSDictionary *record;

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:Doe;John;;;\r\n"
           @"FN:John Doe\r\n"
           @"TEL;TYPE=WORK:+1 514 111 2222\r\n"
           @"TEL;TYPE=WORK:+1 514 333 4444\r\n"
           @"TEL;TYPE=HOME:+1 450 555 6666\r\n"
           @"TEL;TYPE=CELL:+1 514 777 8888\r\n"
           @"TEL;TYPE=CELL:+1 514 999 0000\r\n"
           @"TEL;TYPE=FAX:+1 514 101 1010\r\n"
           @"TEL;TYPE=PAGER:+1 514 202 2020\r\n"
           @"END:VCARD\r\n"];

  record = [card asLDIFRecord];

  testEquals(([record objectForKey: @"telephonenumber"]),
             ([NSArray arrayWithObjects: @"+1 514 111 2222",
                                        @"+1 514 333 4444", nil]));
  testEquals([record objectForKey: @"homephone"],
             [NSArray arrayWithObject: @"+1 450 555 6666"]);
  testEquals(([record objectForKey: @"mobile"]),
             ([NSArray arrayWithObjects: @"+1 514 777 8888",
                                        @"+1 514 999 0000", nil]));
  testEquals([record objectForKey: @"facsimiletelephonenumber"],
             [NSArray arrayWithObject: @"+1 514 101 1010"]);
  testEquals([record objectForKey: @"pager"],
             [NSArray arrayWithObject: @"+1 514 202 2020"]);
}

- (void) test_asLDIFRecordExcludesFaxFromTypedPhones
{
  NGVCard *card;
  NSDictionary *record;

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:Doe;John;;;\r\n"
           @"FN:John Doe\r\n"
           @"TEL;TYPE=WORK:+1 514 111 2222\r\n"
           @"TEL;TYPE=WORK,FAX:+1 514 909 9090\r\n"
           @"TEL;TYPE=FAX:+1 514 101 1010\r\n"
           @"END:VCARD\r\n"];

  record = [card asLDIFRecord];

  testEquals([record objectForKey: @"telephonenumber"],
             [NSArray arrayWithObject: @"+1 514 111 2222"]);
  testEquals(([record objectForKey: @"facsimiletelephonenumber"]),
             ([NSArray arrayWithObjects: @"+1 514 909 9090",
                                        @"+1 514 101 1010", nil]));
}

- (void) test_asLDIFRecordSkipsEmptyPhonesAndKeepsEmptyKeys
{
  NGVCard *card;
  NSDictionary *record;

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:Doe;Jane;;;\r\n"
           @"FN:Jane Doe\r\n"
           @"TEL;TYPE=WORK:\r\n"
           @"TEL;TYPE=WORK:+1 514 444 5555\r\n"
           @"END:VCARD\r\n"];

  record = [card asLDIFRecord];

  testEquals([record objectForKey: @"telephonenumber"],
             [NSArray arrayWithObject: @"+1 514 444 5555"]);
  testEquals([record objectForKey: @"homephone"], @"");
  testEquals([record objectForKey: @"mobile"], @"");
  testEquals([record objectForKey: @"facsimiletelephonenumber"], @"");
  testEquals([record objectForKey: @"pager"], @"");
}

- (void) test_asLDIFRecordFallsBackOnVoicePhones
{
  NGVCard *card;
  NSDictionary *record;

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:Doe;Jim;;;\r\n"
           @"FN:Jim Doe\r\n"
           @"TEL;TYPE=VOICE:+1 514 666 7777\r\n"
           @"TEL;TYPE=VOICE:+1 514 888 9999\r\n"
           @"END:VCARD\r\n"];

  record = [card asLDIFRecord];

  testEquals(([record objectForKey: @"telephonenumber"]),
             ([NSArray arrayWithObjects: @"+1 514 666 7777",
                                        @"+1 514 888 9999", nil]));
}

- (void) test_ldifRecordAsStringRendersOneLinePerPhone
{
  NGVCard *card;
  NSString *ldifString;
  NSArray *lines;
  NSUInteger count, max, workLines, mobileLines;
  NSString *line;

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:Doe;John;;;\r\n"
           @"FN:John Doe\r\n"
           @"TEL;TYPE=WORK:+1 514 111 2222\r\n"
           @"TEL;TYPE=WORK:+1 514 333 4444\r\n"
           @"TEL;TYPE=CELL:+1 514 777 8888\r\n"
           @"TEL;TYPE=CELL:+1 514 999 0000\r\n"
           @"END:VCARD\r\n"];

  ldifString = [[card asLDIFRecord] ldifRecordAsString];
  testWithMessage ([ldifString rangeOfString: @"telephonenumber: +1 514 111 2222"
                                     options: NSCaseInsensitiveSearch].location
                     != NSNotFound,
                   @"first WORK number missing from LDIF export (bug 6143)");
  testWithMessage ([ldifString rangeOfString: @"telephonenumber: +1 514 333 4444"
                                     options: NSCaseInsensitiveSearch].location
                     != NSNotFound,
                   @"second WORK number missing from LDIF export (bug 6143)");
  testWithMessage ([ldifString rangeOfString: @"mobile: +1 514 999 0000"
                                     options: NSCaseInsensitiveSearch].location
                     != NSNotFound,
                   @"second CELL number missing from LDIF export (bug 6143)");

  lines = [ldifString componentsSeparatedByString: @"\n"];
  workLines = mobileLines = 0;
  max = [lines count];
  for (count = 0; count < max; count++)
    {
      line = [lines objectAtIndex: count];
      if ([line hasPrefix: @"telephonenumber: "])
        workLines++;
      if ([line hasPrefix: @"mobile: "])
        mobileLines++;
    }
  test (workLines == 2);
  test (mobileLines == 2);
}

- (void) test_asLDIFRecordExportsAllPhonesFromBug6106Card
{
  NGVCard *card;
  NSDictionary *record;

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"TEL;TYPE=HOME:+41 22 819 44 85\r\n"
           @"TEL;TYPE=WORK:+41 848 726 224\r\n"
           @"TEL;TYPE=WORK:+41 800 633 225\r\n"
           @"ORG:Sana24\r\n"
           @"CATEGORIES:Firmen / Hotlines,Alle,myContacts\r\n"
           @"END:VCARD\r\n"];

  record = [card asLDIFRecord];

  testEquals([record objectForKey: @"homephone"],
             [NSArray arrayWithObject: @"+41 22 819 44 85"]);
  testEquals(([record objectForKey: @"telephonenumber"]),
             ([NSArray arrayWithObjects: @"+41 848 726 224",
                                        @"+41 800 633 225", nil]));
}

- (void) test_updateFromLDIFRecordExpandsPhoneArrays
{
  NGVCard *card, *importedCard;
  NSDictionary *record;
  NSArray *tels;
  NSString *versitString;
  NSUInteger count, max;
  CardElement *tel;
  int workTels;

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:Doe;John;;;\r\n"
           @"FN:John Doe\r\n"
           @"TEL;TYPE=WORK:+1 514 111 2222\r\n"
           @"TEL;TYPE=WORK:+1 514 333 4444\r\n"
           @"EMAIL;TYPE=WORK:john.doe@example.org\r\n"
           @"END:VCARD\r\n"];

  record = [card asLDIFRecord];

  importedCard = [NGVCard cardWithUid: @"imported-6143"];
  [importedCard updateFromLDIFRecord: record];

  tels = [importedCard childrenWithTag: @"tel"];
  workTels = 0;
  max = [tels count];
  for (count = 0; count < max; count++)
    {
      tel = [tels objectAtIndex: count];
      if ([tel hasAttribute: @"type" havingValue: @"work"])
        workTels++;
    }
  test (workTels == 2);

  versitString = [importedCard versitString];
  testWithMessage ([versitString rangeOfString: @"+1 514 111 2222"].location
                     != NSNotFound,
                   @"first WORK number lost during LDIF round-trip");
  testWithMessage ([versitString rangeOfString: @"+1 514 333 4444"].location
                     != NSNotFound,
                   @"second WORK number lost during LDIF round-trip");
}

@end
