/* TestUIxJSONPreferences.m - this file is part of SOGo
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
#import <Foundation/NSString.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>

#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSNumber+Utilities.h>
#import <SOGo/NSString+Utilities.h>

#import "SOGoTest.h"
#import <UI/PreferencesUI/UIxJSONPreferences.h>

__attribute__((weak)) char __objc_class_name_SOGoMailLabel = 0;

@interface Test5989DefaultsSource : NSObject
{
  NSMutableDictionary *values;
  BOOL dirty;
}

- (id) objectForKey: (NSString *) key;
- (void) setObject: (id) value forKey: (NSString *) key;
- (void) removeObjectForKey: (NSString *) key;
- (BOOL) synchronize;
- (BOOL) dirty;
- (NSDictionary *) values;

@end

@implementation Test5989DefaultsSource

- (id) init
{
  if ((self = [super init]))
    {
      values = [[NSMutableDictionary alloc] init];
      dirty = NO;
    }

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
  if (value)
    {
      [values setObject: value forKey: key];
      dirty = YES;
    }
}

- (void) removeObjectForKey: (NSString *) key
{
  [values removeObjectForKey: key];
}

- (BOOL) synchronize
{
  dirty = NO;

  return YES;
}

- (BOOL) dirty
{
  return dirty;
}

- (NSDictionary *) values
{
  return values;
}

@end

@interface Test5989ParentSource : SOGoDefaultsSource
@end

@implementation Test5989ParentSource

- (NSString *) language
{
  return @"English";
}

@end

@interface Test5989DomainDefaults : NSObject
@end

@implementation Test5989DomainDefaults

- (NSString *) language
{
  return @"English";
}

- (BOOL) externalAvatarsEnabled
{
  return NO;
}

- (BOOL) appointmentSendEMailNotifications
{
  return NO;
}

- (BOOL) ldapGroupExpansionEnabled
{
  return NO;
}

- (NSString *) mailJunkIcon
{
  return @"thumb_down";
}

- (BOOL) forwardEnabled
{
  return NO;
}

- (BOOL) notificationEnabled
{
  return NO;
}

- (BOOL) mailCertificateEnabled
{
  return NO;
}

- (NSString *) vacationDefaultSubject
{
  return nil;
}

@end

@interface Test5989User : NSObject
{
  SOGoUserDefaults *defaults;
  Test5989DomainDefaults *domainDefaults;
}

- (id) userDefaults;
- (NSString *) login;
- (id) domainDefaults;
- (NSArray *) mailAccountsNoRawHtmlSignature;

@end

@implementation Test5989User

- (id) initWithUserDefaults: (SOGoUserDefaults *) theDefaults
{
  if ((self = [super init]))
    {
      defaults = [theDefaults retain];
      domainDefaults = [[Test5989DomainDefaults alloc] init];
    }

  return self;
}

- (void) dealloc
{
  [defaults release];
  [domainDefaults release];
  [super dealloc];
}

- (id) userDefaults
{
  return defaults;
}

- (NSString *) login
{
  return @"test-5989";
}

- (id) domainDefaults
{
  return domainDefaults;
}

- (NSArray *) mailAccountsNoRawHtmlSignature
{
  return [NSArray arrayWithObject: [NSMutableDictionary dictionary]];
}

@end

@interface Test5989JSONPreferences : UIxJSONPreferences
- (id) initWithTestContext: (WOContext *) aContext;
@end

@implementation Test5989JSONPreferences

- (id) initWithTestContext: (WOContext *) aContext
{
  if ((self = [super init]))
    context = aContext;

  return self;
}

@end

@interface TestUIxJSONPreferences : SOGoTest
@end

@implementation TestUIxJSONPreferences

- (SOGoUserDefaults *) _defaultsWithConfigValues: (NSDictionary *) configValues
                                    userValues: (NSDictionary *) userValues
{
  SOGoDefaultsSource *parent;
  SOGoUserDefaults *defaults;
  Test5989DefaultsSource *source;

  source = [[[Test5989DefaultsSource alloc] init] autorelease];
  [[source values] addEntriesFromDictionary: userValues];
  [[source values] setObject: [NSArray array]  forKey: @"SOGoCalendarCategories"];
  [[source values] setObject: [NSDictionary dictionary]  forKey: @"SOGoCalendarCategoriesColors"];
  [[source values] setObject: [NSArray array]  forKey: @"SOGoContactsCategories"];
  [[source values] setObject: [NSDictionary dictionary]  forKey: @"SOGoMailLabelsColors"];

  parent = [Test5989ParentSource
             defaultsSourceWithSource: configValues
                       andParentSource: [SOGoSystemDefaults sharedSystemDefaults]];
  defaults = [SOGoUserDefaults defaultsSourceWithSource: source
                                         andParentSource: parent];

  return defaults;
}

- (NSDictionary *) _configValues
{
  NSMutableDictionary *configValues;

  configValues = [NSMutableDictionary dictionary];
  [configValues setObject: @"English"  forKey: @"SOGoLanguage"];
  [configValues setObject: @"UTC"  forKey: @"SOGoTimeZone"];
  [configValues setObject: @"%d-%b-%y"  forKey: @"SOGoShortDateFormat"];
  [configValues setObject: @"%A, %B %d, %Y"  forKey: @"SOGoLongDateFormat"];
  [configValues setObject: @"%H:%M"  forKey: @"SOGoTimeFormat"];
  [configValues setObject: @"Mail"  forKey: @"SOGoLoginModule"];
  [configValues setObject: @"manually"  forKey: @"SOGoRefreshViewCheck"];
  [configValues setObject: @"normal"  forKey: @"SOGoAnimationMode"];
  [configValues setObject: [NSNumber numberWithInt: 0]  forKey: @"SOGoFirstDayOfWeek"];
  [configValues setObject: @"January1"  forKey: @"SOGoFirstWeekOfYear"];
  [configValues setObject: @"selected"  forKey: @"SOGoDefaultCalendar"];
  [configValues setObject: @"PUBLIC"  forKey: @"SOGoCalendarEventsDefaultClassification"];
  [configValues setObject: @"PUBLIC"  forKey: @"SOGoCalendarTasksDefaultClassification"];
  [configValues setObject: @"NONE"  forKey: @"SOGoCalendarDefaultReminder"];
  [configValues setObject: @"Disabled"  forKey: @"SOGoPasswordRecoveryMode"];
  [configValues setObject: @"SecretQuestion1"  forKey: @"SOGoPasswordRecoveryQuestion"];
  [configValues setObject: @"inline"  forKey: @"SOGoMailComposeWindow"];
  [configValues setObject: @"collected"  forKey: @"SOGoSelectedAddressBook"];
  [configValues setObject: @"inline"  forKey: @"SOGoMailMessageForwarding"];
  [configValues setObject: @"below"  forKey: @"SOGoMailReplyPlacement"];
  [configValues setObject: @"html"  forKey: @"SOGoMailComposeMessageType"];
  [configValues setObject: [NSNumber numberWithInt: 0]  forKey: @"SOGoMailComposeFontSize"];
  [configValues setObject: @"never"  forKey: @"SOGoMailDisplayRemoteInlineImages"];
  [configValues setObject: @"5"  forKey: @"SOGoMailAutoSave"];

  return configValues;
}

- (NSDictionary *) _jsonDefaultsWithConfigValues: (NSDictionary *) configValues
                                     userValues: (NSDictionary *) userValues
{
  WORequest *request;
  WOContext *context;
  Test5989JSONPreferences *preferences;
  Test5989User *user;
  NSDictionary *locale, *json;
  NSString *jsonString;

  request = [[[WORequest alloc] initWithMethod: @"GET"
                                            uri: @"/SOGo/so/test/Preferences/jsonDefaults"
                                    httpVersion: @"HTTP/1.1"
                                        headers: [NSDictionary dictionaryWithObject: @"en"
                                                                             forKey: @"accept-language"]
                                        content: nil
                                      userInfo: nil] autorelease];
  context = [[[WOContext alloc] initWithRequest: request] autorelease];
  locale = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"English", @"NSLocaleCode",
                             [NSArray array], @"NSMonthNameArray",
                             [NSArray array], @"NSShortMonthNameArray",
                             [NSArray array], @"NSWeekDayNameArray",
                             [NSArray array], @"NSShortWeekDayNameArray",
                             nil];
  [context setObject: locale  forKey: @"locale"];

  user = [[[Test5989User alloc]
            initWithUserDefaults: [self _defaultsWithConfigValues: configValues
                                                       userValues: userValues]] autorelease];
  [context setActiveUser: user];

  preferences = [[[Test5989JSONPreferences alloc] initWithTestContext: context] autorelease];
  [preferences setValue: [context objectForKey: @"locale"] forKey: @"locale"];
  jsonString = [preferences jsonDefaults];
  json = [jsonString objectFromJSONString];

  return json;
}

- (void) test_fetchAllUnseenCountFoldersFromConfigExposedAsNumber
{
  NSDictionary *configValues, *json;
  id value;

  configValues = [self _configValues];
  [configValues setValue: [NSNumber numberWithBool: YES]
                  forKey: @"SOGoMailFetchAllUnseenCountFolders"];
  json = [self _jsonDefaultsWithConfigValues: configValues
                                 userValues: [NSDictionary dictionary]];

  value = [json objectForKey: @"SOGoMailFetchAllUnseenCountFolders"];
  testWithMessage (value != nil,
                   @"a SOGoMailFetchAllUnseenCountFolders default from the configuration"
                   @" must be exposed in the user's defaults (bug 5989)");
  testWithMessage (![value isKindOfClass: [NSString class]],
                   @"SOGoMailFetchAllUnseenCountFolders must be serialized as a number,"
                   @" not as a string");
  testEquals ([value jsonRepresentation], @"1");
}

- (void) test_fetchAllUnseenCountFoldersFromStringConfigExposedAsNumber
{
  NSDictionary *configValues, *json;

  configValues = [self _configValues];
  [configValues setValue: @"1"
                  forKey: @"SOGoMailFetchAllUnseenCountFolders"];
  json = [self _jsonDefaultsWithConfigValues: configValues
                                 userValues: [NSDictionary dictionary]];

  testEquals ([[json objectForKey: @"SOGoMailFetchAllUnseenCountFolders"] jsonRepresentation], @"1");
}

- (void) test_fetchAllUnseenCountFoldersUserValueNotOverwritten
{
  NSDictionary *configValues, *userValues, *json;

  configValues = [self _configValues];
  [configValues setValue: [NSNumber numberWithBool: YES]
                  forKey: @"SOGoMailFetchAllUnseenCountFolders"];
  userValues = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: 0]
                                           forKey: @"SOGoMailFetchAllUnseenCountFolders"];
  json = [self _jsonDefaultsWithConfigValues: configValues
                                 userValues: userValues];

  testEquals ([[json objectForKey: @"SOGoMailFetchAllUnseenCountFolders"] jsonRepresentation], @"0");
}

- (void) test_fetchAllUnseenCountFoldersUnsetDefaultsToZero
{
  NSDictionary *json;

  json = [self _jsonDefaultsWithConfigValues: [self _configValues]
                                 userValues: [NSDictionary dictionary]];

  testEquals ([[json objectForKey: @"SOGoMailFetchAllUnseenCountFolders"] jsonRepresentation], @"0");
}

@end
