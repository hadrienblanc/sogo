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

- (void) test_flattenedCustomFieldsReadsThunderbirdXTags
{
  NGVCard *card;
  NSDictionary *customFields;

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:;AAAAAAA;;;\r\n"
           @"FN:AAAAAAA\r\n"
           @"X-CUSTOM1;VALUE=TEXT:tb custom value\r\n"
           @"X-CUSTOM4:tb fourth\r\n"
           @"END:VCARD\r\n"];

  customFields = [card flattenedCustomFields];

  test ([customFields count] == 2);
  testEquals([customFields objectForKey: @"1"], @"tb custom value");
  testEquals([customFields objectForKey: @"4"], @"tb fourth");
}

- (void) test_flattenedCustomFieldsReadsLegacyCustomTags
{
  NGVCard *card;
  NSDictionary *customFields;

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:;AAAAAAA;;;\r\n"
           @"FN:AAAAAAA\r\n"
           @"CUSTOM1:legacy one\r\n"
           @"CUSTOM3:legacy three\r\n"
           @"END:VCARD\r\n"];

  customFields = [card flattenedCustomFields];

  test ([customFields count] == 2);
  testEquals([customFields objectForKey: @"1"], @"legacy one");
  testEquals([customFields objectForKey: @"3"], @"legacy three");
}

- (void) test_flattenedCustomFieldsPrefersXCustomTags
{
  NGVCard *card;
  NSDictionary *customFields;

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:;AAAAAAA;;;\r\n"
           @"FN:AAAAAAA\r\n"
           @"CUSTOM1:legacy one\r\n"
           @"X-CUSTOM1:canonical one\r\n"
           @"END:VCARD\r\n"];

  customFields = [card flattenedCustomFields];

  test ([customFields count] == 1);
  testEquals([customFields objectForKey: @"1"], @"canonical one");
}

- (void) test_setCustomFieldsRendersXTags
{
  NGVCard *card;
  NSString *versitString;

  card = [NGVCard cardWithUid: @"5980-render"];
  [card setFn: @"John Doe"];
  [card setCustomFields: [NSDictionary dictionaryWithObjectsAndKeys:
                                        @"first", @"1",
                                        @"fourth", @"4",
                                        nil]];

  versitString = [card versitString];

  test ([[card childrenWithTag: @"x-custom1"] count] == 1);
  test ([[card childrenWithTag: @"custom1"] count] == 0);
  testWithMessage ([versitString rangeOfString: @"X-CUSTOM1:first\r\n"].location
                     != NSNotFound,
                   @"custom field 1 not rendered as X-CUSTOM1 (bug 5980)");
  testWithMessage ([versitString rangeOfString: @"X-CUSTOM4:fourth\r\n"].location
                     != NSNotFound,
                   @"custom field 4 not rendered as X-CUSTOM4 (bug 5980)");
  testWithMessage ([versitString rangeOfString: @"\r\nCUSTOM"].location
                     == NSNotFound,
                   @"custom field rendered without the X- prefix (bug 5980)");
}

- (void) test_setCustomFieldsReplacesLegacyCustomTags
{
  NGVCard *card;

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:;AAAAAAA;;;\r\n"
           @"FN:AAAAAAA\r\n"
           @"CUSTOM1:legacy one\r\n"
           @"X-CUSTOM1:canonical one\r\n"
           @"CUSTOM2:legacy two\r\n"
           @"END:VCARD\r\n"];

  [card setCustomFields: [NSDictionary dictionaryWithObject: @"new one"
                                                     forKey: @"1"]];

  testEquals([[card flattenedCustomFields] objectForKey: @"1"], @"new one");
  test ([[card childrenWithTag: @"custom1"] count] == 0);
  test ([[card childrenWithTag: @"custom2"] count] == 0);
  test ([[card childrenWithTag: @"x-custom2"] count] == 0);
  testWithMessage ([[card versitString] rangeOfString: @"\r\nCUSTOM"].location
                     == NSNotFound,
                   @"legacy CUSTOM tag survived an editor save (bug 5980)");
}

- (void) test_setCustomFieldsRemovesAllCustomFieldsWhenDictEmpty
{
  NGVCard *card;

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:;AAAAAAA;;;\r\n"
           @"FN:AAAAAAA\r\n"
           @"CUSTOM1:legacy one\r\n"
           @"X-CUSTOM2:canonical two\r\n"
           @"END:VCARD\r\n"];

  [card setCustomFields: [NSDictionary dictionary]];

  test ([[card childrenWithTag: @"custom1"] count] == 0);
  test ([[card childrenWithTag: @"x-custom2"] count] == 0);
  test ([[card flattenedCustomFields] count] == 0);
}

- (void) test_setCustomFieldsIgnoresEmptyValues
{
  NGVCard *card;

  card = [NGVCard cardWithUid: @"5980-empty"];
  [card setFn: @"John Doe"];
  [card setCustomFields: [NSDictionary dictionaryWithObject: @"" forKey: @"1"]];

  test ([[card childrenWithTag: @"x-custom1"] count] == 0);
  test ([[card flattenedCustomFields] count] == 0);
}

- (void) test_vCardStringWithMandatoryPropertiesFixesOrgOnlyCard
{
  NSString *source, *result;

  source = @"BEGIN:VCARD\r\n"
           @"UID:42-6624FD00-1-7C69540.vcf\r\n"
           @"VERSION:3.0\r\n"
           @"CLASS:PUBLIC\r\n"
           @"PROFILE:VCARD\r\n"
           @"ORG:STARS\r\n"
           @"EMAIL:valentine@stars.gov\r\n"
           @"END:VCARD\r\n";

  result = [NGVCard vCardStringWithMandatoryProperties: source];

  testEquals(result,
             @"BEGIN:VCARD\r\n"
             @"UID:42-6624FD00-1-7C69540.vcf\r\n"
             @"VERSION:3.0\r\n"
             @"CLASS:PUBLIC\r\n"
             @"PROFILE:VCARD\r\n"
             @"ORG:STARS\r\n"
             @"EMAIL:valentine@stars.gov\r\n"
             @"FN:STARS\r\n"
             @"N:;;;;\r\n"
             @"END:VCARD\r\n");
}

- (void) test_vCardStringWithMandatoryPropertiesDerivesFnFromEmailOnlyCard
{
  NSString *source, *result;

  source = @"BEGIN:VCARD\n"
           @"UID:test-5958-mail\n"
           @"VERSION:3.0\n"
           @"EMAIL:valentine@stars.gov\n"
           @"END:VCARD\n";

  result = [NGVCard vCardStringWithMandatoryProperties: source];

  testEquals(result,
             @"BEGIN:VCARD\n"
             @"UID:test-5958-mail\n"
             @"VERSION:3.0\n"
             @"EMAIL:valentine@stars.gov\n"
             @"FN:valentine@stars.gov\n"
             @"N:;;;;\n"
             @"END:VCARD\n");
}

- (void) test_vCardStringWithMandatoryPropertiesDerivesFnFromN
{
  NSString *source, *result;

  source = @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:Last;First;;;\r\n"
           @"END:VCARD\r\n";

  result = [NGVCard vCardStringWithMandatoryProperties: source];

  testEquals(result,
             @"BEGIN:VCARD\r\n"
             @"VERSION:3.0\r\n"
             @"N:Last;First;;;\r\n"
             @"FN:First Last\r\n"
             @"END:VCARD\r\n");
}

- (void) test_vCardStringWithMandatoryPropertiesOnlyAddsMissingN
{
  NSString *source, *result;

  source = @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"FN:John Doe\r\n"
           @"ORG:acme\r\n"
           @"END:VCARD\r\n";

  result = [NGVCard vCardStringWithMandatoryProperties: source];

  testEquals(result,
             @"BEGIN:VCARD\r\n"
             @"VERSION:3.0\r\n"
             @"FN:John Doe\r\n"
             @"ORG:acme\r\n"
             @"N:;;;;\r\n"
             @"END:VCARD\r\n");
}

- (void) test_vCardStringWithMandatoryPropertiesLeavesCompleteCardUntouched
{
  NSString *source, *result;

  source = @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:Last;First;;;\r\n"
           @"FN:First Last\r\n"
           @"EMAIL:first.last@x.y\r\n"
           @"END:VCARD\r\n";

  result = [NGVCard vCardStringWithMandatoryProperties: source];

  testEquals(result, source);
}

- (void) test_vCardStringWithMandatoryPropertiesLeavesLowercasePropertiesUntouched
{
  NSString *source, *result;

  source = @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"n:Last;First;;;\r\n"
           @"fn:First Last\r\n"
           @"END:VCARD\r\n";

  result = [NGVCard vCardStringWithMandatoryProperties: source];

  testEquals(result, source);
}

- (void) test_vCardStringWithMandatoryPropertiesLeavesParameterizedNTouched
{
  NSString *source, *result;

  source = @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N;LANGUAGE=fr:Dernier;Premier;;;\r\n"
           @"FN:Premier Dernier\r\n"
           @"END:VCARD\r\n";

  result = [NGVCard vCardStringWithMandatoryProperties: source];

  testEquals(result, source);
}

- (void) test_vCardStringWithMandatoryPropertiesLeavesNonVCardDataUntouched
{
  testEquals([NGVCard vCardStringWithMandatoryProperties: @"REAKTJRIEKL"],
             @"REAKTJRIEKL");
  testEquals([NGVCard vCardStringWithMandatoryProperties: @""], @"");
  testEquals([NGVCard vCardStringWithMandatoryProperties: nil], nil);
}

- (void) test_vCardStringWithMandatoryPropertiesEscapesDerivedFn
{
  NSString *source, *result;

  source = @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"ORG:acme\\, inc\r\n"
           @"END:VCARD\r\n";

  result = [NGVCard vCardStringWithMandatoryProperties: source];

  testWithMessage ([result rangeOfString: @"FN:acme\\, inc\r\n"].location
                     != NSNotFound,
                   @"derived FN not escaped (bug 5958)");
}

- (void) test_fullNameFallsBackOnPreferredEmail
{
  NGVCard *card;

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\nVERSION:3.0\r\nORG:acme\r\n"
           @"EMAIL:valentine@stars.gov\r\nEND:VCARD\r\n"];
  testEquals([card fullName], @"acme");

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\nVERSION:3.0\r\n"
           @"EMAIL;TYPE=WORK:jane@stars.gov\r\n"
           @"EMAIL:valentine@stars.gov\r\nEND:VCARD\r\n"];
  testEquals([card fullName], @"jane@stars.gov");

  card = [self _cardWithSource:
           @"BEGIN:VCARD\r\nVERSION:3.0\r\nEND:VCARD\r\n"];
  test([[card fullName] length] == 0);
}

@end
