/* TestSOGoGCSFolderDelete.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any
 * later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/Foundation.h>

#import <GDLContentStore/GCSFolderManager.h>
#import <NGObjWeb/NSException+HTTP.h>

#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoGCSFolder.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>

#import "SOGoTest.h"

@class WOContext;

@interface TestDeleteUserSettings : SOGoUserSettings
{
  NSMutableDictionary *values;
}
@end

@implementation TestDeleteUserSettings

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

- (void) setObject: (id) object
	    forKey: (NSString *) key
{
  [values setObject: object forKey: key];
}

- (BOOL) synchronize
{
  return YES;
}

@end

@interface TestDeleteUser : SOGoUser
{
  TestDeleteUserSettings *settingsValue;
}
+ (TestDeleteUser *) testUserWithLogin: (NSString *) login;
- (TestDeleteUserSettings *) settings;
@end

@implementation TestDeleteUser

+ (TestDeleteUser *) testUserWithLogin: (NSString *) login
{
  TestDeleteUser *user;

  user = [[TestDeleteUser alloc] initWithLogin: login
					  roles: nil
					  trust: YES];
  [user autorelease];
  user->settingsValue = [TestDeleteUserSettings new];

  return user;
}

- (void) dealloc
{
  [settingsValue release];
  [super dealloc];
}

- (TestDeleteUserSettings *) settings
{
  return settingsValue;
}

- (TestDeleteUserSettings *) userSettings
{
  return settingsValue;
}

- (NSString *) domain
{
  return @"example.com";
}

@end

@interface TestDeleteRequest : NSObject
@end

@implementation TestDeleteRequest

- (NSString *) method
{
  return @"DELETE";
}

- (BOOL) handledByDefaultHandler
{
  return NO;
}

@end

@interface TestDeleteContext : NSObject
{
  TestDeleteUser *userValue;
}
+ (TestDeleteContext *) contextWithUser: (TestDeleteUser *) user;
@end

@implementation TestDeleteContext

+ (TestDeleteContext *) contextWithUser: (TestDeleteUser *) user
{
  TestDeleteContext *context;

  context = [[TestDeleteContext new] autorelease];
  context->userValue = [user retain];

  return context;
}

- (void) dealloc
{
  [userValue release];
  [super dealloc];
}

- (TestDeleteUser *) activeUser
{
  return userValue;
}

- (TestDeleteRequest *) request
{
  return [[[TestDeleteRequest alloc] init] autorelease];
}

@end

@interface TestDeleteContainer : NSObject
{
  NSString *ownerValue;
}
+ (TestDeleteContainer *) containerWithOwner: (NSString *) owner;
@end

@implementation TestDeleteContainer

+ (TestDeleteContainer *) containerWithOwner: (NSString *) owner
{
  TestDeleteContainer *container;

  container = [[TestDeleteContainer new] autorelease];
  container->ownerValue = [owner retain];

  return container;
}

- (void) dealloc
{
  [ownerValue release];
  [super dealloc];
}

- (NSString *) nameInContainer
{
  return @"Calendar";
}

- (NSString *) ownerInContext: (id) ctx
{
  return ownerValue;
}

@end

@interface TestDeleteFolderManager : NSObject
{
  NSMutableArray *deletedPathsValue;
}
- (NSArray *) deletedPaths;
@end

@implementation TestDeleteFolderManager

- (id) init
{
  if ((self = [super init]))
    deletedPathsValue = [[NSMutableArray alloc] init];

  return self;
}

- (void) dealloc
{
  [deletedPathsValue release];
  [super dealloc];
}

- (NSArray *) deletedPaths
{
  return deletedPathsValue;
}

- (NSException *) deleteFolderAtPath: (NSString *) path
{
  [deletedPathsValue addObject: path];

  return nil;
}

@end

@interface TestDeleteGCSFolder : SOGoGCSFolder
{
  TestDeleteContainer *testContainer;
  TestDeleteFolderManager *testFolderManager;
}
- (void) setTestContainer: (id) newContainer;
- (void) setTestFolderManager: (id) newFolderManager;
- (NSArray *) deletedFolderPaths;
@end

@implementation TestDeleteGCSFolder

- (void) dealloc
{
  [testContainer release];
  [testFolderManager release];
  [super dealloc];
}

- (void) setTestContainer: (id) newContainer
{
  ASSIGN (testContainer, newContainer);
  container = testContainer;
}

- (void) setTestFolderManager: (id) newFolderManager
{
  ASSIGN (testFolderManager, newFolderManager);
}

- (NSArray *) deletedFolderPaths
{
  return [testFolderManager deletedPaths];
}

- (NSString *) folderType
{
  return @"Appointment";
}

- (GCSFolderManager *) folderManager
{
  return (GCSFolderManager *) testFolderManager;
}

@end

@interface TestSOGoGCSFolderDelete : SOGoTest
@end

@implementation TestSOGoGCSFolderDelete

- (void) tearDown
{
  [[SOGoCache sharedCache] killCache];
}

- (TestDeleteGCSFolder *) _ownedFolderWithFolderManager: (TestDeleteFolderManager *) folderManager
						    name: (NSString *) name
{
  TestDeleteGCSFolder *folder;
  TestDeleteContext *context;
  TestDeleteUser *owner;

  folder = [[[TestDeleteGCSFolder alloc] init] autorelease];
  [folder setNameInContainer: name];
  [folder setTestContainer: [TestDeleteContainer containerWithOwner: @"owner6073"]];
  [folder setTestFolderManager: folderManager];
  owner = [TestDeleteUser testUserWithLogin: @"owner6073"];
  [[SOGoCache sharedCache] registerUser: owner
				  withName: @"owner6073"];
  context = [TestDeleteContext contextWithUser: owner];
  [folder setContext: (WOContext *) context];
  [folder setOCSPath: [@"/Users/owner6073/Calendar/" stringByAppendingString: name]];
  [folder setOwner: @"owner6073"];

  return folder;
}

- (NSMutableDictionary *) _subscriptionSettingsForUser: (TestDeleteUser *) user
{
  NSMutableDictionary *moduleSettings;
  NSMutableArray *subscribedFolders;
  NSMutableDictionary *folderDisplayNames;

  moduleSettings = [NSMutableDictionary dictionary];
  subscribedFolders = [NSMutableArray arrayWithObject: @"owner6073:Calendar/personal"];
  [moduleSettings setObject: subscribedFolders
		    forKey: @"SubscribedFolders"];
  folderDisplayNames = [NSMutableDictionary dictionary];
  [folderDisplayNames setObject: @"Agenda"
			 forKey: @"owner6073:Calendar/personal"];
  [moduleSettings setObject: folderDisplayNames
		    forKey: @"FolderDisplayNames"];
  [[user settings] setObject: moduleSettings
			   forKey: @"Calendar"];

  return moduleSettings;
}

- (void) test_deleteOnSubscriptionRemovesSubscriptionWithoutDeletingFolder
{
  TestDeleteFolderManager *folderManager;
  TestDeleteGCSFolder *folder;
  TestDeleteContext *context;
  TestDeleteUser *subscriber;
  NSMutableDictionary *moduleSettings;
  NSException *error;

  folderManager = [[TestDeleteFolderManager alloc] init];
  folder = [[[TestDeleteGCSFolder alloc] init] autorelease];
  [folder setNameInContainer: @"owner6073_personal"];
  [folder setTestContainer: [TestDeleteContainer containerWithOwner: @"subscriber6073"]];
  [folder setTestFolderManager: folderManager];
  subscriber = [TestDeleteUser testUserWithLogin: @"subscriber6073"];
  [[SOGoCache sharedCache] registerUser: subscriber
				  withName: @"subscriber6073"];
  context = [TestDeleteContext contextWithUser: subscriber];
  [folder setContext: (WOContext *) context];
  [folder setOCSPath: @"/Users/owner6073/Calendar/personal"];
  [folder setOwner: @"owner6073"];
  [folder setIsSubscription: YES];
  moduleSettings = [self _subscriptionSettingsForUser: subscriber];

  error = [folder delete];

  test(error == nil);
  test([[folder deletedFolderPaths] count] == 0);
  test([[moduleSettings objectForKey: @"SubscribedFolders"]
         containsObject: @"owner6073:Calendar/personal"] == NO);
  test([[moduleSettings objectForKey: @"FolderDisplayNames"]
         objectForKey: @"owner6073:Calendar/personal"] == nil);

  [folderManager release];
}

- (void) test_deleteOnOwnedFolderDeletesFolder
{
  TestDeleteFolderManager *folderManager;
  TestDeleteGCSFolder *folder;
  NSException *error;

  folderManager = [[TestDeleteFolderManager alloc] init];
  folder = [self _ownedFolderWithFolderManager: folderManager
					  name: @"extra"];

  error = [folder delete];

  test(error == nil);
  test([[folder deletedFolderPaths] count] == 1);
  testEquals([[folder deletedFolderPaths] objectAtIndex: 0],
             @"/Users/owner6073/Calendar/extra");

  [folderManager release];
}

- (void) test_deleteOnPersonalFolderIsRefused
{
  TestDeleteFolderManager *folderManager;
  TestDeleteGCSFolder *folder;
  NSException *error;

  folderManager = [[TestDeleteFolderManager alloc] init];
  folder = [self _ownedFolderWithFolderManager: folderManager
					  name: @"personal"];

  error = [folder delete];

  test(error != nil);
  test([error httpStatus] == 403);
  test([[folder deletedFolderPaths] count] == 0);

  [folderManager release];
}

@end
