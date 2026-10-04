/* TestUIxMailEditorReplyTo.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>

#import "SOGoTest.h"

#define DRAFT_CLASS_NAME @"SOGoDraftObject"

__attribute__((weak)) char __objc_class_name_SOGoDraftObject = 0;
__attribute__((weak)) char __objc_class_name_SOGoMailObject = 0;
__attribute__((weak)) char __objc_class_name_SOGoMailFolder = 0;
__attribute__((weak)) char __objc_class_name_SOGoMailAccount = 0;
__attribute__((weak)) char __objc_class_name_SOGoSentFolder = 0;
__attribute__((weak)) char __objc_class_name_SOGoDraftsFolder = 0;
__attribute__((weak)) char __objc_class_name_SOGoMailBodyPart = 0;
__attribute__((weak)) char __objc_class_name_SOGoImageMailBodyPart = 0;

@interface Test5984MailAccountFolder : NSObject
{
  NSArray *folderIdentities;
  NSDictionary *folderDefaultIdentity;
  NSString *folderName;
}

@end

@implementation Test5984MailAccountFolder

- (id) initWithIdentities: (NSArray *) newIdentities
          defaultIdentity: (NSDictionary *) newDefaultIdentity
                     name: (NSString *) newName
{
  if ((self = [super init]))
    {
      folderIdentities = [newIdentities retain];
      folderDefaultIdentity = [newDefaultIdentity retain];
      folderName = [newName retain];
    }

  return self;
}

- (void) dealloc
{
  [folderIdentities release];
  [folderDefaultIdentity release];
  [folderName release];
  [super dealloc];
}

- (NSArray *) identities
{
  return folderIdentities;
}

- (NSDictionary *) defaultIdentity
{
  return folderDefaultIdentity;
}

- (NSString *) nameInContainer
{
  return folderName;
}

@end

@interface Test5984Draft : NSObject
{
  Test5984MailAccountFolder *mailAccountFolder;
}

@end

@implementation Test5984Draft

- (id) initWithMailAccountFolder: (Test5984MailAccountFolder *) newFolder
{
  if ((self = [super init]))
    mailAccountFolder = [newFolder retain];

  return self;
}

- (void) dealloc
{
  [mailAccountFolder release];
  [super dealloc];
}

- (id) mailAccountFolder
{
  return mailAccountFolder;
}

@end

@interface Test5984User : NSObject
{
  NSDictionary *identity;
}

@end

@implementation Test5984User

- (id) initWithDefaultIdentity: (NSDictionary *) newIdentity
{
  if ((self = [super init]))
    identity = [newIdentity retain];

  return self;
}

- (void) dealloc
{
  [identity release];
  [super dealloc];
}

- (NSDictionary *) defaultIdentity
{
  return identity;
}

@end

@interface Test5984MailEditorFactory : NSObject
@end

@implementation Test5984MailEditorFactory

+ (id) editorWithFolderName: (NSString *) folderName
                   identities: (NSArray *) identities
            folderDefaultIdentity: (NSDictionary *) folderDefaultIdentity
                    user: (Test5984User *) user
{
  Test5984MailAccountFolder *folder;
  Test5984Draft *draft;
  WORequest *request;
  WOContext *context;
  id editor;

  folder = [[[Test5984MailAccountFolder alloc] initWithIdentities: identities
                                                  defaultIdentity: folderDefaultIdentity
                                                             name: folderName] autorelease];
  draft = [[[Test5984Draft alloc] initWithMailAccountFolder: folder] autorelease];

  request = [[[WORequest alloc] initWithMethod: @"GET"
                                            uri: @"/SOGo/so/test/Mail/0/drafts/42/edit"
                                    httpVersion: @"HTTP/1.1"
                                        headers: [NSDictionary dictionary]
                                        content: nil
                                      userInfo: nil] autorelease];
  context = [[[WOContext alloc] initWithRequest: request] autorelease];
  [context setClientObject: draft];
  [context setActiveUser: user];

  editor = [[NSClassFromString (@"UIxMailEditor") alloc] init];
  [editor setValue: context forKey: @"context"];

  return [editor autorelease];
}

@end

@interface TestUIxMailEditorReplyTo : SOGoTest
{
  NSDictionary *favoredIdentity;
  NSDictionary *secondIdentity;
  NSDictionary *thirdIdentity;
}

@end

@implementation TestUIxMailEditorReplyTo

- (void) setUp
{
  testWithMessage ([SOGoTest loadSOGoBundle: @"Mailer"
                                 markerClass: DRAFT_CLASS_NAME],
                   @"SOGoDraftObject class unavailable (Mailer.SOGo bundle missing)");

  favoredIdentity = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"Favored User", @"fullName",
                                  @"favored@example.com", @"email",
                                  @"replies-favored@example.com", @"replyTo",
                                  [NSNumber numberWithBool: YES], @"isDefault",
                                  nil];
  [favoredIdentity retain];
  secondIdentity = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"Second User", @"fullName",
                                @"second@example.com", @"email",
                                @"replies-second@example.com", @"replyTo",
                                nil];
  [secondIdentity retain];
  thirdIdentity = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"Third User", @"fullName",
                               @"third@example.com", @"email",
                               nil];
  [thirdIdentity retain];
}

- (void) tearDown
{
  [favoredIdentity release];
  [secondIdentity release];
  [thirdIdentity release];
  [super tearDown];
}

- (id) _editorWithFolderName: (NSString *) folderName
       folderDefaultIdentity: (NSDictionary *) folderDefaultIdentity
{
  NSArray *identities;
  Test5984User *user;

  identities = [NSArray arrayWithObjects: favoredIdentity, secondIdentity,
                           thirdIdentity, nil];
  user = [[[Test5984User alloc] initWithDefaultIdentity: favoredIdentity] autorelease];

  return [Test5984MailEditorFactory editorWithFolderName: folderName
                                              identities: identities
                                     folderDefaultIdentity: folderDefaultIdentity
                                                     user: user];
}

- (void) test_replyToFollowsIdentityMatchingFrom
{
  id editor;

  editor = [self _editorWithFolderName: @"0" folderDefaultIdentity: favoredIdentity];
  [editor setValue: @"Second User <second@example.com>" forKey: @"from"];
  testEquals ([editor valueForKey: @"replyTo"], @"replies-second@example.com");
}

- (void) test_replyToKeepsFavoredIdentityWhenSelected
{
  id editor;

  editor = [self _editorWithFolderName: @"0" folderDefaultIdentity: favoredIdentity];
  [editor setValue: @"Favored User <favored@example.com>" forKey: @"from"];
  testEquals ([editor valueForKey: @"replyTo"], @"replies-favored@example.com");
}

- (void) test_replyToIsOmittedWhenMatchingIdentityHasNone
{
  id editor;

  editor = [self _editorWithFolderName: @"0" folderDefaultIdentity: favoredIdentity];
  [editor setValue: @"Third User <third@example.com>" forKey: @"from"];
  testEquals ([editor valueForKey: @"replyTo"], nil);
}

- (void) test_replyToFallsBackToUserDefaultIdentityWithoutFrom
{
  id editor;

  editor = [self _editorWithFolderName: @"0" folderDefaultIdentity: secondIdentity];
  testEquals ([editor valueForKey: @"replyTo"], @"replies-favored@example.com");
}

- (void) test_replyToFallsBackToUserDefaultIdentityOnUnknownFrom
{
  id editor;

  editor = [self _editorWithFolderName: @"0" folderDefaultIdentity: secondIdentity];
  [editor setValue: @"Unknown <unknown@example.org>" forKey: @"from"];
  testEquals ([editor valueForKey: @"replyTo"], @"replies-favored@example.com");
}

- (void) test_auxiliaryAccountReplyToFallsBackToFolderDefaultIdentity
{
  id editor;

  editor = [self _editorWithFolderName: @"1" folderDefaultIdentity: secondIdentity];
  [editor setValue: @"Unknown <unknown@example.org>" forKey: @"from"];
  testEquals ([editor valueForKey: @"replyTo"], @"replies-second@example.com");
}

@end
