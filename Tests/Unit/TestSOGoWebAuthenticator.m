/* TestSOGoWebAuthenticator.m - this file is part of SOGo
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
 * Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 */

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <NGObjWeb/WOCookie.h>

#import <SOGo/SOGoWebAuthenticator.h>

#import "SOGoTest.h"

@interface Test5722Application : NSObject
@end

@implementation Test5722Application

- (NSString *) name
{
  return @"SOGo";
}

@end

@interface Test5722Request : NSObject
{
}

- (NSString *) applicationName;

@end

@implementation Test5722Request

- (NSString *) applicationName
{
  return @"SOGo";
}

@end

@interface Test5722Context : NSObject
{
  Test5722Application *applicationValue;
  Test5722Request *requestValue;
  NSURL *serverURLValue;
}

+ (Test5722Context *) contextWithServerURL: (NSURL *) serverURL;

- (id) application;
- (Test5722Request *) request;
- (NSURL *) serverURL;

@end

@implementation Test5722Context

+ (Test5722Context *) contextWithServerURL: (NSURL *) serverURL
{
  Test5722Context *context;

  context = [[[Test5722Context alloc] init] autorelease];
  context->applicationValue = [[Test5722Application alloc] init];
  context->requestValue = [[Test5722Request alloc] init];
  context->serverURLValue = [serverURL retain];

  return context;
}

- (void) dealloc
{
  [applicationValue release];
  [requestValue release];
  [serverURLValue release];
  [super dealloc];
}

- (id) application
{
  return applicationValue;
}

- (Test5722Request *) request
{
  return requestValue;
}

- (NSURL *) serverURL
{
  return serverURLValue;
}

@end

@interface TestSOGoWebAuthenticator : SOGoTest
@end

@implementation TestSOGoWebAuthenticator

- (WOCookie *) _authCookieWithServerURL: (NSString *) serverURL
{
  Test5722Context *context;

  context = [Test5722Context contextWithServerURL:
                         [NSURL URLWithString: serverURL]];

  return [[SOGoWebAuthenticator sharedSOGoWebAuthenticator]
           cookieWithUsername: @"user5722"
                   andPassword: @"password5722"
                     inContext: (WOContext *) context];
}

- (void) test_authCookieIsNotSecureOverHttpFrontend
{
  WOCookie *cookie;

  cookie = [self _authCookieWithServerURL: @"http://sogo.example"];

  testWithMessage ([cookie isSecure] == NO,
                   @"http frontend -> session cookie without Secure attribute");
}

- (void) test_authCookieIsSecureOverHttpsFrontend
{
  WOCookie *cookie;

  cookie = [self _authCookieWithServerURL: @"https://sogo.example"];

  testWithMessage ([cookie isSecure] == YES,
                   @"https frontend -> session cookie with Secure attribute");
}

- (void) test_authCookieIsSecureWhenHttpsUrlIsAdvertisedOnHttpPort
{
  WOCookie *cookie;

  cookie = [self _authCookieWithServerURL: @"https://sogo.example:80"];

  testWithMessage ([cookie isSecure] == YES,
                   @"advertised URL scheme drives the Secure flag, not the port");
}

- (void) test_authCookiePathIsScopedToApplication
{
  WOCookie *cookie;

  cookie = [self _authCookieWithServerURL: @"http://sogo.example"];

  testEquals([cookie path], @"/SOGo/");
}

- (void) test_authCookieNameIsDerivedFromApplicationName
{
  WOCookie *cookie;

  cookie = [self _authCookieWithServerURL: @"http://sogo.example"];

  testEquals([cookie name], @"0xHIGHFLYxSOGo");
}

- (void) test_authCookieValueCarriesBasicCredentials
{
  WOCookie *cookie;

  cookie = [self _authCookieWithServerURL: @"http://sogo.example"];

  testWithMessage ([[cookie value] hasPrefix: @"basic "],
                   @"cookie value -> 'basic ' prefixed credentials blob");
}

@end
