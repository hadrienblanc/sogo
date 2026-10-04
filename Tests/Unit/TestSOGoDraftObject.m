/* TestSOGoDraftObject.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any
 * later version.
 *
 * This file is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGMime/NGMimeBodyParser.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeHeaderFields.h>
#import <NGMime/NGMimeMultipartBody.h>
#import <NGMime/NGMimePartParser.h>
#import <NGMime/NGMimeType.h>
#import <NGMail/NGMimeMessageParser.h>

#import <SOGo/SOGoObject.h>
#import <Mailer/SOGoDraftObject.h>

#import "SOGoTest.h"

#define DRAFT_CLASS_NAME @"SOGoDraftObject"

static NSString *attachmentContent = @"test-6224 attachment payload\n";

@interface TestRawBodyParser : NGMimeBodyParser
@end

@implementation TestRawBodyParser

- (id) parseBodyOfPart: (id <NGMimePart>) part
                  data: (NSData *) data
              delegate: (id) d
{
  return data;
}

@end

@interface TestRawBodyParserDelegate : NSObject
@end

@implementation TestRawBodyParserDelegate

- (id <NGMimeBodyParser>) parser: (NGMimePartParser *) parser
                 bodyParserForPart: (id <NGMimePart>) part
{
  static TestRawBodyParser *rawParser = nil;

  if (!rawParser)
    rawParser = [[TestRawBodyParser alloc] init];

  if ([[[part contentType] type] isEqualToString: @"multipart"])
    return nil;

  return rawParser;
}

@end

@interface TestSOGoDraftObjectContainer : NSObject
{
  NSString *spoolPath;
}

- (id) initWithSpoolPath: (NSString *) newSpoolPath;
- (NSString *) userSpoolFolderPath;
- (id) mailAccountFolder;
- (NSString *) ownerInContext: (id) ctx;

@end

@implementation TestSOGoDraftObjectContainer

- (id) initWithSpoolPath: (NSString *) newSpoolPath
{
  if ((self = [super init]))
    {
      spoolPath = [newSpoolPath retain];
    }

  return self;
}

- (void) dealloc
{
  [spoolPath release];
  [super dealloc];
}

- (NSString *) userSpoolFolderPath
{
  return spoolPath;
}

- (id) mailAccountFolder
{
  return nil;
}

- (NSString *) ownerInContext: (id) ctx
{
  return nil;
}

@end

@interface TestSOGoDraftObject : SOGoTest
{
  SOGoDraftObject *draft;
  TestSOGoDraftObjectContainer *container;
  NSString *spoolPath;
  NSString *draftFolderPath;
}

@end

@implementation TestSOGoDraftObject

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
  NSFileManager *fm;
  NSMutableDictionary *metadata;
  NSException *error;

  fm = [NSFileManager defaultManager];

  spoolPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [NSString stringWithFormat: @"sogo-test-draft-%lu-%lu",
                                   (unsigned long) getpid (),
                                   (unsigned long) [[NSDate date] timeIntervalSince1970]]];
  [spoolPath retain];
  [fm createDirectoriesAtPath: spoolPath attributes: nil];

  container = [[TestSOGoDraftObjectContainer alloc] initWithSpoolPath: spoolPath];

  draftClass = LoadDraftClass ();
  testWithMessage (draftClass != Nil,
                   @"SOGoDraftObject class unavailable (Mailer.SOGo bundle missing)");
  if (!draftClass)
    return;

  draft = [[draftClass alloc] initWithName: @"newDraftTest6224"
                                inContainer: container];

  draftFolderPath = [[spoolPath stringByAppendingPathComponent: @"newDraftTest6224"] retain];

  [draft setHeaders: [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSArray arrayWithObject: @"user@example.org"],
                                 @"to",
                                 @"test 6224", @"subject",
                                 nil]];
  [draft setText: @"hello world"];
  [draft setIsHTML: NO];

  metadata = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                            @"test-6224-attachment.txt", @"filename",
                            @"text/plain", @"mimetype",
                            nil];
  error = [draft saveAttachment: [attachmentContent dataUsingEncoding: NSUTF8StringEncoding]
                   withMetadata: metadata];
  test (error == nil);
}

- (void) tearDown
{
  [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"SOGoMaximumMessageSizeLimit"];
  [[NSFileManager defaultManager] removeFileAtPath: spoolPath handler: nil];
  [draftFolderPath release];
  [draft release];
  [container release];
  [spoolPath release];
  [super tearDown];
}

- (void) test_failedSendKeepsDraftAttachments
{
  NSException *error;
  NSArray *attrs;
  NSData *message;
  NSString *messageString;
  NSFileManager *fm;

  fm = [NSFileManager defaultManager];

  test ([fm fileExistsAtPath: draftFolderPath]);
  test ([[draft fetchAttachmentAttrs] count] == 1);

  error = [draft sendMailAndCopyToSent: YES];

  testWithMessage (error != nil, @"the send attempt was expected to fail");
  testWithMessage ([fm fileExistsAtPath: draftFolderPath],
                   @"the draft folder was dropped after a failed send (bug 6224)");
  testWithMessage ([fm fileExistsAtPath:
                      [draft pathToAttachmentWithName: @"test-6224-attachment.txt"]],
                   @"the attachment was dropped after a failed send (bug 6224)");

  attrs = [draft fetchAttachmentAttrs];
  test ([attrs count] == 1);

  message = [draft mimeMessageForRecipient: nil extractingImages: NO];
  test (message != nil);
  messageString = [[[NSString alloc] initWithData: message
                                          encoding: NSUTF8StringEncoding] autorelease];
  testWithMessage ([messageString rangeOfString: @"multipart/mixed"].location != NSNotFound,
                   @"a resent message must still be multipart/mixed");
  testWithMessage ([messageString rangeOfString: @"test-6224-attachment.txt"].location != NSNotFound,
                   @"a resent message must still carry the attachment (bug 6224)");
}

- (void) test_composedAttachmentCarriesNoContentLengthHeader
{
  NGMimeBodyPart *part;
  NSData *message;
  NSString *messageString;

  [draft setIsHTML: YES];
  [draft setText: @"<html>Test Message</html>"];

  message = [draft mimeMessageForRecipient: nil extractingImages: NO];
  testWithMessage (message != nil, @"the composed html message must be generated");

  part = [self _composedAttachmentPartWithFilename: @"test-6224-attachment.txt"];
  testWithMessage (part != nil, @"the composed html message must carry the attachment");
  testWithMessage ([part headerForKey: @"content-length"] == nil,
                   @"an html message attachment must not carry a content-length header (bug 5926)");

  messageString = [[[NSString alloc] initWithData: message
                                          encoding: NSUTF8StringEncoding] autorelease];
  testWithMessage ([messageString rangeOfString: @"Content-Transfer-Encoding: base64"].location != NSNotFound,
                   @"the attachment part must still declare base64 transfer encoding");

  [draft setIsHTML: NO];
  [draft setText: @"Test Message"];

  message = [draft mimeMessageForRecipient: nil extractingImages: NO];
  testWithMessage (message != nil, @"the composed text message must be generated");

  part = [self _composedAttachmentPartWithFilename: @"test-6224-attachment.txt"];
  testWithMessage (part != nil, @"the composed text message must carry the attachment");
  testWithMessage ([part headerForKey: @"content-length"] == nil,
                   @"a text message attachment must not carry a content-length header (bug 5926)");
}

- (void) test_deleteRemovesDraftFolder
{
  NSFileManager *fm;

  fm = [NSFileManager defaultManager];

  test ([fm fileExistsAtPath: draftFolderPath]);
  test ([draft delete] == nil);
  testWithMessage (![fm fileExistsAtPath: draftFolderPath],
                   @"delete must remove the draft folder");
}

- (NSException *) _saveAttachmentNamed: (NSString *) filename
                                 size: (unsigned) size
{
  NSString *payload;
  NSMutableDictionary *metadata;

  payload = [@"" stringByPaddingToLength: size
                               withString: @"0"
                         startingAtIndex: 0];
  metadata = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                             filename, @"filename",
                             @"application/octet-stream", @"mimetype",
                             nil];

  return [draft saveAttachment: [payload dataUsingEncoding: NSUTF8StringEncoding]
                  withMetadata: metadata];
}

- (void) test_oversizedAttachmentRollbackRestoresMessage
{
  NSData *message;
  NSString *messageString;
  NSException *error;

  [[NSUserDefaults standardUserDefaults] setObject: @"1"
                                            forKey: @"SOGoMaximumMessageSizeLimit"];

  test ([draft mimeMessageForRecipient: nil extractingImages: NO] != nil);

  error = [self _saveAttachmentNamed: @"test-6124-oversized.bin" size: 2000];
  test (error == nil);

  testWithMessage ([draft mimeMessageForRecipient: nil extractingImages: NO] == nil,
                   @"a draft over the size limit must not generate a message (bug 6124)");

  [draft deleteAttachmentsWithNames:
    [NSArray arrayWithObject: @"test-6124-oversized.bin"]];

  message = [draft mimeMessageForRecipient: nil extractingImages: NO];
  testWithMessage (message != nil,
                   @"removing the oversized attachment must restore the message (bug 6124)");
  messageString = [[[NSString alloc] initWithData: message
                                          encoding: NSUTF8StringEncoding] autorelease];
  testWithMessage ([messageString rangeOfString: @"test-6224-attachment.txt"].location != NSNotFound,
                   @"the remaining attachment must be kept after the rollback");
  testWithMessage ([messageString rangeOfString: @"test-6124-oversized.bin"].location == NSNotFound,
                   @"the reverted attachment must not leak in the message");
}

- (void) test_deleteAttachmentsWithNamesToleratesMissingNames
{
  NSException *error;

  error = [self _saveAttachmentNamed: @"test-6124-first.bin" size: 10];
  test (error == nil);
  error = [self _saveAttachmentNamed: @"test-6124-second.bin" size: 10];
  test (error == nil);
  test ([[draft fetchAttachmentAttrs] count] == 3);

  [draft deleteAttachmentsWithNames:
    [NSArray arrayWithObjects: @"test-6124-first.bin",
                              @"test-6124-missing.bin",
                              @"test-6124-second.bin",
                              nil]];

  testWithMessage ([[draft fetchAttachmentAttrs] count] == 1,
                   @"existing attachments must be deleted and missing ones skipped");

  [draft deleteAttachmentsWithNames: [NSArray array]];
  test ([[draft fetchAttachmentAttrs] count] == 1);
}

- (NGMimeBodyPart *) _attachmentPartWithFilename: (NSString *) filename
                                         inParts: (NSArray *) parts
{
  NGMimeBodyPart *found;
  NGMimeContentDispositionHeaderField *disposition;
  NSEnumerator *e;
  id part;

  found = nil;
  e = [parts objectEnumerator];
  while ((part = [e nextObject]) && !found)
    {
      if ([[part body] isKindOfClass: [NGMimeMultipartBody class]])
        found = [self _attachmentPartWithFilename: filename
                                          inParts: [[part body] parts]];
      else
        {
          disposition = (NGMimeContentDispositionHeaderField *)
            [part headerForKey: @"content-disposition"];
          if ([[disposition filename] isEqualToString: filename])
            found = part;
        }
    }

  return found;
}

- (NGMimeBodyPart *) _composedAttachmentPartWithFilename: (NSString *) filename
{
  TestRawBodyParserDelegate *parserDelegate;
  NGMimeMessageParser *parser;
  NGMimeBodyPart *part;

  parserDelegate = [[TestRawBodyParserDelegate alloc] init];
  parser = [[NGMimeMessageParser alloc] init];
  [parser setDelegate: parserDelegate];
  part = [self _attachmentPartWithFilename: filename
                                    inParts: [[[parser parsePartFromData:
                                                  [draft mimeMessageForRecipient: nil
                                                                  extractingImages: NO]] body] parts]];
  [parser release];
  [parserDelegate release];

  return part;
}

- (NSData *) _cp1251SampleData
{
  static const unsigned char cp1251Bytes[] = {
    0xCE, 0xCE, 0xCE, 0x20, 0xC1, 0xF0, 0xF3, 0x0a
  };

  return [NSData dataWithBytes: cp1251Bytes length: sizeof(cp1251Bytes)];
}

- (void) test_htmlBodyKeepsInlineFontStyles
{
  NSData *message;
  NSString *messageString;

  [draft setIsHTML: YES];
  [draft setText: @"<html><body><p><span style=\"font-size:36px;\">BIG</span></p><p><span style=\"font-size:12px;\">small</span></p></body></html>"];

  message = [draft mimeMessageForRecipient: nil extractingImages: YES];
  testWithMessage (message != nil, @"the composed message must be generated");
  messageString = [[[NSString alloc] initWithData: message
                                          encoding: NSUTF8StringEncoding] autorelease];
  testWithMessage ([messageString rangeOfString: @"text/html"].location != NSNotFound,
                   @"the composed message must carry an html part");
  testWithMessage ([messageString rangeOfString: @"font-size:36px;"].location != NSNotFound,
                   @"font size changes must be sent (bug 6095)");
  testWithMessage ([messageString rangeOfString: @"font-size:12px;"].location != NSNotFound,
                   @"all font size changes must be sent (bug 6095)");
}

- (void) test_textAttachmentBytesArePreserved
{
  NSMutableDictionary *metadata;
  NGMimeBodyPart *part;
  NSData *original;
  NSString *messageString;

  original = [self _cp1251SampleData];
  metadata = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                             @"test-6114-report.txt", @"filename",
                             @"text/plain", @"mimetype",
                             nil];
  test ([draft saveAttachment: original withMetadata: metadata] == nil);

  messageString = [[[NSString alloc] initWithData:
                      [draft mimeMessageForRecipient: nil extractingImages: NO]
                                      encoding: NSISOLatin1StringEncoding] autorelease];
  testWithMessage ([messageString rangeOfString: @"Content-Transfer-Encoding: base64"].location != NSNotFound,
                   @"the attachment part must declare base64 transfer encoding");

  part = [self _composedAttachmentPartWithFilename: @"test-6114-report.txt"];
  testWithMessage (part != nil, @"the composed message must carry the attachment");

  testWithMessage ([[[part contentType] stringValue] hasPrefix: @"text/plain"],
                   @"the attachment content type must stay text/plain");
  testWithMessage ([[[part contentType] valueOfParameter: @"charset"] length] == 0,
                   @"no charset must be invented for an opaque attachment");
  testWithMessage ([[part body] isEqualToData: original],
                   @"a text attachment must be composed byte for byte (bug 6114)");
}

- (void) test_declaredAttachmentCharsetIsPassedThrough
{
  NSMutableDictionary *metadata;
  NGMimeBodyPart *part;
  NSData *original;

  original = [self _cp1251SampleData];
  metadata = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                             @"test-6114-charset.txt", @"filename",
                             @"text/plain; charset=windows-1251", @"mimetype",
                             nil];
  test ([draft saveAttachment: original withMetadata: metadata] == nil);

  part = [self _composedAttachmentPartWithFilename: @"test-6114-charset.txt"];
  testWithMessage (part != nil, @"the composed message must carry the attachment");

  testWithMessage ([[[part contentType] stringValue] isEqualToString: @"text/plain; charset=windows-1251"],
                   @"the declared content type must be passed through verbatim");
  testWithMessage ([[part body] isEqualToData: original],
                   @"a charset-declared attachment must not be transcoded (bug 6114)");
}

- (void) test_saveAttachmentWithStringBodyPersistsUTF8Bytes
{
  NSString *content;
  NSMutableDictionary *metadata;
  NSData *spooled;

  content = @"\u041e\u041e\u041e report\n";
  metadata = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                             @"test-6114-string.txt", @"filename",
                             @"text/plain", @"mimetype",
                             nil];
  test ([draft saveAttachment: content withMetadata: metadata] == nil);

  spooled = [NSData dataWithContentsOfFile:
               [draft pathToAttachmentWithName: @"test-6114-string.txt"]];
  testWithMessage ([spooled isEqualToData: [content dataUsingEncoding: NSUTF8StringEncoding]],
                   @"a string attachment body must be persisted as UTF-8");
}

- (void) test_setHeadersReplacesPreviousReplyTo
{
  [draft setHeaders: [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"replies-a@example.com", @"replyTo",
                                 nil]];
  testEquals ([[draft headers] objectForKey: @"reply-to"],
              @"replies-a@example.com");

  [draft setHeaders: [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"replies-b@example.com", @"replyTo",
                                 nil]];
  testEquals ([[draft headers] objectForKey: @"reply-to"],
              @"replies-b@example.com");
  testEquals ([[draft headers] objectForKey: @"replyTo"], nil);
}

- (void) test_setHeadersDropsStaleReplyToWhenCleared
{
  [draft setHeaders: [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"replies-a@example.com", @"replyTo",
                                 nil]];
  testEquals ([[draft headers] objectForKey: @"reply-to"],
              @"replies-a@example.com");

  [draft setHeaders: [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"", @"replyTo",
                                 nil]];
  testEquals ([[draft headers] objectForKey: @"reply-to"], nil);
}

- (void) test_setHeadersDropsStaleReplyToWhenAbsent
{
  [draft setHeaders: [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"replies-a@example.com", @"replyTo",
                                 nil]];

  [draft setHeaders: [NSDictionary dictionary]];
  testEquals ([[draft headers] objectForKey: @"reply-to"], nil);
}

- (void) test_composedMessageCarriesCurrentReplyToOnly
{
  NSData *message;
  NSString *messageString;

  [draft setHeaders: [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"replies-a@example.com", @"replyTo",
                                 nil]];
  message = [draft mimeMessageForRecipient: nil extractingImages: NO];
  messageString = [[[NSString alloc] initWithData: message
                                          encoding: NSUTF8StringEncoding] autorelease];
  testWithMessage ([messageString rangeOfString: @"replies-a@example.com"].location != NSNotFound,
                   @"the composed message must carry the reply-to of the current identity (bug 5984)");

  [draft setHeaders: [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"", @"replyTo",
                                 nil]];
  message = [draft mimeMessageForRecipient: nil extractingImages: NO];
  messageString = [[[NSString alloc] initWithData: message
                                          encoding: NSUTF8StringEncoding] autorelease];
  testWithMessage ([messageString rangeOfString: @"replies-a@example.com"].location == NSNotFound,
                   @"the composed message must drop the reply-to of the previous identity (bug 5984)");
}

@end
