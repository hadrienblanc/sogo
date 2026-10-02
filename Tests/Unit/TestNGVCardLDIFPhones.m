#import <NGCards/NGCards.h>

#import "SOGoTest.h"

#import "NGVCard+SOGo.h"
#import "NSDictionary+LDIF.h"

@interface TestNGVCardLDIFPhones : SOGoTest
@end

@implementation TestNGVCardLDIFPhones

- (NGVCard *) _cardOfTicket6143
{
  NGVCard *card;

  card = [NGVCard parseSingleFromSource:
                     @"BEGIN:VCARD\n"
                     @"VERSION:3.0\n"
                     @"N:Doe;Jane;;;;\n"
                     @"FN:Jane Doe\n"
                     @"TEL;TYPE=WORK:+49 351 12345678\n"
                     @"TEL;TYPE=WORK:+49 170 55501234\n"
                     @"TEL;TYPE=HOME:+49 30 98765432\n"
                     @"END:VCARD\n"];
  test (card != nil);

  return card;
}

- (NGVCard *) _roundTrippedCardOfTicket6143
{
  NGVCard *card;

  card = [NGVCard cardWithUid: @"ticket-6143"];
  [card updateFromLDIFRecord: [[self _cardOfTicket6143] asLDIFRecord]];

  return card;
}

- (NSArray *) _ldifValuesForAttribute: (NSString *) attribute
                                 card: (NGVCard *) aCard
{
  NSMutableArray *values;
  NSArray *lines;
  NSUInteger count;

  values = [NSMutableArray array];
  lines = [[[aCard asLDIFRecord] ldifRecordAsString]
             componentsSeparatedByString: @"\n"];
  for (count = 0; count < [lines count]; count++)
    {
      if ([[lines objectAtIndex: count] hasPrefix: attribute])
        [values addObject: [[lines objectAtIndex: count]
                              substringFromIndex: [attribute length]]];
    }

  return values;
}

- (NSArray *) _telValuesOfCard: (NGVCard *) aCard
{
  NSMutableArray *values;
  NSArray *tels;
  NSUInteger count;

  values = [NSMutableArray array];
  tels = [aCard childrenWithTag: @"tel"];
  for (count = 0; count < [tels count]; count++)
    [values addObject: [[tels objectAtIndex: count]
                          flattenedValuesForKey: @""]];

  return values;
}

- (NSArray *) _versitTelValuesOfCard: (NGVCard *) aCard
{
  NSMutableArray *values;
  NSArray *lines;
  NSRange colon;
  NSUInteger count;
  NSString *line;

  values = [NSMutableArray array];
  lines = [[aCard versitString] componentsSeparatedByString: @"\r\n"];
  for (count = 0; count < [lines count]; count++)
    {
      line = [lines objectAtIndex: count];
      colon = [line rangeOfString: @":"];
      if ([line hasPrefix: @"TEL;"] && colon.location != NSNotFound)
        [values addObject: [line substringFromIndex: NSMaxRange (colon)]];
    }

  return values;
}

- (void) test_vCardVersitStringKeepsAllPhoneNumbers
{
  NSArray *expected;

  expected = [NSArray arrayWithObjects: @"+49 351 12345678", @"+49 170 55501234",
                        @"+49 30 98765432", nil];
  testEquals ([self _versitTelValuesOfCard: [self _cardOfTicket6143]], expected);
}

- (void) test_exportedRecordHoldsAllPhoneNumbersOfSameType
{
  NSArray *expectedWork;

  expectedWork = [NSArray arrayWithObjects: @"+49 351 12345678", @"+49 170 55501234", nil];
  testEquals ([[[self _cardOfTicket6143] asLDIFRecord] objectForKey: @"telephonenumber"], expectedWork);
  testEquals ([[[self _cardOfTicket6143] asLDIFRecord] objectForKey: @"homephone"],
              [NSArray arrayWithObject: @"+49 30 98765432"]);
}

- (void) test_exportedLDIFStringHoldsAllPhoneNumbersOfSameType
{
  NSArray *expectedWork;

  expectedWork = [NSArray arrayWithObjects: @"+49 351 12345678", @"+49 170 55501234", nil];
  testEquals ([self _ldifValuesForAttribute: @"telephonenumber: " card: [self _cardOfTicket6143]],
              expectedWork);
  testEquals ([self _ldifValuesForAttribute: @"homephone: " card: [self _cardOfTicket6143]],
              [NSArray arrayWithObject: @"+49 30 98765432"]);
}

- (void) test_ldifToVCardRoundTripKeepsAllPhoneNumbers
{
  NSArray *expected;

  expected = [NSArray arrayWithObjects: @"+49 351 12345678", @"+49 170 55501234",
                        @"+49 30 98765432", nil];
  testEquals ([self _telValuesOfCard: [self _roundTrippedCardOfTicket6143]], expected);
}

- (void) test_exportedVCardStringKeepsAllWorkPhoneNumbers
{
  NSArray *expected;

  expected = [NSArray arrayWithObjects: @"+49 351 12345678", @"+49 170 55501234",
                        @"+49 30 98765432", nil];
  testEquals ([self _versitTelValuesOfCard: [self _roundTrippedCardOfTicket6143]], expected);
}

- (void) test_exportedRecordHoldsSinglePhoneNumberAsArray
{
  NGVCard *card;

  card = [NGVCard parseSingleFromSource:
                     @"BEGIN:VCARD\n"
                     @"VERSION:3.0\n"
                     @"TEL;TYPE=WORK:+49 351 12345678\n"
                     @"END:VCARD\n"];
  testEquals ([[card asLDIFRecord] objectForKey: @"telephonenumber"],
              [NSArray arrayWithObject: @"+49 351 12345678"]);
  testEquals ([self _ldifValuesForAttribute: @"telephonenumber: " card: card],
              [NSArray arrayWithObject: @"+49 351 12345678"]);
}

- (void) test_exportedRecordWithoutPhonesHoldsEmptyValues
{
  NGVCard *card;

  card = [NGVCard parseSingleFromSource:
                     @"BEGIN:VCARD\n"
                     @"VERSION:3.0\n"
                     @"FN:Jane Doe\n"
                     @"END:VCARD\n"];
  testEquals ([[card asLDIFRecord] objectForKey: @"telephonenumber"], @"");
  testEquals ([[card asLDIFRecord] objectForKey: @"homephone"], @"");
}

- (void) test_exportedRecordExcludesFaxFromWorkPhoneNumbers
{
  NGVCard *card;

  card = [NGVCard parseSingleFromSource:
                     @"BEGIN:VCARD\n"
                     @"VERSION:3.0\n"
                     @"TEL;TYPE=WORK,FAX:+49 351 12345678\n"
                     @"TEL;TYPE=WORK:+49 170 55501234\n"
                     @"END:VCARD\n"];
  testEquals ([[card asLDIFRecord] objectForKey: @"telephonenumber"],
              [NSArray arrayWithObject: @"+49 170 55501234"]);
  testEquals ([[card asLDIFRecord] objectForKey: @"facsimiletelephonenumber"],
              [NSArray arrayWithObject: @"+49 351 12345678"]);
}

- (void) test_exportedRecordFallsBackToVoicePhoneNumber
{
  NGVCard *card;

  card = [NGVCard parseSingleFromSource:
                     @"BEGIN:VCARD\n"
                     @"VERSION:2.1\n"
                     @"N:Doe;Jane;;;;\n"
                     @"TEL;CELL:+49 170 55501234\n"
                     @"TEL;VOICE:+49 30 98765432\n"
                     @"END:VCARD\n"];
  testEquals ([[card asLDIFRecord] objectForKey: @"telephonenumber"],
              @"+49 30 98765432");
}

@end
