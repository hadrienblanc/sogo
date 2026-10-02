/* TestSOGoWebDAVAclManager.m - this file is part of SOGo
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
#import <Foundation/NSDictionary.h>

#import <SOGo/SOGoGCSFolder.h>
#import <SOGo/SOGoWebDAVAclManager.h>

#import "SOGoTest.h"

@interface TestSOGoWebDAVAclManager : SOGoTest
@end

@implementation TestSOGoWebDAVAclManager

- (NSArray *) _managerPrivileges
{
  SOGoWebDAVAclManager *aclManager;
  SOGoGCSFolder *folder;
  NSArray *privileges;

  aclManager = [SOGoGCSFolder webdavAclManager];
  folder = [[SOGoGCSFolder alloc] init];
  privileges = [aclManager davPermissionsForRoles:
                          [NSArray arrayWithObject: @"Manager"]
                                      onObject: folder];
  [folder release];

  return privileges;
}

- (void) test_gcsFolderDavPrivilegesIncludeRead
{
  NSArray *privileges;
  NSDictionary *read, *readPrivilegeSet;
  BOOL hasRead, hasReadPrivilegeSet;

  privileges = [self _managerPrivileges];
  read = [NSDictionary dictionaryWithObjectsAndKeys:
                      @"read", @"method", @"DAV:", @"ns", nil];
  readPrivilegeSet = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"read-current-user-privilege-set",
                                @"method", @"DAV:", @"ns", nil];
  hasRead = [privileges containsObject: read];
  hasReadPrivilegeSet = [privileges containsObject: readPrivilegeSet];

  testWithMessage (hasRead,
                   @"{DAV:}read is missing from the privileges of a GCS"
                   @" folder (bug 6179)");
  testWithMessage (hasReadPrivilegeSet,
                   @"{DAV:}read-current-user-privilege-set is missing from"
                   @" the privileges of a GCS folder (bug 6179)");
}

- (void) test_gcsFolderDavPrivilegesIncludeWriteForWriters
{
  NSArray *privileges;
  NSDictionary *write;
  BOOL hasWrite;

  privileges = [self _managerPrivileges];
  write = [NSDictionary dictionaryWithObjectsAndKeys:
                       @"write", @"method", @"DAV:", @"ns", nil];
  hasWrite = [privileges containsObject: write];

  testWithMessage (hasWrite,
                   @"{DAV:}write is missing from the privileges of a GCS"
                   @" folder");
}

@end
