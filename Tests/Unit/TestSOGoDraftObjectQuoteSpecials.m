#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import "SOGoDraftObjectTestCase.h"

@interface SOGoDraftObject (QuoteSpecialsTests)
- (NSString *) _quoteSpecials: (NSString *) address;
- (NSArray *) _quoteSpecialsInArray: (NSArray *) addresses;
@end

@interface TestSOGoDraftObjectQuoteSpecials : SOGoDraftObjectTestCase

@end

@implementation TestSOGoDraftObjectQuoteSpecials

- (NSString *) draftName
{
  return @"quoteSpecialsDraft6227";
}

- (NSString *) _generatedHeaderFor: (NSString *) address
{
  return [self generatedHeaderFor: [draft _quoteSpecials: address]];
}

- (void) test_commaAndBracketsInDisplayName
{
  testEquals ([draft _quoteSpecials: @"Max, Muster [ABC] <Max.Muster@ab-cd.df>"],
              @"\"Max, Muster [ABC]\" <Max.Muster@ab-cd.df>");
  testEquals ([draft _quoteSpecials: @"Lastname, Firstname (INFO)[MoreINFO] <user@example.com>"],
              @"\"Lastname, Firstname (INFO)[MoreINFO]\" <user@example.com>");
  testEquals ([draft _quoteSpecials: @"Muster[ABC] <Max.Muster@ab-cd.df>"],
              @"\"Muster[ABC]\" <Max.Muster@ab-cd.df>");
  testEquals ([draft _quoteSpecials: @"Muster[ABC]<Max.Muster@ab-cd.df>"],
              @"\"Muster[ABC]\" <Max.Muster@ab-cd.df>");
}

- (void) test_simpleAddressesUntouched
{
  testEquals ([draft _quoteSpecials: @"wolfgang@test.com"],
              @"wolfgang@test.com");
  testEquals ([draft _quoteSpecials: @"<wolfgang@test.com>"],
              @"<wolfgang@test.com>");
  testEquals ([draft _quoteSpecials: @"Wolfgang Sourdeau <wolfgang@test.com>"],
              @"Wolfgang Sourdeau <wolfgang@test.com>");
  testEquals ([draft _quoteSpecials: @"Muster <Max.Muster@ab-cd.df>"],
              @"Muster <Max.Muster@ab-cd.df>");
}

- (void) test_alreadyQuotedDisplayNameUntouched
{
  testEquals ([draft _quoteSpecials: @"\"Muster, Max [ABC]\" <Max.Muster@ab-cd.df>"],
              @"\"Muster, Max [ABC]\" <Max.Muster@ab-cd.df>");
  testEquals ([draft _quoteSpecials: @"\"Doe, John\" <john@doe.com>"],
              @"\"Doe, John\" <john@doe.com>");
  testEquals ([draft _quoteSpecials: @"\"weird <name>\" <a@b.com>"],
              @"\"weird <name>\" <a@b.com>");
}

- (void) test_encodedWordDisplayNameUntouched
{
  testEquals ([draft _quoteSpecials: @"=?utf-8?q?Max=2C_Muster_=5BABC=5D?= <Max.Muster@ab-cd.df>"],
              @"=?utf-8?q?Max=2C_Muster_=5BABC=5D?= <Max.Muster@ab-cd.df>");
  testEquals ([draft _quoteSpecials: @"=?utf-8?q?Max=2C_Muster?= Max <Max.Muster@ab-cd.df>"],
              @"=?utf-8?q?Max=2C_Muster?= Max <Max.Muster@ab-cd.df>");
}

- (void) test_specialCharactersAreQuotedAndEscaped
{
  testEquals ([draft _quoteSpecials: @"foo (bar) <foo@zot.com>"],
              @"\"foo (bar)\" <foo@zot.com>");
  testEquals ([draft _quoteSpecials: @"bar, foo <foo@zot.com>"],
              @"\"bar, foo\" <foo@zot.com>");
  testEquals ([draft _quoteSpecials: @"foo;bar <foo@zot.com>"],
              @"\"foo;bar\" <foo@zot.com>");
  testEquals ([draft _quoteSpecials: @"foo:bar <foo@zot.com>"],
              @"\"foo:bar\" <foo@zot.com>");
  testEquals ([draft _quoteSpecials: @"foo@bar <foo@zot.com>"],
              @"\"foo@bar\" <foo@zot.com>");
  testEquals ([draft _quoteSpecials: @"foo.bar <foo@zot.com>"],
              @"\"foo.bar\" <foo@zot.com>");
  testEquals ([draft _quoteSpecials: @"foo[bar] <foo@zot.com>"],
              @"\"foo[bar]\" <foo@zot.com>");
  testEquals ([draft _quoteSpecials: @"Max \"The Boss\" Muster <Max.Muster@ab-cd.df>"],
              @"\"Max \\\"The Boss\\\" Muster\" <Max.Muster@ab-cd.df>");
  testEquals ([draft _quoteSpecials: @"back\\slash <foo@zot.com>"],
              @"\"back\\\\slash\" <foo@zot.com>");
}

- (void) test_addressesWithoutEmailPart
{
  testEquals ([draft _quoteSpecials: @"Muster, Max"],
              @"\"Muster, Max\"");
  testEquals ([draft _quoteSpecials: @"Muster Max"],
              @"Muster Max");
  testEquals ([draft _quoteSpecials: @"foo.bar"],
              @"\"foo.bar\"");
}

- (void) test_whitespaceIsTrimmedAroundDisplayName
{
  testEquals ([draft _quoteSpecials: @"  Muster, Max [ABC]  <a@b.com>"],
              @"\"Muster, Max [ABC]\" <a@b.com>");
  testEquals ([draft _quoteSpecials: @"   Wolfgang Sourdeau    <wolfgang@test.com>"],
              @"Wolfgang Sourdeau <wolfgang@test.com>");
}

- (void) test_emptyInput
{
  testEquals ([draft _quoteSpecials: @""], @"");
  testEquals ([draft _quoteSpecials: nil], nil);
  testEquals ([draft _quoteSpecials: @"   "], @"   ");
}

- (void) test_array
{
  NSArray *input, *expected;

  input = [NSArray arrayWithObjects: @"wolfgang@test.com",
                               @"Max, Muster [ABC] <Max.Muster@ab-cd.df>",
                               @"\"Doe, John\" <john@doe.com>",
                               nil];
  expected = [NSArray arrayWithObjects: @"wolfgang@test.com",
                                 @"\"Max, Muster [ABC]\" <Max.Muster@ab-cd.df>",
                                 @"\"Doe, John\" <john@doe.com>",
                                 nil];

  testEquals ([draft _quoteSpecialsInArray: [NSArray array]],
              [NSArray array]);
  testEquals ([draft _quoteSpecialsInArray: input], expected);
}

- (void) test_generatedHeadersKeepSingleAddress
{
  testEquals ([self _generatedHeaderFor: @"Max, Muster [ABC] <Max.Muster@ab-cd.df>"],
              @"\"Max, Muster [ABC]\" <Max.Muster@ab-cd.df>");
  testEquals ([self _generatedHeaderFor: @"\"Max, Muster [ABC]\" <Max.Muster@ab-cd.df>"],
              @"\"Max, Muster [ABC]\" <Max.Muster@ab-cd.df>");
  testEquals ([self _generatedHeaderFor: @"=?utf-8?q?Max=2C_Muster_=5BABC=5D?= <Max.Muster@ab-cd.df>"],
              @"=?utf-8?q?Max=2C_Muster_=5BABC=5D?= <Max.Muster@ab-cd.df>");
  testEquals ([self _generatedHeaderFor: @"wolfgang@test.com"],
              @"wolfgang@test.com");
  testEquals ([self _generatedHeaderFor: @"Wolfgang Sourdeau <wolfgang@test.com>"],
              @"Wolfgang Sourdeau <wolfgang@test.com>");
}

@end
