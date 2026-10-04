/* TestSQLSourceLookupContactEntries.m - this file is part of SOGo
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
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

#import <SOGo/SQLSource.h>

#import "SOGoTest.h"

@interface Test6014Channel : NSObject
{
  NSMutableArray *queries;
  NSMutableArray *pendingResults;
  NSArray *currentRows;
  unsigned int fetchIndex;
}

- (NSArray *) queries;
- (void) enqueueRows: (NSArray *) rows;
- (NSException *) evaluateExpressionX: (NSString *) sql;
- (NSArray *) describeResults: (BOOL) flag;
- (NSMutableDictionary *) fetchAttributes: (NSArray *) attributes
                                 withZone: (NSZone *) zone;
- (void) cancelFetch;

@end

@implementation Test6014Channel

- (id) init
{
  if ((self = [super init]))
    {
      queries = [NSMutableArray new];
      pendingResults = [NSMutableArray new];
      currentRows = [NSArray array];
    }

  return self;
}

- (void) dealloc
{
  [queries release];
  [pendingResults release];
  [currentRows release];
  [super dealloc];
}

- (NSArray *) queries
{
  return queries;
}

- (void) enqueueRows: (NSArray *) rows
{
  [pendingResults addObject: rows];
}

- (void) reset
{
  [queries removeAllObjects];
  [pendingResults removeAllObjects];
  ASSIGN (currentRows, [NSArray array]);
  fetchIndex = 0;
}

- (NSException *) evaluateExpressionX: (NSString *) sql
{
  [queries addObject: sql];
  if ([pendingResults count] > 0)
    {
      ASSIGN (currentRows, [pendingResults objectAtIndex: 0]);
      [pendingResults removeObjectAtIndex: 0];
    }
  else
    ASSIGN (currentRows, [NSArray array]);
  fetchIndex = 0;

  return nil;
}

- (NSArray *) describeResults: (BOOL) flag
{
  return [NSArray array];
}

- (NSMutableDictionary *) fetchAttributes: (NSArray *) attributes
                                 withZone: (NSZone *) zone
{
  if (fetchIndex < [currentRows count])
    return [currentRows objectAtIndex: fetchIndex++];

  return nil;
}

- (void) cancelFetch
{
  fetchIndex = [currentRows count];
}

@end

@interface TestSQLSourceLookupContactEntries : SOGoTest
{
  SQLSource *source;
  Test6014Channel *channel;
}
@end

@implementation TestSQLSourceLookupContactEntries

- (id) init
{
  NSDictionary *udSource;

  if ((self = [super init]))
    {
      udSource = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"test-6014-gal", @"id",
                             @"mysql://127.0.0.1/sogo/test_6014_gal", @"viewURL",
                             nil];
      source = [[SQLSource sourceFromUDSource: udSource  inDomain: nil] retain];
      channel = [Test6014Channel new];
    }

  return self;
}

- (void) dealloc
{
  [source release];
  [channel release];

  [super dealloc];
}

- (void) setUp
{
  [channel reset];
}

- (NSDictionary *) rowForUID: (NSString *) uid
                       andCN: (NSString *) cn
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
                           uid, @"c_uid",
                           uid, @"c_name",
                           cn, @"c_cn",
                           [NSString stringWithFormat: @"%@@example.com", uid],
                           @"mail",
                           nil];
}

- (void) test_batchLookupFetchesAllEntriesInASingleQuery
{
  NSDictionary *records;

  [channel enqueueRows: [NSArray arrayWithObjects:
                                  [self rowForUID: @"alice" andCN: @"Alice"],
                                  [self rowForUID: @"bob" andCN: @"Bob"],
                                  nil]];
  records = [source lookupContactEntriesForIDs:
                       [NSArray arrayWithObjects: @"alice", @"bob", @"ghost", nil]
                                       inDomain: nil
                                usingConnection: channel];

  testEquals([NSNumber numberWithInt: [[channel queries] count]],
             [NSNumber numberWithInt: 1]);
  testEquals([NSNumber numberWithInt: [records count]],
             [NSNumber numberWithInt: 2]);
  testWithMessage ([records objectForKey: @"alice"] != nil,
                   @"a requested entry present in the table must be returned");
  testWithMessage ([records objectForKey: @"ghost"] == nil,
                   @"a requested entry missing from the table must be absent");
  testEquals([[records objectForKey: @"alice"] objectForKey: @"cn"],
             @"Alice");
  testEquals([[records objectForKey: @"alice"] objectForKey: @"uid"],
             @"alice");
  testEquals([[records objectForKey: @"alice"] objectForKey: @"c_domain"],
             @"");
  testEquals([[[records objectForKey: @"alice"] objectForKey: @"c_emails"] objectAtIndex: 0],
             @"alice@example.com");
  test([[[records objectForKey: @"alice"] objectForKey: @"canAuthenticate"]
         boolValue]);
  testEquals([[records objectForKey: @"alice"] objectForKey: @"source"],
             source);
  testEquals([[records objectForKey: @"bob"] objectForKey: @"cn"],
             @"Bob");
}

- (void) test_batchLookupSelectsFromTheSourceTableOnCUID
{
  [channel enqueueRows: [NSArray arrayWithObject:
                                  [self rowForUID: @"alice" andCN: @"Alice"]]];
  [source lookupContactEntriesForIDs:
             [NSArray arrayWithObject: @"alice"]
                             inDomain: nil
                      usingConnection: channel];

  testWithMessage ([[[channel queries] objectAtIndex: 0]
                     hasPrefix: @"SELECT * FROM test_6014_gal WHERE"],
                   @"the batch lookup must select every column of the source"
                   @" table");
  testWithMessage ([[[channel queries] objectAtIndex: 0]
                     rangeOfString: @"c_uid = 'alice'"].location != NSNotFound,
                   @"the batch lookup must match entries on c_uid");
}

- (void) test_batchLookupSplitsLargeIDSetsIntoChunks
{
  NSMutableArray *ids;
  int i;

  ids = [NSMutableArray array];
  for (i = 0; i < 1201; i++)
    [ids addObject: [NSString stringWithFormat: @"user%d", i]];

  [source lookupContactEntriesForIDs: ids
                            inDomain: nil
                     usingConnection: channel];

  testEquals([NSNumber numberWithInt: [[channel queries] count]],
             [NSNumber numberWithInt: 3]);
}

- (void) test_batchLookupEscapesQuotesInIDs
{
  NSDictionary *records;

  [channel enqueueRows: [NSArray arrayWithObject:
                                  [self rowForUID: @"o'brien" andCN: @"O'Brien"]]];
  records = [source lookupContactEntriesForIDs:
                       [NSArray arrayWithObject: @"o'brien"]
                                       inDomain: nil
                                usingConnection: channel];

  testEquals([NSNumber numberWithInt: [records count]],
             [NSNumber numberWithInt: 1]);
  testWithMessage ([records objectForKey: @"o'brien"] != nil,
                   @"an entry whose uid contains a quote must be returned");
  testWithMessage ([[[channel queries] objectAtIndex: 0]
                     rangeOfString: @"o''brien"].location != NSNotFound,
                   @"quotes in ids must be escaped in the generated SQL");
}

- (void) test_batchLookupKeepsFirstRecordOnDuplicateUIDs
{
  NSDictionary *records;

  [channel enqueueRows: [NSArray arrayWithObjects:
                                  [self rowForUID: @"dup" andCN: @"First"],
                                  [self rowForUID: @"dup" andCN: @"Second"],
                                  nil]];
  records = [source lookupContactEntriesForIDs:
                       [NSArray arrayWithObject: @"dup"]
                                       inDomain: nil
                                usingConnection: channel];

  testEquals([NSNumber numberWithInt: [records count]],
             [NSNumber numberWithInt: 1]);
  testEquals([[records objectForKey: @"dup"] objectForKey: @"cn"],
             @"First");
}

- (void) test_batchLookupMarksCanAuthenticateFromTheAuthFilter
{
  NSDictionary *records;
  NSDictionary *udSource;
  SQLSource *filteredSource;

  udSource = [NSDictionary dictionaryWithObjectsAndKeys:
                         @"test-6014-gal-auth", @"id",
                         @"mysql://127.0.0.1/sogo/test_6014_gal_auth",
                         @"viewURL",
                         @"c_cn = 'Alice'", @"authenticationFilter",
                         nil];
  filteredSource = [[SQLSource sourceFromUDSource: udSource  inDomain: nil] retain];

  [channel enqueueRows: [NSArray arrayWithObjects:
                                  [self rowForUID: @"alice" andCN: @"Alice"],
                                  [self rowForUID: @"bob" andCN: @"Bob"],
                                  nil]];
  [channel enqueueRows: [NSArray arrayWithObject:
                                  [NSDictionary dictionaryWithObject: @"alice"
                                                              forKey: @"c_uid"]]];
  records = [filteredSource lookupContactEntriesForIDs:
                          [NSArray arrayWithObjects: @"alice", @"bob", nil]
                                          inDomain: nil
                                   usingConnection: channel];

  testEquals([NSNumber numberWithInt: [[channel queries] count]],
             [NSNumber numberWithInt: 2]);
  test([[[records objectForKey: @"alice"] objectForKey: @"canAuthenticate"]
         boolValue]);
  test(![[[records objectForKey: @"bob"] objectForKey: @"canAuthenticate"]
          boolValue]);

  [filteredSource release];
}

@end
