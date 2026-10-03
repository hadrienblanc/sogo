#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import "SOGoDraftObjectTestCase.h"

@interface SOGoDraftObject (IDNFromTests)
- (NSString *) _idnFrom: (NSString *) theFrom;
- (NSArray *) _idnFromInArray: (NSArray *) theFroms;
@end

@interface TestSOGoDraftObjectIDNFrom : SOGoDraftObjectTestCase

@end

@implementation TestSOGoDraftObjectIDNFrom

- (NSString *) draftName
{
  return @"idnFromDraft6233";
}

- (NSString *) _generatedHeaderFor: (NSString *) theFrom
{
  return [self generatedHeaderFor: [draft _idnFrom: theFrom]];
}

- (void) test_barePunycodeFromGetsIDNDisplayName
{
  testEquals([draft _idnFrom: @"test@xn--exmple-4ya.org"],
             @"test@exümple.org <test@xn--exmple-4ya.org>");
  testEquals([draft _idnFrom: @"<test@xn--exmple-4ya.org>"],
             @"test@exümple.org <test@xn--exmple-4ya.org>");
  testEquals([draft _idnFrom: @" <test@xn--exmple-4ya.org> "],
             @"test@exümple.org <test@xn--exmple-4ya.org>");
  testEquals([draft _idnFrom: @"<test@xn--bcher-kva.example>"],
             @"test@bücher.example <test@xn--bcher-kva.example>");
}

- (void) test_fromWithDisplayNameUntouched
{
  testEquals([draft _idnFrom: @"Dude <test@xn--exmple-4ya.org>"],
             @"Dude <test@xn--exmple-4ya.org>");
  testEquals([draft _idnFrom: @"\"Doe, John\" <test@xn--exmple-4ya.org>"],
             @"\"Doe, John\" <test@xn--exmple-4ya.org>");
  testEquals([draft _idnFrom: @"=?utf-8?q?Doe=2C_John?= <test@xn--exmple-4ya.org>"],
             @"=?utf-8?q?Doe=2C_John?= <test@xn--exmple-4ya.org>");
}

- (void) test_asciiAndInvalidFromUntouched
{
  testEquals([draft _idnFrom: @"test@example.org"],
             @"test@example.org");
  testEquals([draft _idnFrom: @"<test@example.org>"],
             @"<test@example.org>");
  testEquals([draft _idnFrom: @"Dude <test@example.org>"],
             @"Dude <test@example.org>");
  testEquals([draft _idnFrom: @"Dude"],
             @"Dude");
  testEquals([draft _idnFrom: @"<>"],
             @"<>");
  testEquals([draft _idnFrom: @""],
             @"");
}

- (void) test_array
{
  NSArray *input, *expected;

  input = [NSArray arrayWithObjects:
                     @"<test@xn--exmple-4ya.org>",
                     @"Dude <test@example.org>",
                     nil];
  expected = [NSArray arrayWithObjects:
                        @"test@exümple.org <test@xn--exmple-4ya.org>",
                        @"Dude <test@example.org>",
                        nil];

  testEquals([draft _idnFromInArray: [NSArray array]], [NSArray array]);
  testEquals([draft _idnFromInArray: input], expected);
}

- (void) test_generatedHeaderCarriesIDNFormAsEncodedWord
{
  testEquals([self _generatedHeaderFor: @"<test@xn--exmple-4ya.org>"],
             @"=?utf-8?q?test=40ex=C3=BCmple=2Eorg?= <test@xn--exmple-4ya.org>");
  testEquals([self _generatedHeaderFor: @"test@xn--bcher-kva.example"],
             @"=?utf-8?q?test=40b=C3=BCcher=2Eexample?= <test@xn--bcher-kva.example>");
  testEquals([self _generatedHeaderFor: @"<test@example.org>"],
             @"test@example.org");
}

@end
