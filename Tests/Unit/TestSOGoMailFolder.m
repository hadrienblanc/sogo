/* TestSOGoMailFolder.m - this file is part of SOGo
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

#import <objc/runtime.h>

#import <Foundation/NSData.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import "SOGoTest.h"

#define FOLDER_CLASS_NAME @"SOGoMailFolder"

static BOOL folderExists;
static NSException *folderCreateError;
static NSException *folderAppendError;
static unsigned createCalls, appendCalls;
static NSString *createdMailboxName;
static NSData *appendedMessageData;
static NSURL *appendedFolderURL;

@interface Test6153Connection : NSObject
@end

@implementation Test6153Connection

- (NSString *) imap4FolderNameForURL: (NSURL *) url
{
  NSString *path;

  path = [url path];
  if ([path length] > 1)
    path = [path substringFromIndex: 1];

  return path;
}

- (NSException *) createMailbox: (NSString *) mailbox atURL: (NSURL *) url
{
  createCalls++;
  [createdMailboxName release];
  createdMailboxName = [mailbox retain];

  return folderCreateError;
}

- (NSException *) postData: (NSData *) data
                     flags: (id) flags
              toFolderURL: (NSURL *) url
{
  appendCalls++;
  [appendedMessageData release];
  appendedMessageData = [data retain];
  [appendedFolderURL release];
  appendedFolderURL = [url retain];

  return folderAppendError;
}

@end

@interface Test6153Account : NSObject
@end

@implementation Test6153Account

- (NSURL *) imap4URL
{
  return [NSURL URLWithString: @"imap://127.0.0.1:143/"];
}

@end

static Test6153Connection *connection6153 = nil;
static Test6153Account *account6153 = nil;

static BOOL
ExistsIMP (id self, SEL _cmd)
{
  return folderExists;
}

static id
Imap4ConnectionIMP (id self, SEL _cmd)
{
  return connection6153;
}

static NSURL *
Imap4URLIMP (id self, SEL _cmd)
{
  return [NSURL URLWithString: @"imap://127.0.0.1:143/folderSent"];
}

static id
MailAccountFolderIMP (id self, SEL _cmd)
{
  return account6153;
}

static NSString *
RelativeImap4NameIMP (id self, SEL _cmd)
{
  return @"Sent";
}

static Class
PostDataFolderClass ()
{
  static Class folderClass = Nil;

  if (!folderClass)
    {
      folderClass = objc_allocateClassPair (NSClassFromString (FOLDER_CLASS_NAME),
                                            "PostData6153Folder", 0);
      class_addMethod (folderClass, @selector (exists), (IMP) ExistsIMP, "B@:");
      class_addMethod (folderClass, @selector (imap4Connection),
                       (IMP) Imap4ConnectionIMP, "@@:");
      class_addMethod (folderClass, @selector (imap4URL),
                       (IMP) Imap4URLIMP, "@@:");
      class_addMethod (folderClass, @selector (mailAccountFolder),
                       (IMP) MailAccountFolderIMP, "@@:");
      class_addMethod (folderClass, @selector (relativeImap4Name),
                       (IMP) RelativeImap4NameIMP, "@@:");
      objc_registerClassPair (folderClass);
    }

  return folderClass;
}

static NSException *
AlreadyExistsException ()
{
  return [NSException exceptionWithName: @"NGImap4Exception"
                                  reason: @"Failed to create folder: Mailbox already exists"
                                userInfo: nil];
}

@interface TestSOGoMailFolder : SOGoTest
{
  id folder;
}

@end

@implementation TestSOGoMailFolder

- (void) setUp
{
  Class folderClass;

  testWithMessage ([SOGoTest loadSOGoBundle: @"Mailer"
                                 markerClass: FOLDER_CLASS_NAME],
                   @"SOGoMailFolder class unavailable (Mailer.SOGo bundle missing)");
  folderClass = PostDataFolderClass ();
  if (!folderClass)
    return;

  if (!connection6153)
    connection6153 = [[Test6153Connection alloc] init];
  if (!account6153)
    account6153 = [[Test6153Account alloc] init];

  folderExists = NO;
  folderCreateError = nil;
  folderAppendError = nil;
  createCalls = 0;
  appendCalls = 0;

  folder = [[folderClass alloc] init];
}

- (void) tearDown
{
  [folder release];
  [createdMailboxName release];
  createdMailboxName = nil;
  [appendedMessageData release];
  appendedMessageData = nil;
  [appendedFolderURL release];
  appendedFolderURL = nil;
  [super tearDown];
}

- (void) _resetScenario: (BOOL) exists
            createError: (NSException *) createError
{
  folderExists = exists;
  folderCreateError = createError;
}

- (void) test_postDataAppendsWhenFolderExists
{
  NSException *error;

  [self _resetScenario: YES createError: AlreadyExistsException ()];

  error = [folder postData: [@"hello" dataUsingEncoding: NSUTF8StringEncoding]
                      flags: @"seen"];

  test (error == nil);
  test (createCalls == 0);
  test (appendCalls == 1);
}

- (void) test_postDataAppendsAfterSuccessfulCreate
{
  NSException *error;

  [self _resetScenario: NO createError: nil];

  error = [folder postData: [@"hello" dataUsingEncoding: NSUTF8StringEncoding]
                      flags: @"seen"];

  test (error == nil);
  test (createCalls == 1);
  test (appendCalls == 1);
  test ([createdMailboxName isEqualToString: @"folderSent"]);
}

- (void) test_postDataAppendsWhenCreateReportsAlreadyExists
{
  NSException *error;

  [self _resetScenario: NO createError: AlreadyExistsException ()];

  error = [folder postData: [@"hello" dataUsingEncoding: NSUTF8StringEncoding]
                      flags: @"seen"];

  testWithMessage (error == nil,
                   @"a CREATE refused with 'already exists' proves the mailbox"
                   @" exists and must not abort the append (bug 6153)");
  test (createCalls == 1);
  testWithMessage (appendCalls == 1,
                   @"the message must still be appended to the existing mailbox");
}

- (void) test_postDataFailsWhenCreateFailsOtherwise
{
  NSException *error;

  [self _resetScenario: NO
           createError: [NSException exceptionWithName: @"NGImap4Exception"
                                                 reason: @"Failed to create folder: Permission denied"
                                               userInfo: nil]];

  error = [folder postData: [@"hello" dataUsingEncoding: NSUTF8StringEncoding]
                      flags: @"seen"];

  test (error != nil);
  test ([[error reason] isEqualToString: @"Sent is not an IMAP4 folder"]);
  test (createCalls == 1);
  test (appendCalls == 0);
}

- (void) test_postDataPropagatesAppendError
{
  NSException *error;

  [self _resetScenario: YES createError: nil];
  folderAppendError = [NSException exceptionWithName: @"NGImap4Exception"
                                               reason: @"Failed to store message"
                                             userInfo: nil];

  error = [folder postData: [@"hello" dataUsingEncoding: NSUTF8StringEncoding]
                      flags: @"seen"];

  test (error == folderAppendError);
  test (appendCalls == 1);
}

@end
