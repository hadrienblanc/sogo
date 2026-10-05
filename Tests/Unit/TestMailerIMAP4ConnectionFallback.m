/* TestMailerIMAP4ConnectionFallback.m - this file is part of SOGo
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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/Foundation.h>

#import <Mailer/SOGoMailBaseObject.h>

#import "SOGoTest.h"

@interface SOGoMailBaseObject (Test99999FallbackSupport)
- (id) _connectionFromManager: (id) manager
                          url: (NSURL *) url
                     password: (NSString *) password
         preLoginIDParameters: (NSString *) idParameters;
@end

@interface Test99999ConnectionManagerFake : NSObject
{
  NSString *lastSelector;
  NSURL *lastURL;
  NSString *lastPassword;
  NSString *lastIDParameters;
  id connection;
}

- (id) initWithConnection: (id) aConnection;
- (NSString *) lastSelector;
- (NSURL *) lastURL;
- (NSString *) lastPassword;
- (NSString *) lastIDParameters;
- (id) connectionForURL: (NSURL *) url password: (NSString *) password;

@end

@implementation Test99999ConnectionManagerFake

- (id) initWithConnection: (id) aConnection
{
  if ((self = [super init]))
    connection = [aConnection retain];

  return self;
}

- (void) dealloc
{
  [lastSelector release];
  [lastURL release];
  [lastPassword release];
  [lastIDParameters release];
  [connection release];
  [super dealloc];
}

- (NSString *) lastSelector
{
  return lastSelector;
}

- (NSURL *) lastURL
{
  return lastURL;
}

- (NSString *) lastPassword
{
  return lastPassword;
}

- (NSString *) lastIDParameters
{
  return lastIDParameters;
}

- (id) connectionForURL: (NSURL *) url password: (NSString *) password
{
  ASSIGN (lastSelector, @"connectionForURL:password:");
  ASSIGN (lastURL, url);
  ASSIGN (lastPassword, password);
  ASSIGN (lastIDParameters, nil);

  return connection;
}

@end

@interface Test99999PreLoginManagerFake : Test99999ConnectionManagerFake
- (id) connectionForURL: (NSURL *) url
               password: (NSString *) password
   preLoginIDParameters: (NSString *) idParameters;
@end

@implementation Test99999PreLoginManagerFake

- (id) connectionForURL: (NSURL *) url
               password: (NSString *) password
   preLoginIDParameters: (NSString *) idParameters
{
  ASSIGN (lastSelector, @"connectionForURL:password:preLoginIDParameters:");
  ASSIGN (lastURL, url);
  ASSIGN (lastPassword, password);
  ASSIGN (lastIDParameters, idParameters);

  return connection;
}

@end

@interface TestMailerIMAP4ConnectionFallback : SOGoTest
{
  id baseObject;
}

@end

@implementation TestMailerIMAP4ConnectionFallback

- (void) setUp
{
  Class baseObjectClass;

  testWithMessage ([SOGoTest loadSOGoBundle: @"Mailer"
                                markerClass: @"SOGoMailBaseObject"],
                   @"SOGoMailBaseObject class unavailable (Mailer.SOGo bundle missing)");
  baseObjectClass = NSClassFromString (@"SOGoMailBaseObject");
  if (baseObjectClass)
    baseObject = [[baseObjectClass alloc] init];
}

- (void) tearDown
{
  ASSIGN (baseObject, nil);
  [super tearDown];
}

- (void) test_stockManagerFallsBackToPlainConnection
{
  Test99999ConnectionManagerFake *manager;
  id result;

  manager = [[Test99999ConnectionManagerFake alloc] initWithConnection: baseObject];

  result = [baseObject _connectionFromManager: manager
                                          url: [NSURL URLWithString: @"imap://127.0.0.1/"]
                                     password: @"secret"
                         preLoginIDParameters: @"(\"x-originating-ip\" \"127.0.0.1\")"];

  testEquals (result, baseObject);
  testEquals ([manager lastSelector], @"connectionForURL:password:");
  testEquals ([[manager lastURL] absoluteString], @"imap://127.0.0.1/");
  testEquals ([manager lastPassword], @"secret");
  testEquals ([manager lastIDParameters], nil);

  [manager release];
}

- (void) test_patchedManagerUsesPreLoginIDParameters
{
  Test99999PreLoginManagerFake *manager;
  id result;

  manager = [[Test99999PreLoginManagerFake alloc] initWithConnection: baseObject];

  result = [baseObject _connectionFromManager: manager
                                          url: [NSURL URLWithString: @"imap://127.0.0.1/"]
                                     password: @"secret"
                         preLoginIDParameters: @"(\"x-originating-ip\" \"127.0.0.1\")"];

  testEquals (result, baseObject);
  testEquals ([manager lastSelector], @"connectionForURL:password:preLoginIDParameters:");
  testEquals ([[manager lastURL] absoluteString], @"imap://127.0.0.1/");
  testEquals ([manager lastPassword], @"secret");
  testEquals ([manager lastIDParameters], @"(\"x-originating-ip\" \"127.0.0.1\")");

  [manager release];
}

- (void) test_stockManagerWithoutOriginatingIP
{
  Test99999ConnectionManagerFake *manager;
  id result;

  manager = [[Test99999ConnectionManagerFake alloc] initWithConnection: baseObject];

  result = [baseObject _connectionFromManager: manager
                                          url: [NSURL URLWithString: @"imap://127.0.0.1/"]
                                     password: @"secret"
                         preLoginIDParameters: nil];

  testEquals (result, baseObject);
  testEquals ([manager lastSelector], @"connectionForURL:password:");

  [manager release];
}

@end
