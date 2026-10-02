/* TestSOGoFolderSubscriptionRoles.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import <SOGo/SOGoFolder.h>

#import "SOGoTest.h"

@interface NSObject (SubscriptionRolesDeclaration)
- (NSArray *) subscriptionRoles;
@end

@interface TestSOGoFolderSubscriptionRoles : SOGoTest
@end

static BOOL
LoadAppointmentsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Appointments"
                       markerClass: @"SOGoAppointmentObject"];
}

@implementation TestSOGoFolderSubscriptionRoles

- (NSArray *) _subscriptionRolesForClassNamed: (NSString *) className
{
  id folder;
  Class folderClass;

  folderClass = NSClassFromString (className);
  testWithMessage (folderClass != Nil,
                   @"class could not be loaded");
  if (!folderClass)
    return nil;

  folder = [[folderClass alloc] init];
  testWithMessage (folder != nil,
                   @"class could not be instantiated");

  return [folder subscriptionRoles];
}

- (void) test_calendarSubscriptionRolesAuthorizeSogoToolSharingRoles
{
  NSArray *roles, *rights;

  LoadAppointmentsBundle ();
  rights = [NSArray arrayWithObjects: @"ObjectCreator", @"PublicModifier",
                         @"ConfidentialModifier", @"PrivateModifier", nil];
  roles = [self _subscriptionRolesForClassNamed: @"SOGoAppointmentFolder"];

  testWithMessage ([roles firstObjectCommonWithArray: rights] != nil,
                   @"roles granted by 'sogo-tool manage-acl add' on calendars"
                   @" do not authorize subscriptions (bug 6171)");
}

- (void) test_calendarSubscriptionRolesAuthorizeViewers
{
  NSArray *roles, *rights;

  LoadAppointmentsBundle ();
  rights = [NSArray arrayWithObjects: @"PublicViewer", @"PublicDAndTViewer",
                         @"PrivateViewer", @"ConfidentialViewer", nil];
  roles = [self _subscriptionRolesForClassNamed: @"SOGoAppointmentFolder"];

  testWithMessage ([roles firstObjectCommonWithArray: rights] != nil,
                   @"viewer roles on calendars do not authorize"
                   @" subscriptions");
}

- (void) test_folderSubscriptionRolesAuthorizeObjectRoles
{
  SOGoFolder *folder;
  NSArray *roles, *rights;

  folder = [[SOGoFolder alloc] init];
  rights = [NSArray arrayWithObjects: @"ObjectViewer", @"ObjectEditor",
                         @"ObjectCreator", @"ObjectEraser", nil];
  roles = [folder subscriptionRoles];
  [folder release];

  testWithMessage ([roles firstObjectCommonWithArray: rights] != nil,
                   @"object roles do not authorize subscriptions on generic"
                   @" folders");
}

@end
