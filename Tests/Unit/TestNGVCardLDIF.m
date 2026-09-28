/* TestNGVCardLDIF.m - this file is part of SOGo
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

/* This file is encoded in utf-8. */

#import "SOGoTest.h"

#import <NGCards/NGCards.h>

#import "NGVCard+SOGo.h"
#import "NSDictionary+LDIF.h"

@interface TestNGVCardLDIF : SOGoTest
@end

@implementation TestNGVCardLDIF

- (NGVCard *) _parseCard: (NSString *) vcardString
{
  NGVCard *card;

  card = [NGVCard parseSingleFromSource: vcardString];
  testWithMessage (card != nil, @"the fixture vCard must parse");

  return card;
}

/* Bug #6106: exporting a contact holding several phone numbers of the
   same type dropped every number but the first one of each type. */
- (void) test_ldifExportKeepsAllPhoneNumbersOfSameType
{
  NSString *fixture, *ldif, *error;
  NGVCard *card;
  NSArray *lines, *workNumbers;
  NSUInteger count;

  fixture = @"BEGIN:VCARD\n"
            @"VERSION:3.0\n"
            @"TEL;TYPE=HOME:+41 22 819 44 85\n"
            @"TEL;TYPE=WORK:+41 848 726 224\n"
            @"TEL;TYPE=WORK:+41 800 633 225\n"
            @"ORG:Sana24\n"
            @"END:VCARD\n";

  card = [self _parseCard: fixture];
  ldif = [[card asLDIFRecord] ldifRecordAsString];

  workNumbers = [NSMutableArray array];
  lines = [ldif componentsSeparatedByString: @"\n"];
  for (count = 0; count < [lines count]; count++)
    {
      if ([[lines objectAtIndex: count] hasPrefix: @"telephonenumber: "])
        [(NSMutableArray *) workNumbers addObject:
           [[lines objectAtIndex: count] substringFromIndex: [@"telephonenumber: " length]]];
    }

  error = [NSString stringWithFormat: @"expected two work numbers in:\n%@", ldif];
  testWithMessage ([workNumbers count] == 2, error);
  error = [NSString stringWithFormat: @"first work number missing in:\n%@", ldif];
  testWithMessage ([workNumbers containsObject: @"+41 848 726 224"], error);
  error = [NSString stringWithFormat: @"second work number missing in:\n%@", ldif];
  testWithMessage ([workNumbers containsObject: @"+41 800 633 225"], error);
  error = [NSString stringWithFormat: @"home number missing in:\n%@", ldif];
  testWithMessage ([ldif rangeOfString: @"homephone: +41 22 819 44 85"].location != NSNotFound, error);
}

- (void) test_ldifRecordHoldsPhoneArrays
{
  NSString *fixture;
  NGVCard *card;
  NSDictionary *ldifRecord;
  NSString *error;

  fixture = @"BEGIN:VCARD\n"
            @"VERSION:3.0\n"
            @"TEL;TYPE=CELL:+41 79 111 22 33\n"
            @"TEL;TYPE=CELL:+41 79 444 55 66\n"
            @"TEL;TYPE=CELL:+41 79 777 88 99\n"
            @"END:VCARD\n";

  card = [self _parseCard: fixture];
  ldifRecord = [card asLDIFRecord];

  error = @"three cell numbers must be held as an array";
  testWithMessage ([[ldifRecord objectForKey: @"mobile"] isKindOfClass: [NSArray class]]
                   && [(NSArray *) [ldifRecord objectForKey: @"mobile"] count] == 3,
                   error);
}

- (void) test_ldifRoundTripKeepsAllPhoneNumbers
{
  NSString *fixture, *error;
  NGVCard *card, *roundTripped;
  NSArray *tels;
  NSUInteger count;
  NSMutableArray *values;

  fixture = @"BEGIN:VCARD\n"
            @"VERSION:3.0\n"
            @"TEL;TYPE=HOME:+41 22 819 44 85\n"
            @"TEL;TYPE=WORK:+41 848 726 224\n"
            @"TEL;TYPE=WORK:+41 800 633 225\n"
            @"END:VCARD\n";

  card = [self _parseCard: fixture];
  roundTripped = [NGVCard cardWithUid: @"roundtrip"];
  [roundTripped updateFromLDIFRecord: [card asLDIFRecord]];

  tels = [roundTripped childrenWithTag: @"tel"];
  values = [NSMutableArray array];
  for (count = 0; count < [tels count]; count++)
    [values addObject: [[tels objectAtIndex: count] flattenedValuesForKey: @""]];

  error = [NSString stringWithFormat: @"round trip must keep the three numbers, got: %@", values];
  testWithMessage ([values count] == 3
                   && [values containsObject: @"+41 22 819 44 85"]
                   && [values containsObject: @"+41 848 726 224"]
                   && [values containsObject: @"+41 800 633 225"],
                   error);
}

- (void) test_ldifExportWithSinglePhoneNumbers
{
  NSString *fixture, *ldif, *error;
  NGVCard *card;

  fixture = @"BEGIN:VCARD\n"
            @"VERSION:3.0\n"
            @"TEL;TYPE=WORK:+41 848 726 224\n"
            @"END:VCARD\n";

  card = [self _parseCard: fixture];
  ldif = [[card asLDIFRecord] ldifRecordAsString];

  error = [NSString stringWithFormat: @"single work number must be exported, got:\n%@", ldif];
  testWithMessage ([ldif rangeOfString: @"telephonenumber: +41 848 726 224"].location != NSNotFound,
                   error);
}

- (void) test_ldifExportWithoutPhones
{
  NSString *fixture, *error;
  NGVCard *card;
  NSDictionary *ldifRecord;

  fixture = @"BEGIN:VCARD\n"
            @"VERSION:3.0\n"
            @"ORG:Sana24\n"
            @"END:VCARD\n";

  card = [self _parseCard: fixture];
  ldifRecord = [card asLDIFRecord];

  error = @"record without phones must not crash and must hold empty values";
  testWithMessage ([[ldifRecord objectForKey: @"telephonenumber"] length] == 0
                   && [[ldifRecord objectForKey: @"homephone"] length] == 0,
                   error);
}

/* A work number flagged as fax as well must not become the work number */
- (void) test_ldifExportExcludesFaxFromWorkNumbers
{
  NSString *fixture, *ldif, *error;
  NGVCard *card;

  fixture = @"BEGIN:VCARD\n"
            @"VERSION:3.0\n"
            @"TEL;TYPE=WORK,FAX:+41 848 726 224\n"
            @"TEL;TYPE=WORK:+41 800 633 225\n"
            @"END:VCARD\n";

  NSArray *lines;
  NSUInteger count;
  BOOL faxHasCombined, workHasCombined, workHasPlain;

  card = [self _parseCard: fixture];
  ldif = [[card asLDIFRecord] ldifRecordAsString];

  faxHasCombined = workHasCombined = workHasPlain = NO;
  lines = [ldif componentsSeparatedByString: @"\n"];
  for (count = 0; count < [lines count]; count++)
    {
      NSString *line;

      line = [lines objectAtIndex: count];
      if ([line isEqualToString: @"facsimiletelephonenumber: +41 848 726 224"])
        faxHasCombined = YES;
      if ([line isEqualToString: @"telephonenumber: +41 848 726 224"])
        workHasCombined = YES;
      if ([line isEqualToString: @"telephonenumber: +41 800 633 225"])
        workHasPlain = YES;
    }

  error = [NSString stringWithFormat: @"the combined WORK/FAX number must be exported as fax only:\n%@", ldif];
  testWithMessage (faxHasCombined && !workHasCombined, error);
  error = [NSString stringWithFormat: @"the plain WORK number must still be exported:\n%@", ldif];
  testWithMessage (workHasPlain, error);
}

/* The legacy v2.1 VOICE fallback must survive the array-based record */
- (void) test_ldifExportVoiceFallback
{
  NSString *fixture, *ldif, *error;
  NGVCard *card;

  fixture = @"BEGIN:VCARD\n"
            @"VERSION:2.1\n"
            @"N:name;surname;;;;\n"
            @"TEL;VOICE;HOME:\n"
            @"TEL;VOICE;WORK:\n"
            @"TEL;PAGER:\n"
            @"TEL;FAX;WORK:\n"
            @"TEL;CELL:514 123 1234\n"
            @"TEL;VOICE:450 456 6789\n"
            @"END:VCARD\n";

  card = [self _parseCard: fixture];
  ldif = [[card asLDIFRecord] ldifRecordAsString];

  error = [NSString stringWithFormat: @"the voice number must fall back to the work attribute:\n%@", ldif];
  testWithMessage ([ldif rangeOfString: @"telephonenumber: 450 456 6789"].location != NSNotFound,
                   error);
}

@end
