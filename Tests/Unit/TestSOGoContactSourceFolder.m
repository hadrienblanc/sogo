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

#import <DOM/DOMDocument.h>
#import <DOM/DOMElement.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOResponse.h>

#import "SOGoTest.h"

@interface NSObject (ContactSourceFolderLookupDeclaration)
- (id) lookupName: (NSString *) objectName
         inContext: (id) lookupContext
           acquire: (BOOL) acquire;
- (NSEnumerator *) davChildKeysInContext: (id) aContext;
- (void) _appendComponentProperties: (NSArray *) properties
                       matchingURLs: (id) refs
                         toResponse: (id) response;
@end

@interface Test6014Container : NSObject
@end

@implementation Test6014Container

- (NSString *) davURLAsString
{
  return @"/SOGo/dav/user/Contacts/";
}

@end

@interface Test6014LegacySource : NSObject
{
  NSMutableDictionary *records;
  NSArray *entryIDs;
  int singleLookupCount;
}

+ (Test6014LegacySource *) sourceWithEntryIDs: (NSArray *) newEntryIDs
                                      records: (NSDictionary *) newRecords;

- (int) singleLookupCount;

@end

@implementation Test6014LegacySource

+ (Test6014LegacySource *) sourceWithEntryIDs: (NSArray *) newEntryIDs
                                      records: (NSDictionary *) newRecords
{
  Test6014LegacySource *source;

  source = [[Test6014LegacySource alloc] init];
  source->entryIDs = [newEntryIDs retain];
  source->records = [newRecords retain];

  return [source autorelease];
}

- (id) init
{
  if ((self = [super init]))
    singleLookupCount = 0;

  return self;
}

- (void) dealloc
{
  [entryIDs release];
  [records release];
  [super dealloc];
}

- (int) singleLookupCount
{
  return singleLookupCount;
}

- (NSArray *) allEntryIDsVisibleFromDomain: (NSString *) domain
{
  return entryIDs;
}

- (NSDictionary *) lookupContactEntry: (NSString *) theID
                              inDomain: (NSString *) domain
{
  singleLookupCount++;

  return [records objectForKey: theID];
}

- (NSDictionary *) lookupContactEntry: (NSString *) theID
                              inDomain: (NSString *) domain
		       usingConnection: (id) connection
{
  return [self lookupContactEntry: theID  inDomain: domain];
}

- (id) connection
{
  return self;
}

- (void) releaseConnection: (id) connection
{
}

@end

@interface Test6014Source : Test6014LegacySource
{
  NSMutableArray *batchCalls;
}

+ (Test6014Source *) sourceWithEntryIDs: (NSArray *) newEntryIDs
                               records: (NSDictionary *) newRecords;

- (NSArray *) batchCalls;

@end

@implementation Test6014Source

+ (Test6014Source *) sourceWithEntryIDs: (NSArray *) newEntryIDs
                               records: (NSDictionary *) newRecords
{
  Test6014Source *source;

  source = [[Test6014Source alloc] init];
  source->entryIDs = [newEntryIDs retain];
  source->records = [newRecords retain];

  return [source autorelease];
}

- (id) init
{
  if ((self = [super init]))
    batchCalls = [NSMutableArray new];

  return self;
}

- (void) dealloc
{
  [batchCalls release];
  [super dealloc];
}

- (NSArray *) batchCalls
{
  return batchCalls;
}

- (NSDictionary *) lookupContactEntriesForIDs: (NSArray *) theIDs
                                     inDomain: (NSString *) domain
                              usingConnection: (id) connection
{
  [batchCalls addObject: theIDs];

  return records;
}

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

- (NSDictionary *) _record6014ForUID: (NSString *) uid
                               andCN: (NSString *) cn
{
  NSMutableDictionary *record;

  record = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                              uid, @"c_uid",
                              uid, @"c_name",
                              cn, @"c_cn",
                              cn, @"cn",
                              uid, @"uid",
                              [NSString stringWithFormat: @"%@@example.com", uid],
                              @"mail",
                              [NSArray arrayWithObject:
                                [NSString stringWithFormat: @"%@@example.com", uid]],
                              @"c_emails",
                              [NSNumber numberWithBool: YES], @"canAuthenticate",
                              nil];

  return record;
}

- (id) _folder6014WithSource: (Test6014Source *) source
{
  Class folderClass;
  Test6014Container *container;
  id folder;

  folderClass = [self _folderClass];
  container = [[[Test6014Container alloc] init] autorelease];
  folder = [folderClass folderWithName: @"test-6014-gal"
                         andDisplayName: @"Test 6014 GAL"
                             inContainer: container];
  [folder setSource: source];

  return [folder autorelease];
}

- (void) test_davChildKeysPrefetchesRecordsInOneBatch
{
  Test6014Source *source;
  id folder, obj;
  NSMutableArray *keys;
  NSString *key;
  NSEnumerator *e;

  source = [Test6014Source
             sourceWithEntryIDs: [NSArray arrayWithObjects: @"alice", @"bob", nil]
                         records: [NSDictionary dictionaryWithObjectsAndKeys:
                                     [self _record6014ForUID: @"alice" andCN: @"Alice"],
                                     @"alice",
                                      [self _record6014ForUID: @"bob" andCN: @"Bob"],
                                      @"bob",
                                      nil]];
  folder = [self _folder6014WithSource: source];

  keys = [NSMutableArray array];
  e = [folder davChildKeysInContext: nil];
  while ((key = [e nextObject]))
    [keys addObject: key];

  testEquals([keys objectAtIndex: 0], @"alice");
  testEquals([keys objectAtIndex: 1], @"bob");
  testEquals([NSNumber numberWithInt: [[source batchCalls] count]],
             [NSNumber numberWithInt: 1]);
  testEquals([[[source batchCalls] objectAtIndex: 0] objectAtIndex: 0],
             @"alice");
  testEquals([[[source batchCalls] objectAtIndex: 0] objectAtIndex: 1],
             @"bob");

  obj = [folder lookupName: @"alice" inContext: nil acquire: NO];
  testWithMessage ([obj respondsToSelector: @selector (ldifRecord)],
                    @"a prefetched entry must be resolved as a contact");
  testEquals([[obj ldifRecord] objectForKey: @"c_cn"], @"Alice");
  testEquals([NSNumber numberWithInt: [source singleLookupCount]],
             [NSNumber numberWithInt: 0]);
}

- (void) test_davChildKeysWithoutBatchSupportFallsBackToSingleLookups
{
  Test6014LegacySource *source;
  id folder, obj;

  source = [Test6014LegacySource
             sourceWithEntryIDs: [NSArray arrayWithObject: @"alice"]
                         records: [NSDictionary dictionaryWithObject:
                                     [self _record6014ForUID: @"alice" andCN: @"Alice"]
                                                        forKey: @"alice"]];
  folder = [self _folder6014WithSource: source];

  testWithMessage ([[folder davChildKeysInContext: nil] nextObject] != nil,
                    @"child keys must still be enumerated without batch"
                    @" support on the source");
  testEquals([NSNumber numberWithInt: [source singleLookupCount]],
             [NSNumber numberWithInt: 0]);

  obj = [folder lookupName: @"alice" inContext: nil acquire: NO];
  testWithMessage ([obj respondsToSelector: @selector (ldifRecord)],
                    @"an entry must be resolved through a single lookup");
  testEquals([[obj ldifRecord] objectForKey: @"c_cn"], @"Alice");
  testEquals([NSNumber numberWithInt: [source singleLookupCount]],
             [NSNumber numberWithInt: 1]);
}

- (void) test_multigetFetchesEntriesThroughTheBatchLookup
{
  Test6014Source *source;
  NGDOMDocument *document;
  WOResponse *response;
  NSString *content;
  id folder;

  source = [Test6014Source
             sourceWithEntryIDs: [NSArray arrayWithObjects: @"alice", @"bob", nil]
                         records: [NSDictionary dictionaryWithObjectsAndKeys:
                                     [self _record6014ForUID: @"alice" andCN: @"Alice"],
                                     @"alice",
                                      [self _record6014ForUID: @"bob" andCN: @"Bob"],
                                      @"bob",
                                      nil]];
  folder = [self _folder6014WithSource: source];

  document = [NGDOMDocument documentFromString:
               @"<D:addressbook-multiget xmlns:D=\"DAV:\">"
               @"<D:prop><D:getetag/></D:prop>"
               @"<D:href>/SOGo/dav/user/Contacts/test-6014-gal/alice</D:href>"
               @"<D:href>/SOGo/dav/user/Contacts/test-6014-gal/ghost</D:href>"
               @"</D:addressbook-multiget>"];

  response = [[WOResponse alloc] init];
  [folder _appendComponentProperties: [NSArray arrayWithObject: @"{DAV:}getetag"]
                        matchingURLs: [[document documentElement]
                                        getElementsByTagName: @"href"]
                          toResponse: response];
  content = [response contentAsString];
  [response release];

  testEquals([NSNumber numberWithInt: [[source batchCalls] count]],
             [NSNumber numberWithInt: 1]);
  testEquals([[[source batchCalls] objectAtIndex: 0] objectAtIndex: 0],
             @"alice");
  testEquals([[[source batchCalls] objectAtIndex: 0] objectAtIndex: 1],
             @"ghost");
  testEquals([NSNumber numberWithInt: [source singleLookupCount]],
             [NSNumber numberWithInt: 0]);
  testWithMessage ([content rangeOfString:
                     @"/SOGo/dav/user/Contacts/test-6014-gal/alice</D:href>"]
                     .location != NSNotFound,
                    @"the existing entry must be rendered under its href");
  testWithMessage ([content rangeOfString: @"<D:getetag>hash"].location
                     != NSNotFound,
                    @"the existing entry must render its etag");
  testWithMessage ([content rangeOfString: @"HTTP/1.1 404 Not Found"].location
                     != NSNotFound,
                    @"a missing entry must be reported as HTTP 404");
}

- (void) test_multigetWithoutBatchSupportFallsBackToSingleLookups
{
  Test6014LegacySource *source;
  NGDOMDocument *document;
  WOResponse *response;
  NSString *content;
  id folder;

  source = [Test6014LegacySource
             sourceWithEntryIDs: [NSArray arrayWithObject: @"alice"]
                         records: [NSDictionary dictionaryWithObject:
                                     [self _record6014ForUID: @"alice" andCN: @"Alice"]
                                                        forKey: @"alice"]];
  folder = [self _folder6014WithSource: source];

  document = [NGDOMDocument documentFromString:
               @"<D:addressbook-multiget xmlns:D=\"DAV:\">"
               @"<D:prop><D:getetag/></D:prop>"
               @"<D:href>/SOGo/dav/user/Contacts/test-6014-gal/alice</D:href>"
               @"</D:addressbook-multiget>"];

  response = [[WOResponse alloc] init];
  [folder _appendComponentProperties: [NSArray arrayWithObject: @"{DAV:}getetag"]
                        matchingURLs: [[document documentElement]
                                        getElementsByTagName: @"href"]
                          toResponse: response];
  content = [response contentAsString];
  [response release];

  testEquals([NSNumber numberWithInt: [source singleLookupCount]],
             [NSNumber numberWithInt: 1]);
  testWithMessage ([content rangeOfString: @"<D:getetag>hash"].location
                     != NSNotFound,
                    @"the existing entry must render its etag");
}

@end
