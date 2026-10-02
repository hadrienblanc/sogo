/* TestSOGoContactSourceFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/NSException+HTTP.h>

#import "SOGoTest.h"

@interface NSObject (ContactSourceFolderLookupDeclaration)
- (id) lookupName: (NSString *) objectName
        inContext: (id) lookupContext
          acquire: (BOOL) acquire;
@end

@interface TestSOGoContactSourceFolder : SOGoTest
@end

static BOOL
LoadContactsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Contacts"
                       markerClass: @"SOGoContactSourceFolder"];
}

@implementation TestSOGoContactSourceFolder

- (Class) _folderClass
{
  Class folderClass;

  testWithMessage (LoadContactsBundle (),
                   @"Contacts bundle could not be loaded");

  folderClass = NSClassFromString (@"SOGoContactSourceFolder");
  testWithMessage (folderClass != Nil,
                   @"SOGoContactSourceFolder class could not be found");

  return folderClass;
}

- (NSMutableDictionary *) _childRecordsOfFolder: (id) folder
{
  NSMutableDictionary *childRecords;

  childRecords = [folder valueForKey: @"childRecords"];
  testWithMessage ([childRecords isKindOfClass: [NSMutableDictionary class]],
                   @"childRecords could not be read on the source folder");

  return childRecords;
}

- (void) test_lookupNameWithEmptyNameReturnsHTTP404
{
  Class folderClass;
  id folder;
  NSMutableDictionary *childRecords;
  id obj;

  folderClass = [self _folderClass];

  folder = [[folderClass alloc] init];
  childRecords = [self _childRecordsOfFolder: folder];
  [childRecords setObject: [NSDictionary dictionaryWithObject: @"someone@example.com"
                                                       forKey: @"mail"]
                   forKey: @""];
  obj = [folder lookupName: @"" inContext: nil acquire: NO];
  [folder release];

  testWithMessage ([obj isKindOfClass: [NSException class]],
                   @"an empty-named cached record must not be instantiated as"
                   @" a contact (bug 6161)");
  testWithMessage ([obj httpStatus] == 404,
                   @"an empty lookup name must be reported as HTTP 404");
}

- (void) test_lookupNameWithUnknownNameReturnsHTTP404
{
  Class folderClass;
  id folder;
  id obj;

  folderClass = [self _folderClass];

  folder = [[folderClass alloc] init];
  obj = [folder lookupName: @"nosuchcontact" inContext: nil acquire: NO];
  [folder release];

  testWithMessage ([obj isKindOfClass: [NSException class]]
                   && [obj httpStatus] == 404,
                   @"an unknown lookup name must be reported as HTTP 404");
}

@end
