/* TestSOGoAppointmentFolderNewEventsAsFree.m - this file is part of SOGo
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <Appointments/SOGoAppointmentFolder.h>
#import <SOGo/SOGoUserSettings.h>

#import "SOGoTest.h"

@class WOContext;

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

@interface TestFolderUserSettings : SOGoUserSettings
{
  NSMutableDictionary *values;
}
@end

@implementation TestFolderUserSettings

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

@interface TestFolderUser : NSObject
{
  SOGoUserSettings *settings;
}
- (id) initWithSettings: (SOGoUserSettings *) newSettings;
@end

@implementation TestFolderUser

- (id) initWithSettings: (SOGoUserSettings *) newSettings
{
  if ((self = [super init]))
    settings = [newSettings retain];

  return self;
}

- (void) dealloc
{
  [settings release];
  [super dealloc];
}

- (SOGoUserSettings *) userSettings
{
  return settings;
}

- (NSString *) login
{
  return @"sogo1";
}

@end

@interface TestFolderContext : NSObject
{
  TestFolderUser *user;
}
- (id) initWithUser: (TestFolderUser *) newUser;
@end

@implementation TestFolderContext

- (id) initWithUser: (TestFolderUser *) newUser
{
  if ((self = [super init]))
    user = [newUser retain];

  return self;
}

- (void) dealloc
{
  [user release];
  [super dealloc];
}

- (TestFolderUser *) activeUser
{
  return user;
}

@end

@interface TestFolderContainer : NSObject
@end

@implementation TestFolderContainer

- (NSString *) nameInContainer
{
  return @"Calendar";
}

@end

@interface TestNewEventsFolder : SOGoAppointmentFolder
- (void) setTestContainer: (id) newContainer;
@end

@implementation TestNewEventsFolder

- (void) setTestContainer: (id) newContainer
{
  container = newContainer;
}

@end

@interface TestSOGoAppointmentFolderNewEventsAsFree : SOGoTest
{
  TestNewEventsFolder *folder;
  TestFolderUserSettings *settings;
}
@end

@implementation TestSOGoAppointmentFolderNewEventsAsFree

- (void) setUp
{
  TestFolderContext *context;
  TestFolderUser *user;

  testWithMessage (LoadAppointmentsBundle (),
                  @"Appointments bundle could not be loaded");

  settings = [[TestFolderUserSettings alloc] init];
  user = [[[TestFolderUser alloc] initWithSettings: settings] autorelease];
  context = [[[TestFolderContext alloc] initWithUser: user] autorelease];

  folder = [[TestNewEventsFolder alloc] init];
  [folder setContext: (WOContext *) context];
  [folder setNameInContainer: @"personal"];
  [folder setOwner: @"sogo1"];
  [folder setTestContainer: [[[TestFolderContainer alloc] init] autorelease]];
}

- (void) tearDown
{
  [folder release];
  [settings release];
}

- (void) test_newEventsAreBusyByDefault
{
  testEquals([NSNumber numberWithBool: [folder newEventsAsFree]],
             [NSNumber numberWithBool: NO]);
}

- (void) test_enableDisableRoundTrip
{
  [folder setNewEventsAsFree: YES];

  testEquals([NSNumber numberWithBool: [folder newEventsAsFree]],
             [NSNumber numberWithBool: YES]);

  [folder setNewEventsAsFree: NO];

  testEquals([NSNumber numberWithBool: [folder newEventsAsFree]],
             [NSNumber numberWithBool: NO]);
}

- (void) test_valueStoredUnderFolderReference
{
  NSDictionary *moduleSettings, *category;

  [folder setNewEventsAsFree: YES];

  moduleSettings = [settings objectForKey: @"Calendar"];
  category = [moduleSettings objectForKey: @"FolderNewEventsAsFree"];

  testEquals([category objectForKey: @"sogo1:Calendar/personal"],
             [NSNumber numberWithBool: YES]);
}

- (void) test_disableDropsStoredValue
{
  NSDictionary *moduleSettings;

  [folder setNewEventsAsFree: YES];
  [folder setNewEventsAsFree: NO];

  moduleSettings = [settings objectForKey: @"Calendar"];

  test([moduleSettings objectForKey: @"FolderNewEventsAsFree"] == nil);
}

- (void) test_removeFolderSettingsDropsValue
{
  NSMutableDictionary *moduleSettings;

  [folder setNewEventsAsFree: YES];

  moduleSettings = [settings objectForKey: @"Calendar"];
  [folder removeFolderSettings: moduleSettings
                  withReference: @"sogo1:Calendar/personal"];

  testEquals([NSNumber numberWithBool: [folder newEventsAsFree]],
             [NSNumber numberWithBool: NO]);
  test([[moduleSettings objectForKey: @"FolderNewEventsAsFree"]
         objectForKey: @"sogo1:Calendar/personal"] == nil);
}

@end
