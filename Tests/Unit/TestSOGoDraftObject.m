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

#import <Foundation/NSDate.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <SOGo/SOGoObject.h>
#import <Mailer/SOGoDraftObject.h>

#import "SOGoTest.h"

#define DRAFT_CLASS_NAME @"SOGoDraftObject"

static NSString *attachmentContent = @"test-6224 attachment payload\n";

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

@end
