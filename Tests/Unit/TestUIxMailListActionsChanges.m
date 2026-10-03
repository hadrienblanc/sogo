/* TestUIxMailListActionsChanges.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 2, or (at your option) any
 * later version.
 *
 * This file is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <objc/runtime.h>

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>

#import <Mailer/SOGoMailFolder.h>

#import "SOGoTest.h"
#import <UI/MailerUI/UIxMailListActions.h>

@interface UIxMailListActions (Test6231Changes)
- (id <WOActionResults>) getChangesAction;
@end

#define FOLDER_CLASS_NAME @"SOGoMailFolder"

__attribute__((weak)) char __objc_class_name_SOGoSentFolder = 0;
__attribute__((weak)) char __objc_class_name_SOGoDraftsFolder = 0;
__attribute__((weak)) char __objc_class_name_SOGoMailBodyPart = 0;
__attribute__((weak)) char __objc_class_name_SOGoImageMailBodyPart = 0;


static BOOL changesThreadEnabled;
static NSString *changesCollectionTag;
static NSArray *changesSortedUids;
static NSArray *changesThreadedUids;
static NSDictionary *changesFetchResults;
static unsigned changesThreadedFetchCalls;

@interface Test6231ImapClient : NSObject
@end

@implementation Test6231ImapClient

- (NSDictionary *) fetchVanished: (uint64_t) modseq
{
  return nil;
}

- (NSDictionary *) searchWithQualifier: (id) qualifier
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithBool: YES], @"result",
                    [[changesSortedUids reverseObjectEnumerator] allObjects],
                    @"search",
                    nil];
}

@end

@interface Test6231Connection : NSObject
{
  Test6231ImapClient *imapClient;
}

- (id) client;
- (BOOL) enableExtensions: (NSArray *) extensions;
- (BOOL) selectFolder: (id) url;
- (NSArray *) fetchUIDsInURL: (NSURL *) url
                   qualifier: (id) qualifier
                sortOrdering: (id) sortOrdering;
- (NSArray *) fetchThreadedUIDsInURL: (NSURL *) url
                           qualifier: (id) qualifier
                        sortOrdering: (id) sortOrdering;
- (NSDictionary *) fetchUIDs: (NSArray *) uids
                       inURL: (NSURL *) url
                       parts: (NSArray *) parts;

@end

@implementation Test6231Connection

- (id) init
{
  if ((self = [super init]))
    imapClient = [[Test6231ImapClient alloc] init];

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

- (BOOL) enableExtensions: (NSArray *) extensions
{
  return YES;
}

- (BOOL) selectFolder: (id) url
{
  return YES;
}

- (NSArray *) fetchUIDsInURL: (NSURL *) url
                   qualifier: (id) qualifier
                sortOrdering: (id) sortOrdering
{
  return changesSortedUids;
}

- (NSArray *) fetchThreadedUIDsInURL: (NSURL *) url
                           qualifier: (id) qualifier
                        sortOrdering: (id) sortOrdering
{
  changesThreadedFetchCalls++;

  return changesThreadedUids;
}

- (NSDictionary *) fetchUIDs: (NSArray *) uids
                       inURL: (NSURL *) url
                       parts: (NSArray *) parts
{
  return changesFetchResults;
}

@end

@interface Test6231Account : NSObject
@end

@implementation Test6231Account

- (NSString *) encryption
{
  return @"plain";
}

- (NSString *) tlsVerifyMode
{
  return @"none";
}

- (id) getInboxQuota
{
  return nil;
}

@end

static Test6231Connection *changesConnection = nil;
static Test6231Account *changesAccount = nil;

static id
Imap4ConnectionIMP (id self, SEL _cmd)
{
  return changesConnection;
}

static NSString *
DavCollectionTagIMP (id self, SEL _cmd)
{
  return changesCollectionTag;
}

static unsigned int
UnseenCountIMP (id self, SEL _cmd)
{
  return 0;
}

static id
MailAccountFolderIMP (id self, SEL _cmd)
{
  return changesAccount;
}

static Class
ChangesFolderClass ()
{
  static Class folderClass = Nil;

  if (!folderClass)
    {
      folderClass = objc_allocateClassPair (NSClassFromString (FOLDER_CLASS_NAME),
                                            "Test6231MailFolder", 0);
      class_addMethod (folderClass, @selector (imap4Connection),
                       (IMP) Imap4ConnectionIMP, "@@:");
      class_addMethod (folderClass, @selector (davCollectionTag),
                       (IMP) DavCollectionTagIMP, "@@:");
      class_addMethod (folderClass, @selector (unseenCount),
                       (IMP) UnseenCountIMP, "I@:");
      class_addMethod (folderClass, @selector (mailAccountFolder),
                       (IMP) MailAccountFolderIMP, "@@:");
      objc_registerClassPair (folderClass);
    }

  return folderClass;
}

@interface Test6231UserDefaults : NSObject
@end

@implementation Test6231UserDefaults

- (BOOL) mailSortByThreads
{
  return changesThreadEnabled;
}

- (NSTimeZone *) timeZone
{
  return [NSTimeZone defaultTimeZone];
}

@end

@interface Test6231UserSettings : NSObject
{
  NSMutableDictionary *values;
}

- (id) objectForKey: (NSString *) key;
- (void) setObject: (id) value forKey: (NSString *) key;
- (BOOL) synchronize;

@end

@implementation Test6231UserSettings

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

@interface Test6231User : NSObject
{
  Test6231UserDefaults *defaults;
  Test6231UserSettings *settings;
}

- (id) userDefaults;
- (id) userSettings;
- (id) dateFormatterInContext: (id) aContext;

@end

@implementation Test6231User

- (id) init
{
  if ((self = [super init]))
    {
      defaults = [[Test6231UserDefaults alloc] init];
      settings = [[Test6231UserSettings alloc] init];
    }

  return self;
}

- (void) dealloc
{
  [defaults release];
  [settings release];
  [super dealloc];
}

- (id) userDefaults
{
  return defaults;
}

- (id) userSettings
{
  return settings;
}

- (id) dateFormatterInContext: (id) aContext
{
  return nil;
}

@end

@interface Test6231ListActions : UIxMailListActions
- (id) initWithTestContext: (WOContext *) aContext;
@end

@implementation Test6231ListActions

- (id) initWithTestContext: (WOContext *) aContext
{
  if ((self = [super initWithRequest: [aContext request]]))
    {
      context = aContext;
      sortByThread = changesThreadEnabled;
    }

  return self;
}

@end

@interface TestUIxMailListActionsChanges : SOGoTest
{
  WOContext *context;
  Test6231User *user;
  id folder;
  Test6231ListActions *actions;
  WOResponse *response;
  NSDictionary *json;
}

@end

@implementation TestUIxMailListActionsChanges

- (void) setUp
{
  Class folderClass;
  WORequest *request;
  NSData *content;

  testWithMessage ([SOGoTest loadSOGoBundle: @"Mailer"
                                 markerClass: FOLDER_CLASS_NAME],
                   @"SOGoMailFolder class unavailable (Mailer.SOGo bundle missing)");
  folderClass = ChangesFolderClass ();
  if (!folderClass)
    return;

  if (!changesConnection)
    changesConnection = [[Test6231Connection alloc] init];
  if (!changesAccount)
    changesAccount = [[Test6231Account alloc] init];

  changesThreadEnabled = YES;
  changesCollectionTag = @"110-10";
  changesSortedUids = [NSArray arrayWithObjects: [NSNumber numberWithInt: 9],
                                              [NSNumber numberWithInt: 7],
                                              [NSNumber numberWithInt: 3],
                                              [NSNumber numberWithInt: 2],
                                              [NSNumber numberWithInt: 1], nil];
  changesThreadedUids = [NSArray arrayWithObjects:
                            [NSArray arrayWithObjects: [NSNumber numberWithInt: 9],
                                                      [NSNumber numberWithInt: 7], nil],
                            [NSArray arrayWithObjects: [NSNumber numberWithInt: 1],
                                                      [NSNumber numberWithInt: 2],
                                                      [NSNumber numberWithInt: 3], nil],
                            nil];
  changesFetchResults = [NSDictionary dictionaryWithObject:
                            [NSArray arrayWithObjects:
                               [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithInt: 9], @"uid",
                                  [NSNumber numberWithInt: 110], @"modseq",
                                  [NSArray array], @"flags", nil],
                               [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithInt: 7], @"uid",
                                  [NSNumber numberWithInt: 105], @"modseq",
                                  [NSArray array], @"flags", nil],
                               nil]
                                               forKey: @"fetch"];
  changesThreadedFetchCalls = 0;

  content = [@"{\"syncToken\": \"100-5\"}" dataUsingEncoding: NSUTF8StringEncoding];
  request = [[[WORequest alloc] initWithMethod: @"POST"
                                            uri: @"/SOGo/so/test/Mail/0/folderINBOX/changes"
                                    httpVersion: @"HTTP/1.1"
                                        headers: [NSDictionary dictionaryWithObject: @"application/json"
                                                                             forKey: @"content-type"]
                                        content: content
                                      userInfo: nil] autorelease];

  context = [[WOContext alloc] initWithRequest: request];
  user = [[Test6231User alloc] init];
  folder = [[folderClass alloc] init];
  [context setClientObject: folder];
  [context setActiveUser: user];

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

- (void) _invokeChangesAction
{
  NSString *contentString;

  actions = [[Test6231ListActions alloc] initWithTestContext: context];
  response = (WOResponse *) [actions getChangesAction];
  contentString = [[[NSString alloc] initWithData: [response content]
                                         encoding: NSUTF8StringEncoding] autorelease];
  json = [contentString objectFromJSONString];
}

- (NSArray *) expectedThreadedUids
{
  return [NSArray arrayWithObjects:
            [NSArray arrayWithObjects: @"uid", @"level", @"first", nil],
            [NSArray arrayWithObjects: [NSNumber numberWithInt: 9],
                                      [NSNumber numberWithInt: 0],
                                      [NSNumber numberWithInt: 1], nil],
            [NSArray arrayWithObjects: [NSNumber numberWithInt: 7],
                                      [NSNumber numberWithInt: 1],
                                      [NSNumber numberWithInt: 0], nil],
            [NSArray arrayWithObjects: [NSNumber numberWithInt: 3],
                                      [NSNumber numberWithInt: 0],
                                      [NSNumber numberWithInt: 1], nil],
            [NSArray arrayWithObjects: [NSNumber numberWithInt: 2],
                                      [NSNumber numberWithInt: 1],
                                      [NSNumber numberWithInt: 0], nil],
            [NSArray arrayWithObjects: [NSNumber numberWithInt: 1],
                                      [NSNumber numberWithInt: 2],
                                      [NSNumber numberWithInt: 0], nil],
            nil];
}

- (void) test_threadedChangesReturnFullFolderState
{
  [self _invokeChangesAction];

  test ([response status] == 200);
  testWithMessage ([json objectForKey: @"uids"] != nil,
                   @"a threaded changes response must carry the full uids list (bug 6231)");
  testEquals ([json objectForKey: @"uids"], [self expectedThreadedUids]);
  testWithMessage ([[json objectForKey: @"threaded"] boolValue],
                   @"the resync payload must announce threading");
  testWithMessage ([json objectForKey: @"headers"] != nil,
                   @"the resync payload must carry the message headers");
  testEquals ([json objectForKey: @"syncToken"], @"110-10");
  testWithMessage ([json objectForKey: @"changed"] == nil,
                   @"a threaded changes response must not carry flat changed uids");
  testWithMessage ([json objectForKey: @"deleted"] == nil,
                   @"a threaded changes response must not carry flat deleted uids");
  test (changesThreadedFetchCalls == 1);
}

- (void) test_nonThreadedChangesKeepIncrementalResponse
{
  changesThreadEnabled = NO;

  [self _invokeChangesAction];

  test ([response status] == 200);
  testWithMessage ([json objectForKey: @"uids"] == nil,
                   @"a non-threaded changes response must stay incremental");
  testEquals ([json objectForKey: @"changed"],
              ([NSArray arrayWithObjects: @"9", @"7", nil]));
  testEquals ([json objectForKey: @"deleted"], [NSArray array]);
  testEquals ([json objectForKey: @"syncToken"], @"110-10");
  test (changesThreadedFetchCalls == 0);
}

- (void) test_unchangedFolderReturnsSyncTokenOnly
{
  changesCollectionTag = @"100-5";

  [self _invokeChangesAction];

  test ([response status] == 200);
  test ([json count] == 1);
  testEquals ([json objectForKey: @"syncToken"], @"100-5");
  testWithMessage ([json objectForKey: @"uids"] == nil,
                   @"an unchanged folder must not trigger a resync");
}

@end
