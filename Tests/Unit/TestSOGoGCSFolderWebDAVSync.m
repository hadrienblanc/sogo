/* TestSOGoGCSFolderWebDAVSync.m - this file is part of SOGo
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

#import <EOControl/EOControl.h>

#import <SOGo/SOGoGCSFolder.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>

#import <Contacts/SOGoContactGCSFolder.h>

#import "SOGoTest.h"

@class WOContext;

@interface TestSyncUserSettings : SOGoUserSettings
{
  NSMutableDictionary *values;
}
@end

@implementation TestSyncUserSettings

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

@interface TestSyncUser : SOGoUser
{
  TestSyncUserSettings *settingsValue;
}
+ (TestSyncUser *) testUserWithLogin: (NSString *) login;
@end

@implementation TestSyncUser

+ (TestSyncUser *) testUserWithLogin: (NSString *) login
{
  TestSyncUser *user;

  user = [[TestSyncUser alloc] initWithLogin: login
					roles: nil
					trust: YES];
  [user autorelease];
  user->settingsValue = [TestSyncUserSettings new];

  return user;
}

- (void) dealloc
{
  [settingsValue release];
  [super dealloc];
}

- (TestSyncUserSettings *) settings
{
  return settingsValue;
}

- (TestSyncUserSettings *) userSettings
{
  return settingsValue;
}

- (NSString *) domain
{
  return @"example.com";
}

@end

@interface TestSyncRequest : NSObject
{
  BOOL thunderbirdValue;
}
- (void) setThunderbird: (BOOL) flag;
@end

@implementation TestSyncRequest

- (void) setThunderbird: (BOOL) flag
{
  thunderbirdValue = flag;
}

- (BOOL) isThunderbird
{
  return thunderbirdValue;
}

@end

@interface TestSyncContext : NSObject
{
  TestSyncUser *userValue;
  TestSyncRequest *requestValue;
}
+ (TestSyncContext *) contextWithUser: (TestSyncUser *) user
			      request: (TestSyncRequest *) request;
@end

@implementation TestSyncContext

+ (TestSyncContext *) contextWithUser: (TestSyncUser *) user
			      request: (TestSyncRequest *) request
{
  TestSyncContext *context;

  context = [[TestSyncContext new] autorelease];
  context->userValue = [user retain];
  context->requestValue = [request retain];

  return context;
}

- (void) dealloc
{
  [userValue release];
  [requestValue release];
  [super dealloc];
}

- (TestSyncUser *) activeUser
{
  return userValue;
}

- (TestSyncRequest *) request
{
  return requestValue;
}

@end

@interface TestSyncOCSFolder : NSObject
{
  NSMutableArray *fetchesValue;
}
- (NSArray *) recordedFetches;
@end

@implementation TestSyncOCSFolder

- (id) init
{
  if ((self = [super init]))
    fetchesValue = [[NSMutableArray alloc] init];

  return self;
}

- (void) dealloc
{
  [fetchesValue release];
  [super dealloc];
}

- (NSArray *) recordedFetches
{
  return fetchesValue;
}

- (NSString *) folderName
{
  return @"Contact";
}

- (NSArray *) fetchFields: (NSArray *) fields
	 fetchSpecification: (EOFetchSpecification *) spec
	     ignoreDeleted: (BOOL) ignoreDeleted
{
  [fetchesValue addObject: [NSDictionary dictionaryWithObjectsAndKeys:
				      fields, @"fields",
				      [[spec qualifier] allQualifierKeys], @"qualifierKeys",
				      [NSNumber numberWithBool: ignoreDeleted], @"ignoreDeleted",
				      [spec qualifier], @"qualifier",
				      nil]];

  return [NSArray array];
}

@end

@interface TestSyncContactFolder : SOGoContactGCSFolder
- (void) setTestOCSFolder: (id) newFolder;
@end

@implementation TestSyncContactFolder

- (void) setTestOCSFolder: (id) newFolder
{
  ASSIGN (ocsFolder, (GCSFolder *) newFolder);
}

@end

@interface TestSOGoGCSFolderWebDAVSync : SOGoTest
@end

@implementation TestSOGoGCSFolderWebDAVSync

- (TestSyncOCSFolder *) _runSyncReportWithThunderbirdUserAgent: (BOOL) thunderbird
                                                     syncToken: (NSString *) syncToken
{
  TestSyncOCSFolder *ocsFolderStub;
  TestSyncContactFolder *folder;
  TestSyncContext *context;
  TestSyncRequest *request;
  TestSyncUser *user;

  request = [[[TestSyncRequest alloc] init] autorelease];
  [request setThunderbird: thunderbird];
  user = [TestSyncUser testUserWithLogin: @"owner5972"];
  context = [TestSyncContext contextWithUser: user
				     request: request];

  folder = [[[TestSyncContactFolder alloc] init] autorelease];
  [folder setContext: (WOContext *) context];
  ocsFolderStub = [[[TestSyncOCSFolder alloc] init] autorelease];
  [folder setTestOCSFolder: ocsFolderStub];

  [folder syncTokenFieldsWithProperties: [NSDictionary dictionary]
		      matchingSyncToken: syncToken
		               fromDate: nil
		            initialLoad: NO];

  return ocsFolderStub;
}

- (id) _syncValueForQualifier: (EOQualifier *) qualifier
                          key: (NSString *) key
                     operator: (SEL) operatorSelector
{
  NSEnumerator *subQualifiers;
  EOQualifier *subQualifier;
  id value;

  value = nil;
  if ([qualifier isKindOfClass: [EOAndQualifier class]])
    {
      subQualifiers = [[(EOAndQualifier *) qualifier qualifiers] objectEnumerator];
      while (!value && (subQualifier = [subQualifiers nextObject]))
        value = [self _syncValueForQualifier: subQualifier
                                         key: key
                                    operator: operatorSelector];
    }
  else if ([qualifier isKindOfClass: [EOKeyValueQualifier class]]
           && [[(EOKeyValueQualifier *) qualifier key] isEqualToString: key]
           && [NSStringFromSelector([(EOKeyValueQualifier *) qualifier selector])
                  isEqualToString: NSStringFromSelector(operatorSelector)])
    value = [(EOKeyValueQualifier *) qualifier value];

  return value;
}

- (void) test_thunderbirdLiveRecordsKeepVlistExclusion
{
  TestSyncOCSFolder *ocsFolder;
  NSDictionary *liveFetch;

  ocsFolder = [self _runSyncReportWithThunderbirdUserAgent: YES syncToken: @"100"];

  test([[ocsFolder recordedFetches] count] == 2);
  liveFetch = [[ocsFolder recordedFetches] objectAtIndex: 0];
  test([[liveFetch objectForKey: @"ignoreDeleted"] boolValue] == YES);
  test([[liveFetch objectForKey: @"qualifierKeys"] containsObject: @"c_component"] == YES);
}

- (void) test_thunderbirdTombstonesBypassVlistExclusion
{
  TestSyncOCSFolder *ocsFolder;
  NSDictionary *tombstoneFetch;

  ocsFolder = [self _runSyncReportWithThunderbirdUserAgent: YES syncToken: @"100"];

  test([[ocsFolder recordedFetches] count] == 2);
  tombstoneFetch = [[ocsFolder recordedFetches] objectAtIndex: 1];
  test([[tombstoneFetch objectForKey: @"ignoreDeleted"] boolValue] == NO);
  test([[tombstoneFetch objectForKey: @"fields"] containsObject: @"c_name"] == YES);
  test([[tombstoneFetch objectForKey: @"fields"] containsObject: @"c_lastmodified"] == YES);
  test([[tombstoneFetch objectForKey: @"fields"] containsObject: @"c_deleted"] == YES);
  test([[tombstoneFetch objectForKey: @"qualifierKeys"] containsObject: @"c_lastmodified"] == YES);
  test([[tombstoneFetch objectForKey: @"qualifierKeys"] containsObject: @"c_deleted"] == YES);
  test([[tombstoneFetch objectForKey: @"qualifierKeys"] containsObject: @"c_component"] == NO);
}

- (void) test_nonThunderbirdRequestsBypassVlistExclusion
{
  TestSyncOCSFolder *ocsFolder;
  NSDictionary *liveFetch;

  ocsFolder = [self _runSyncReportWithThunderbirdUserAgent: NO syncToken: @"100"];

  test([[ocsFolder recordedFetches] count] == 2);
  liveFetch = [[ocsFolder recordedFetches] objectAtIndex: 0];
  test([[liveFetch objectForKey: @"ignoreDeleted"] boolValue] == YES);
  test([[liveFetch objectForKey: @"qualifierKeys"] containsObject: @"c_component"] == NO);
}

- (void) test_incrementalFetchesExcludeCurrentSecond
{
  TestSyncOCSFolder *ocsFolder;
  NSDictionary *liveFetch, *tombstoneFetch;
  EOQualifier *qualifier;
  NSNumber *upperBound;
  int before, after;

  before = (int) [[NSDate date] timeIntervalSince1970];
  ocsFolder = [self _runSyncReportWithThunderbirdUserAgent: NO syncToken: @"100"];
  after = (int) [[NSDate date] timeIntervalSince1970];

  test([[ocsFolder recordedFetches] count] == 2);
  liveFetch = [[ocsFolder recordedFetches] objectAtIndex: 0];
  qualifier = [liveFetch objectForKey: @"qualifier"];
  test([[self _syncValueForQualifier: qualifier
                                 key: @"c_lastmodified"
                            operator: EOQualifierOperatorGreaterThan] intValue] == 100);
  upperBound = [self _syncValueForQualifier: qualifier
                                        key: @"c_lastmodified"
                                   operator: EOQualifierOperatorLessThan];
  test(upperBound != nil);
  test([upperBound intValue] >= before);
  test([upperBound intValue] <= after);

  tombstoneFetch = [[ocsFolder recordedFetches] objectAtIndex: 1];
  qualifier = [tombstoneFetch objectForKey: @"qualifier"];
  test([[self _syncValueForQualifier: qualifier
                                 key: @"c_lastmodified"
                            operator: EOQualifierOperatorGreaterThan] intValue] == 100);
  upperBound = [self _syncValueForQualifier: qualifier
                                        key: @"c_lastmodified"
                                   operator: EOQualifierOperatorLessThan];
  test(upperBound != nil);
  test([upperBound intValue] >= before);
  test([upperBound intValue] <= after);
  test([[self _syncValueForQualifier: qualifier
                                 key: @"c_deleted"
                            operator: EOQualifierOperatorEqual] intValue] == 1);
}

- (void) test_initialLoadFetchExcludesCurrentSecond
{
  TestSyncOCSFolder *ocsFolder;
  NSDictionary *liveFetch;
  EOQualifier *qualifier;
  NSNumber *upperBound;
  int before, after;

  before = (int) [[NSDate date] timeIntervalSince1970];
  ocsFolder = [self _runSyncReportWithThunderbirdUserAgent: NO syncToken: @""];
  after = (int) [[NSDate date] timeIntervalSince1970];

  test([[ocsFolder recordedFetches] count] == 1);
  liveFetch = [[ocsFolder recordedFetches] objectAtIndex: 0];
  qualifier = [liveFetch objectForKey: @"qualifier"];
  test([self _syncValueForQualifier: qualifier
                                key: @"c_lastmodified"
                           operator: EOQualifierOperatorGreaterThan] == nil);
  upperBound = [self _syncValueForQualifier: qualifier
                                        key: @"c_lastmodified"
                                   operator: EOQualifierOperatorLessThan];
  test(upperBound != nil);
  test([upperBound intValue] >= before);
  test([upperBound intValue] <= after);
}

@end
