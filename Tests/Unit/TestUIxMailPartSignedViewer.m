#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>

#import "SOGoTest.h"
#import "UIxMailPartSignedViewer.h"

#if defined(HAVE_OPENSSL)

@interface Test5723Address : NSObject
{
  NSString *email;
}

- (id) initWithEMail: (NSString *) theEmail;
- (NSString *) baseEMail;

@end

@implementation Test5723Address

- (id) initWithEMail: (NSString *) theEmail
{
  if ((self = [super init]))
    email = [theEmail retain];

  return self;
}

- (void) dealloc
{
  [email release];
  [super dealloc];
}

- (NSString *) baseEMail
{
  return email;
}

@end

@interface Test5723MailObject : NSObject
{
  NSData *content;
  Test5723Address *from;
}

- (id) initWithContent: (NSData *) theContent
                  from: (NSString *) theFrom;
- (NSData *) content;
- (NSArray *) fromEnvelopeAddresses;

@end

@implementation Test5723MailObject

- (id) initWithContent: (NSData *) theContent
                  from: (NSString *) theFrom
{
  if ((self = [super init]))
    {
      content = [theContent retain];
      from = [[Test5723Address alloc] initWithEMail: theFrom];
    }

  return self;
}

- (void) dealloc
{
  [content release];
  [from release];
  [super dealloc];
}

- (NSData *) content
{
  return content;
}

- (NSArray *) fromEnvelopeAddresses
{
  return [NSArray arrayWithObject: from];
}

@end

@interface Test5723SignedViewer : UIxMailPartSignedViewer
{
  Test5723MailObject *mail;
}

- (id) initWithMail: (Test5723MailObject *) theMail;
- (id) decodedFlatContent;
- (id) clientObject;
- (NSString *) labelForKey: (NSString *) key;

@end

@implementation Test5723SignedViewer

- (id) initWithMail: (Test5723MailObject *) theMail
{
  if ((self = [super init]))
    mail = [theMail retain];

  return self;
}

- (void) dealloc
{
  [mail release];
  [super dealloc];
}

- (id) decodedFlatContent
{
  return [mail content];
}

- (id) clientObject
{
  return mail;
}

- (NSString *) labelForKey: (NSString *) key
{
  return key;
}

@end

@interface TestUIxMailPartSignedViewer : SOGoTest
{
  NSData *signedContent;
}

- (Test5723SignedViewer *) viewerWithSender: (NSString *) sender
                                    content: (NSData *) content;
- (NSData *) tamperedContent;

@end

@implementation TestUIxMailPartSignedViewer

- (void) setUp
{
  signedContent = [[NSData dataWithContentsOfFile: @"Fixtures/ticket-5723-signed.eml"] retain];
}

- (void) tearDown
{
  [signedContent release];
}

- (Test5723SignedViewer *) viewerWithSender: (NSString *) sender
                                    content: (NSData *) content
{
  Test5723MailObject *mail;
  Test5723SignedViewer *viewer;

  mail = [[[Test5723MailObject alloc] initWithContent: content
                                                 from: sender] autorelease];
  viewer = [[[Test5723SignedViewer alloc] initWithMail: mail] autorelease];

  return viewer;
}

- (NSData *) tamperedContent
{
  NSString *s;

  s = [[[NSString alloc] initWithData: signedContent
                              encoding: NSUTF8StringEncoding] autorelease];
  s = [s stringByReplacingOccurrencesOfString: @"This signed content is intact."
                                   withString: @"This mailing list modified the content."];

  return [s dataUsingEncoding: NSUTF8StringEncoding];
}

- (void) test_intactSignatureFromUntrustedSignerIsValidOfTicket5723
{
  Test5723SignedViewer *viewer;

  viewer = [self viewerWithSender: @"test-5723-list@sogo.local"
                          content: signedContent];
  test ([viewer validSignature] == YES);
  testEquals ([viewer validationMessage],
              @"Message is signed but the certificate doesn't match the sender email address");
}

- (void) test_intactSignatureWithSenderMatchingCertificateOfTicket5723
{
  Test5723SignedViewer *viewer;

  viewer = [self viewerWithSender: @"author@sogo.local"
                          content: signedContent];
  test ([viewer validSignature] == YES);
  testEquals ([viewer validationMessage], @"Message is signed");
}

- (void) test_modifiedContentIsReportedAsInvalidSignatureOfTicket5723
{
  Test5723SignedViewer *viewer;

  viewer = [self viewerWithSender: @"author@sogo.local"
                          content: [self tamperedContent]];
  test ([viewer validSignature] == NO);
  testEquals ([viewer validationMessage], @"verification failure");
}

- (void) test_signerCertificateEmailsAreExtractedOfTicket5723
{
  Test5723SignedViewer *viewer;
  NSArray *certificates;

  viewer = [self viewerWithSender: @"author@sogo.local"
                          content: signedContent];
  test ([viewer validSignature] == YES);
  certificates = [viewer smimeCertificates];
  test ([certificates count] == 1);
  testEquals ([[certificates lastObject] objectForKey: @"emails"],
              [NSArray arrayWithObject: @"author@sogo.local"]);
}

@end

#endif /* HAVE_OPENSSL */
