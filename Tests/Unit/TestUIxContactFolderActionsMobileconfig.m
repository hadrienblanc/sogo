/* TestUIxContactFolderActionsMobileconfig.m - this file is part of SOGo
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
 * Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGCards/NGVCard.h>
#import <NGCards/NGVList.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <Contacts/UIxContactFolderActions.h>

#import "SOGoTest.h"

__attribute__((weak)) char __objc_class_name_SOGoContactGCSFolder = 0;
__attribute__((weak)) char __objc_class_name_SOGoContactGCSEntry = 0;
__attribute__((weak)) char __objc_class_name_SOGoContactGCSList = 0;
__attribute__((weak)) char __objc_class_name_SOGoContactLDIFEntry = 0;

@interface UIxContactFolderActions (Test5999Mobileconfig)
- (WOResponse *) mobileconfigAction;
@end

@interface Test5999UserFolder : NSObject
@end

@implementation Test5999UserFolder

- (NSString *) davURLAsString
{
  return @"/SOGo/dav/test5999/";
}

@end

@interface Test5999Defaults : NSObject
@end

@implementation Test5999Defaults

- (NSString *) language
{
  return @"English";
}

@end

@interface Test5999User : NSObject
{
  Test5999Defaults *defaults;
}
@end

@implementation Test5999User

- (id) init
{
  if ((self = [super init]))
    defaults = [[Test5999Defaults alloc] init];

  return self;
}

- (void) dealloc
{
  [defaults release];
  [super dealloc];
}

- (NSString *) login
{
  return @"test5999";
}

- (id) userDefaults
{
  return defaults;
}

- (id) domainDefaults
{
  return defaults;
}

- (id) homeFolderInContext: (id) aContext
{
  return [[[Test5999UserFolder alloc] init] autorelease];
}

@end

@interface Test5999AddressBook : NSObject
@end

@implementation Test5999AddressBook

- (NSString *) owner
{
  return @"test5999";
}

- (NSString *) realNameInContainer
{
  return @"personal";
}

- (NSString *) davURLAsString
{
  return @"/SOGo/dav/test5999/Contacts/personal/";
}

@end

@interface Test5999FolderActions : UIxContactFolderActions
- (id) initWithTestContext: (WOContext *) aContext;
@end

@implementation Test5999FolderActions

- (id) initWithTestContext: (WOContext *) aContext
{
  if ((self = [super init]))
    context = aContext;

  return self;
}

@end

@interface TestUIxContactFolderActionsMobileconfig : SOGoTest
{
  WOContext *context;
  Test5999FolderActions *actions;
  NSDictionary *payload;
}
@end

@implementation TestUIxContactFolderActionsMobileconfig

- (void) setUp
{
  WORequest *request;

  testWithMessage ([SOGoTest loadSOGoBundle: @"Contacts"
                                 markerClass: @"SOGoContactGCSFolder"],
                   @"Contacts bundle could not be loaded");

  [[NSUserDefaults standardUserDefaults] setObject: @"English"
                                             forKey: @"SOGoLanguage"];

  request = [[[WORequest alloc] initWithMethod: @"GET"
                                            uri: @"/SOGo/so/test5999/Contacts/personal/mobileconfig"
                                    httpVersion: @"HTTP/1.1"
                                        headers: [NSDictionary dictionaryWithObject: @"sogo.test"
                                                                             forKey: @"host"]
                                        content: [NSData data]
                                      userInfo: nil] autorelease];
  context = [[WOContext alloc] initWithRequest: request];
  [context setClientObject: [[[Test5999AddressBook alloc] init] autorelease]];
  [context setActiveUser: [[[Test5999User alloc] init] autorelease]];

  actions = [[Test5999FolderActions alloc] initWithTestContext: context];
  payload = nil;
}

- (void) tearDown
{
  [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"SOGoLanguage"];
  [actions release];
  [context release];
  [super tearDown];
}

- (void) _invokeMobileconfigAction
{
  WOResponse *response;
  NSString *error;
  NSPropertyListFormat format;
  NSDictionary *plist;

  response = [actions mobileconfigAction];
  plist = [NSPropertyListSerialization propertyListFromData: [response content]
                                          mutabilityOption: NSPropertyListImmutable
                                                        format: &format
                                             errorDescription: &error];
  payload = [[plist objectForKey: @"PayloadContent"] objectAtIndex: 0];

  testWithMessage ([response status] == 200,
                   @"mobileconfig generation failed");
  testWithMessage (payload != nil,
                   @"mobileconfig payload could not be parsed");
}

- (void) test_mobileconfigUsesTheAccountPrincipalURL
{
  [self _invokeMobileconfigAction];

  testEquals([payload objectForKey: @"CardDAVPrincipalURL"], @"/SOGo/dav/test5999/");
}

- (void) test_mobileconfigKeepsTheAccountCredentials
{
  [self _invokeMobileconfigAction];

  testEquals([payload objectForKey: @"CardDAVUsername"], @"test5999");
  testEquals([payload objectForKey: @"CardDAVAccountDescription"], @"Contact test5999 - personal");
}

- (void) test_mobileconfigDoesNotExposeTheAddressBookCollectionURL
{
  [self _invokeMobileconfigAction];

  testWithMessage (![[payload objectForKey: @"CardDAVPrincipalURL"]
                      isEqualToString: @"/SOGo/dav/test5999/Contacts/personal/"],
                   @"the principal URL must not point at a single address book "
                     "(macOS Contacts silently refuses to synchronize it)");
}

@end
