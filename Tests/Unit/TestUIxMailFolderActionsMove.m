/* TestUIxMailFolderActionsMove.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any
 * later version.
 *
 * This file is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 */

#import <objc/runtime.h>

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <Mailer/SOGoMailFolder.h>
#import <SOGo/NSString+Utilities.h>

#import "SOGoTest.h"
#import <UI/MailerUI/UIxMailFolderActions.h>

@interface UIxMailFolderActions (Test5785Move)
- (WOResponse *) moveFolderAction;
@end

#define FOLDER_CLASS_NAME @"SOGoMailFolder"

static NSString *move5785RenameDestination = nil;
static NSURL *move5785FolderURL = nil;

@interface Test5785Account : NSObject
@end

@implementation Test5785Account

- (NSString *) nameInContainer
{
  return @"0";
}

@end

static Test5785Account *move5785Account = nil;

static NSURL *
Imap4URLIMP (id self, SEL _cmd)
{
  return move5785FolderURL;
}

static id
MailAccountFolderIMP (id self, SEL _cmd)
{
  return move5785Account;
}

static NSException *
RenameToIMP (id self, SEL _cmd, NSString *theNewName)
{
  ASSIGN (move5785RenameDestination, theNewName);

  return nil;
}

static Class
MoveFolderClass ()
{
  static Class folderClass = Nil;

  if (!folderClass)
    {
      folderClass = objc_allocateClassPair (NSClassFromString (FOLDER_CLASS_NAME),
                                            "Test5785MailFolder", 0);
      class_addMethod (folderClass, @selector (imap4URL),
                       (IMP) Imap4URLIMP, "@@:");
      class_addMethod (folderClass, @selector (mailAccountFolder),
                       (IMP) MailAccountFolderIMP, "@@:");
      class_addMethod (folderClass, @selector (renameTo:),
                       (IMP) RenameToIMP, "@@:@");
      objc_registerClassPair (folderClass);
    }

  return folderClass;
}

@interface Test5785UserSettings : NSObject
{
  NSMutableDictionary *values;
}

- (id) objectForKey: (NSString *) key;
- (void) setObject: (id) value forKey: (NSString *) key;
- (BOOL) synchronize;

@end

@implementation Test5785UserSettings

- (id) init
{
  if ((self = [super init]))
    values = [[NSMutableDictionary alloc] init];

  return self;
}

- (void) dealloc
{
  [values release];
  [super dealloc];
}

- (id) objectForKey: (NSString *) key
{
  return [values objectForKey: key];
}

- (void) setObject: (id) value forKey: (NSString *) key
{
  [values setObject: value forKey: key];
}

- (BOOL) synchronize
{
  return YES;
}

@end

@interface Test5785User : NSObject
{
  Test5785UserSettings *settings;
}

- (id) userSettings;

@end

@implementation Test5785User

- (id) init
{
  if ((self = [super init]))
    settings = [[Test5785UserSettings alloc] init];

  return self;
}

- (void) dealloc
{
  [settings release];
  [super dealloc];
}

- (id) userSettings
{
  return settings;
}

@end

@interface Test5785FolderActions : UIxMailFolderActions
- (id) initWithTestContext: (WOContext *) aContext;
- (NSString *) labelForKey: (NSString *) key;
@end

@implementation Test5785FolderActions

- (id) initWithTestContext: (WOContext *) aContext
{
  if ((self = [super initWithRequest: [aContext request]]))
    context = aContext;

  return self;
}

- (NSString *) labelForKey: (NSString *) key
{
  return key;
}

@end

@interface TestUIxMailFolderActionsMove : SOGoTest
{
  WOContext *context;
  Test5785User *user;
  Test5785UserSettings *userSettings;
  id folder;
  Test5785FolderActions *actions;
  WOResponse *response;
  NSDictionary *json;
}

@end

@implementation TestUIxMailFolderActionsMove

- (void) setUp
{
  Class folderClass;

  testWithMessage ([SOGoTest loadSOGoBundle: @"Mailer"
                                  markerClass: FOLDER_CLASS_NAME],
                   @"SOGoMailFolder class unavailable (Mailer.SOGo bundle missing)");
  folderClass = MoveFolderClass ();
  if (!folderClass)
    return;

  if (!move5785Account)
    move5785Account = [[Test5785Account alloc] init];
  if (!move5785FolderURL)
    move5785FolderURL = [[NSURL URLWithString: @"imap://cyrus.example.com/Test-5785-Parent/Test-5785-Child"] retain];
  if (move5785RenameDestination)
    {
      [move5785RenameDestination release];
      move5785RenameDestination = nil;
    }

  context = nil;
  user = [[Test5785User alloc] init];
  userSettings = [user userSettings];
  folder = [[folderClass alloc] init];

  response = nil;
  json = nil;
}

- (void) tearDown
{
  [actions release];
  actions = nil;
  [folder release];
  [user release];
  [context release];
  [super tearDown];
}

- (void) _invokeMoveActionWithString: (NSString *) body
{
  NSString *contentString;
  WORequest *request;
  NSData *content;

  content = [body dataUsingEncoding: NSUTF8StringEncoding];
  request = [[[WORequest alloc] initWithMethod: @"POST"
                                            uri: @"/SOGo/so/test/Mail/0/folderTest-5785-Parent/folderTest-5785-Child/move"
                                    httpVersion: @"HTTP/1.1"
                                        headers: [NSDictionary dictionaryWithObject: @"application/json"
                                                                             forKey: @"content-type"]
                                        content: content
                                      userInfo: nil] autorelease];

  [context release];
  context = [[WOContext alloc] initWithRequest: request];
  [context setClientObject: folder];
  [context setActiveUser: user];

  actions = [[Test5785FolderActions alloc] initWithTestContext: context];
  response = (WOResponse *) [actions moveFolderAction];
  contentString = [[[NSString alloc] initWithData: [response content]
                                         encoding: NSUTF8StringEncoding] autorelease];
  json = [contentString objectFromJSONString];
}

- (NSMutableDictionary *) _threadsCollapsedSettings
{
  NSMutableDictionary *threadsCollapsed, *moduleSettings;

  threadsCollapsed = [NSMutableDictionary dictionaryWithObject: [NSArray arrayWithObjects: @"1", @"3", nil]
                                                        forKey: @"/0/folderTest-5785-Parent/folderTest-5785-Child"];
  moduleSettings = [NSMutableDictionary dictionaryWithObject: threadsCollapsed
                                                      forKey: @"threadsCollapsed"];
  [userSettings setObject: moduleSettings forKey: @"Mail"];

  return threadsCollapsed;
}

- (void) test_moveToTopLevelRenamesFolderToAccountRoot
{
  [self _invokeMoveActionWithString: @"{\"parent\": \"\"}"];

  test ([response status] == 200);
  testEquals (move5785RenameDestination, @"/Test-5785-Child");
  testEquals ([json objectForKey: @"path"], @"Test-5785-Child");
  testEquals ([json objectForKey: @"sievePath"], @"Test-5785-Child");
}

- (void) test_moveToTopLevelMigratesCollapsedThreadsKey
{
  NSMutableDictionary *threadsCollapsed;

  threadsCollapsed = [self _threadsCollapsedSettings];
  [self _invokeMoveActionWithString: @"{\"parent\": \"\"}"];

  test ([response status] == 200);
  test ([threadsCollapsed objectForKey: @"/0/folderTest-5785-Parent/folderTest-5785-Child"] == nil);
  testEquals ([threadsCollapsed objectForKey: @"/0/folderTest-5785-Child"],
              ([NSArray arrayWithObjects: @"1", @"3", nil]));
}

- (void) test_moveUnderParentKeepsDestinationPath
{
  [self _invokeMoveActionWithString: @"{\"parent\": \"Test-5785-Other\"}"];

  test ([response status] == 200);
  testEquals (move5785RenameDestination, @"/Test-5785-Other/Test-5785-Child");
  testEquals ([json objectForKey: @"path"], @"Test-5785-Other/Test-5785-Child");
}

- (void) test_missingParentParameterIsRejected
{
  [self _invokeMoveActionWithString: @"{}"];

  test ([response status] == 500);
  test (move5785RenameDestination == nil);
}

@end
