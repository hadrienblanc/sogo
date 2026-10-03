#import "SOGoTest.h"

#import "Mailer/NSString+Mail.h"

static NSString *
MessageIDShape(NSString *mailOrDomain)
{
  NSString *messageID = [NSString generateMessageID: mailOrDomain];

  return [@"<UUID" stringByAppendingString: [messageID substringFromIndex: 37]];
}

@interface TestNSString_plus_Mail : SOGoTest
@end

@implementation TestNSString_plus_Mail

- (void) test_generateMessageID_fromAddressOrDomain
{
  testEquals(MessageIDShape(@"user@example.org"), @"<UUID@example.org>");
  testEquals(MessageIDShape(@"Example.ORG"), @"<UUID@example.org>");
}

- (void) test_generateMessageID_fromSenderWithDisplayName
{
  testEquals(MessageIDShape(@"Doe, John <user@example.org>"), @"<UUID@example.org>");
  testEquals(MessageIDShape(@"Doe, John <user@example.org> (work)"), @"<UUID@example.org>");
  testEquals(MessageIDShape(@"user@example.org>"), @"<UUID@example.org>");
}

- (void) test_generateMessageID_rejectsInjectedDomains
{
  testEquals(MessageIDShape(@"user@example.org\r\nBcc: victim"),
             @"<UUID@example.org>");
  testEquals(MessageIDShape(@"user@example.org Bcc: victim"),
             @"<UUID@example.org>");
}

- (void) test_generateMessageID_withoutDomain
{
  testEquals(MessageIDShape(@""), @"<UUID>");
  testEquals(MessageIDShape(nil), @"<UUID>");
}

- (void) test_emailWithDecodedIDNDomain
{
  testEquals([@"test@xn--exmple-4ya.org" emailWithDecodedIDNDomain],
             @"test@exümple.org");
  testEquals([@"test@xn--bcher-kva.example" emailWithDecodedIDNDomain],
             @"test@bücher.example");
  testEquals([@"test@xn--mnchen-3ya.de" emailWithDecodedIDNDomain],
             @"test@münchen.de");
  testEquals([@"u@xn--80ak6aa92e.com" emailWithDecodedIDNDomain],
             @"u@аррӏе.com");
  testEquals([@"a@xn--bcher-kva.xn--exmple-4ya.org" emailWithDecodedIDNDomain],
             @"a@bücher.exümple.org");
  testEquals([@"a@b.xn--bcher-kva" emailWithDecodedIDNDomain],
             @"a@b.bücher");
}

- (void) test_emailWithDecodedIDNDomain_keepsASCIIAddresses
{
  testEquals([@"test@example.org" emailWithDecodedIDNDomain],
             @"test@example.org");
  testEquals([@"a@xn--exmple-4ya" emailWithDecodedIDNDomain],
             @"a@exümple");
  testEquals([@"plainstring" emailWithDecodedIDNDomain],
             @"plainstring");
  testEquals([@"" emailWithDecodedIDNDomain],
             @"");
  testEquals([@"@xn--bcher-kva.example" emailWithDecodedIDNDomain],
             @"@xn--bcher-kva.example");
  testEquals([@"test@" emailWithDecodedIDNDomain],
             @"test@");
}

- (void) test_emailWithDecodedIDNDomain_rejectsMalformedLabels
{
  testEquals([@"a@xn--.example" emailWithDecodedIDNDomain],
             @"a@xn--.example");
  testEquals([@"a@xn--a.example" emailWithDecodedIDNDomain],
             @"a@xn--a.example");
  testEquals([@"a@xn--*+.example" emailWithDecodedIDNDomain],
             @"a@xn--*+.example");
  testEquals([@"a@xn--bcher-kva.example." emailWithDecodedIDNDomain],
             @"a@bücher.example.");
}

@end
