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

#import <Foundation/NSBundle.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSString.h>

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
  NSString *baseDir, *bundlePath;
  NSBundle *bundle;
  NSArray *bundleNames;
  unsigned int i;

  if (draftClass)
    return draftClass;

  draftClass = NSClassFromString (DRAFT_CLASS_NAME);
  if (draftClass)
    return draftClass;

  baseDir = [[[[NSFileManager defaultManager] currentDirectoryPath]
                       stringByAppendingPathComponent: @"../.."]
                     stringByStandardizingPath];

  bundleNames = [NSArray arrayWithObjects: @"Contacts", @"Mailer", nil];
  for (i = 0; i < [bundleNames count] && !draftClass; i++)
    {
      bundlePath = [[baseDir stringByAppendingPathComponent: @"SoObjects"]
                              stringByAppendingPathComponent:
                                [NSString stringWithFormat: @"%@/%@.SOGo",
                                          [bundleNames objectAtIndex: i],
                                          [bundleNames objectAtIndex: i]]];

      if ([[NSFileManager defaultManager] fileExistsAtPath: bundlePath])
        {
          bundle = [[NSBundle alloc] initWithPath: bundlePath];
          [bundle load];
          draftClass = NSClassFromString (DRAFT_CLASS_NAME);
        }
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

@end
