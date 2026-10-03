#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <NGMime/NGMimeHeaderFieldGenerator.h>

#import <SOGo/SOGoObject.h>
#import <Mailer/SOGoDraftObject.h>

#import "SOGoTest.h"

#define DRAFT_CLASS_NAME @"SOGoDraftObject"

@interface SOGoDraftObject (IDNFromTests)
- (NSString *) _idnFrom: (NSString *) theFrom;
- (NSArray *) _idnFromInArray: (NSArray *) theFroms;
@end

@interface TestSOGoDraftObjectIDNFrom : SOGoTest
{
  SOGoDraftObject *draft;
}

@end

@implementation TestSOGoDraftObjectIDNFrom

static Class
LoadDraftClass ()
{
  static Class draftClass = Nil;

  if (!draftClass)
    {
      if (![SOGoTest loadSOGoBundle: @"Contacts"
                          markerClass: DRAFT_CLASS_NAME])
        [SOGoTest loadSOGoBundle: @"Mailer"
                      markerClass: DRAFT_CLASS_NAME];
      draftClass = NSClassFromString (DRAFT_CLASS_NAME);
    }

  return draftClass;
}

- (void) setUp
{
  Class draftClass;

  draftClass = LoadDraftClass ();
  testWithMessage (draftClass != Nil,
                   @"SOGoDraftObject class unavailable (Mailer.SOGo bundle missing)");
  if (!draftClass)
    return;

  draft = [[draftClass alloc] initWithName: @"idnFromDraft6233"
                                 inContainer: nil];
}

- (void) tearDown
{
  [draft release];
  [super tearDown];
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

- (NSString *) _generatedHeaderFor: (NSString *) theFrom
{
  NGMimeAddressHeaderFieldGenerator *generator;
  NSString *transformed;

  generator = [NGMimeAddressHeaderFieldGenerator headerFieldGenerator];
  transformed = [draft _idnFrom: theFrom];

  return [[[NSString alloc] initWithData:
              [generator generateDataForHeaderFieldNamed: @"from"
                                                    value: transformed]
                              encoding: NSASCIIStringEncoding] autorelease];
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
