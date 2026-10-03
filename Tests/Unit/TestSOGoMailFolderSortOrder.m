/* TestSOGoMailFolderSortOrder.m - this file is part of SOGo
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
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#import <objc/runtime.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <Mailer/SOGoMailFolder.h>

#import "SOGoTest.h"

#define FOLDER_CLASS_NAME @"SOGoMailFolder"

static NSArray *writeOrderUids;
static NSArray *sortedUids;
static NSArray *threadedUids;
static unsigned searchCalls;
static unsigned sortCalls;
static unsigned threadedCalls;

@interface Test6086ImapClient : NSObject
@end

@implementation Test6086ImapClient

- (NSDictionary *) searchWithQualifier: (id) qualifier
{
  searchCalls++;

  return [NSDictionary dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithBool: YES], @"result",
                    writeOrderUids, @"search",
                    nil];
}

@end

@interface Test6086Connection : NSObject
{
  Test6086ImapClient *imapClient;
}
@end

@implementation Test6086Connection

- (id) init
{
  if ((self = [super init]))
    imapClient = [[Test6086ImapClient alloc] init];

  return self;
}

- (void) dealloc
{
  [imapClient release];
  [super dealloc];
}

- (id) client
{
  return imapClient;
}

- (BOOL) selectFolder: (id) url
{
  return YES;
}

- (NSArray *) fetchUIDsInURL: (NSURL *) url
                   qualifier: (id) qualifier
                sortOrdering: (id) sortOrdering
{
  sortCalls++;

  return sortedUids;
}

- (NSArray *) fetchThreadedUIDsInURL: (NSURL *) url
                           qualifier: (id) qualifier
                        sortOrdering: (id) sortOrdering
{
  threadedCalls++;

  return threadedUids;
}

@end

static Test6086Connection *connection6086 = nil;

static id
Imap4ConnectionIMP (id self, SEL _cmd)
{
  return connection6086;
}

static NSURL *
Imap4URLIMP (id self, SEL _cmd)
{
  return [NSURL URLWithString: @"imap://127.0.0.1:143/folderINBOX"];
}

static Class
SortOrderFolderClass ()
{
  static Class folderClass = Nil;

  if (!folderClass)
    {
      folderClass = objc_allocateClassPair (NSClassFromString (FOLDER_CLASS_NAME),
                                            "SortOrder6086Folder", 0);
      class_addMethod (folderClass, @selector (imap4Connection),
                       (IMP) Imap4ConnectionIMP, "@@:");
      class_addMethod (folderClass, @selector (imap4URL),
                       (IMP) Imap4URLIMP, "@@:");
      objc_registerClassPair (folderClass);
    }

  return folderClass;
}

@interface TestSOGoMailFolderSortOrder : SOGoTest
{
  id folder;
}
@end

@implementation TestSOGoMailFolderSortOrder

- (void) setUp
{
  Class folderClass;

  testWithMessage ([SOGoTest loadSOGoBundle: @"Mailer"
                                 markerClass: FOLDER_CLASS_NAME],
                   @"SOGoMailFolder class unavailable (Mailer.SOGo bundle missing)");
  folderClass = SortOrderFolderClass ();
  if (!folderClass)
    return;

  if (!connection6086)
    connection6086 = [[Test6086Connection alloc] init];

  searchCalls = 0;
  sortCalls = 0;
  threadedCalls = 0;
  writeOrderUids = nil;
  sortedUids = nil;
  threadedUids = nil;

  folder = [[folderClass alloc] init];
}

- (void) tearDown
{
  [folder release];
  [super tearDown];
}

- (void) test_arrivalReturnsUIDsInWriteOrder
{
  NSArray *uids;

  writeOrderUids = [NSArray arrayWithObjects:
                              [NSNumber numberWithInt: 9],
                              [NSNumber numberWithInt: 10],
                              [NSNumber numberWithInt: 11], nil];
  sortedUids = [NSArray arrayWithObjects:
                          [NSNumber numberWithInt: 10],
                          [NSNumber numberWithInt: 9],
                          [NSNumber numberWithInt: 11], nil];

  uids = [folder fetchUIDsMatchingQualifier: nil
                               sortOrdering: @"ARRIVAL"];

  testEquals (uids, writeOrderUids);
  test (searchCalls == 1);
  test (sortCalls == 0);
}

- (void) test_reverseArrivalReturnsUIDsInReverseWriteOrder
{
  NSArray *uids, *expected;

  writeOrderUids = [NSArray arrayWithObjects:
                              [NSNumber numberWithInt: 9],
                              [NSNumber numberWithInt: 10],
                              [NSNumber numberWithInt: 11], nil];

  uids = [folder fetchUIDsMatchingQualifier: nil
                               sortOrdering: @"REVERSE ARRIVAL"];

  expected = [NSArray arrayWithObjects:
                       [NSNumber numberWithInt: 11],
                       [NSNumber numberWithInt: 10],
                       [NSNumber numberWithInt: 9], nil];
  testEquals (uids, expected);
  test (searchCalls == 1);
  test (sortCalls == 0);
}

- (void) test_arrivalOrderingIsCaseInsensitive
{
  NSArray *uids, *expected;

  writeOrderUids = [NSArray arrayWithObjects:
                              [NSNumber numberWithInt: 9],
                              [NSNumber numberWithInt: 10],
                              [NSNumber numberWithInt: 11], nil];

  uids = [folder fetchUIDsMatchingQualifier: nil
                               sortOrdering: @"reverse arrival"];

  expected = [NSArray arrayWithObjects:
                       [NSNumber numberWithInt: 11],
                       [NSNumber numberWithInt: 10],
                       [NSNumber numberWithInt: 9], nil];
  testEquals (uids, expected);
  test (sortCalls == 0);
}

- (void) test_dateOrderingStillUsesIMAPSort
{
  NSArray *uids;

  sortedUids = [NSArray arrayWithObjects:
                          [NSNumber numberWithInt: 9],
                          [NSNumber numberWithInt: 11],
                          [NSNumber numberWithInt: 10], nil];

  uids = [folder fetchUIDsMatchingQualifier: nil
                               sortOrdering: @"REVERSE DATE"];

  testEquals (uids, sortedUids);
  test (searchCalls == 0);
  test (sortCalls == 1);
}

- (void) test_nilOrderingStillUsesIMAPSort
{
  NSArray *uids;

  sortedUids = [NSArray arrayWithObjects:
                          [NSNumber numberWithInt: 9],
                          [NSNumber numberWithInt: 10],
                          [NSNumber numberWithInt: 11], nil];

  uids = [folder fetchUIDsMatchingQualifier: nil
                               sortOrdering: nil];

  testEquals (uids, sortedUids);
  test (searchCalls == 0);
  test (sortCalls == 1);
}

- (void) test_threadedArrivalOrdersThreadsByWriteOrder
{
  NSArray *uids, *expected;

  threadedUids = [NSArray arrayWithObjects:
                             [NSArray arrayWithObjects:
                                         [NSNumber numberWithInt: 11], nil],
                             [NSArray arrayWithObjects:
                                         [NSNumber numberWithInt: 10],
                                         [NSNumber numberWithInt: 9], nil],
                             nil];

  uids = [folder fetchUIDsMatchingQualifier: nil
                               sortOrdering: @"ARRIVAL"
                                   threaded: YES];

  expected = [NSArray arrayWithObjects:
                      [NSArray arrayWithObjects:
                                  [NSNumber numberWithInt: 9],
                                  [NSNumber numberWithInt: 10], nil],
                      [NSArray arrayWithObjects:
                                  [NSNumber numberWithInt: 11], nil],
                      nil];
  testEquals (uids, expected);
  test (threadedCalls == 1);
  test (searchCalls == 0);
  test (sortCalls == 0);
}

- (void) test_threadedReverseArrivalReversesThreadsAndMembers
{
  NSArray *uids, *expected;

  threadedUids = [NSArray arrayWithObjects:
                             [NSArray arrayWithObjects:
                                         [NSNumber numberWithInt: 11], nil],
                             [NSArray arrayWithObjects:
                                         [NSNumber numberWithInt: 10],
                                         [NSNumber numberWithInt: 9], nil],
                             nil];

  uids = [folder fetchUIDsMatchingQualifier: nil
                               sortOrdering: @"REVERSE ARRIVAL"
                                   threaded: YES];

  expected = [NSArray arrayWithObjects:
                      [NSArray arrayWithObjects:
                                  [NSNumber numberWithInt: 11], nil],
                      [NSArray arrayWithObjects:
                                  [NSNumber numberWithInt: 10],
                                  [NSNumber numberWithInt: 9], nil],
                      nil];
  testEquals (uids, expected);
  test (threadedCalls == 1);
}

- (void) test_threadedArrivalWithFlatFallbackSortsNumerically
{
  NSArray *uids, *expected;

  threadedUids = [NSArray arrayWithObjects:
                             [NSNumber numberWithInt: 11],
                             [NSNumber numberWithInt: 9],
                             [NSNumber numberWithInt: 10], nil];

  uids = [folder fetchUIDsMatchingQualifier: nil
                               sortOrdering: @"ARRIVAL"
                                   threaded: YES];

  expected = [NSArray arrayWithObjects:
                      [NSNumber numberWithInt: 9],
                      [NSNumber numberWithInt: 10],
                      [NSNumber numberWithInt: 11], nil];
  testEquals (uids, expected);
  test (threadedCalls == 1);
}

@end
