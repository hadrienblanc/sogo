/* TestSOGoProxyAuthenticator.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option), any
 * later version.
 *
 * This file is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/WOContext.h>

#import <NGExtensions/NGBase64Coding.h>

#import <SOGo/SOGoProxyAuthenticator.h>
#import <SOGo/SOGoSource.h>
#import <SOGo/SOGoUserManager.h>

#import "SOGoTest.h"

@interface SOGoUserManager (Test5987SourceRegistration)
- (BOOL) _registerSource: (NSDictionary *) udSource
                 inDomain: (NSString *) domain;
@end

@interface SOGoProxyAuthenticator (Test5987CredentialsCheck)
- (NSString *) checkCredentialsInContext: (WOContext *) context;
@end

@interface Test5987Source : NSObject
{
}
+ (id) sourceFromUDSource: (NSDictionary *) udSource
                 inDomain: (NSString *) domain;
@end

@implementation Test5987Source

+ (id) sourceFromUDSource: (NSDictionary *) udSource
                 inDomain: (NSString *) domain
{
  return [[[Test5987Source alloc] initFromUDSource: udSource
                                          inDomain: domain] autorelease];
}

- (id) initFromUDSource: (NSDictionary *) udSource
               inDomain: (NSString *) domain
{
  return [super init];
}

- (NSString *) domain
{
  return nil;
}

- (NSArray *) userPasswordPolicy
{
  return nil;
}

- (BOOL) checkLogin: (NSString *) login
            password: (NSString *) password
                perr: (SOGoPasswordPolicyError *) perr
              expire: (int *) expire
               grace: (int *) grace
{
  *perr = PolicyNoError;

  return [password isEqualToString: @"goodpw"];
}

@end

@interface Test5987Request : NSObject
{
  NSDictionary *headersValue;
}
+ (Test5987Request *) requestWithHeaders: (NSDictionary *) headers;
- (NSString *) headerForKey: (NSString *) key;
@end

@implementation Test5987Request

+ (Test5987Request *) requestWithHeaders: (NSDictionary *) headers
{
  Test5987Request *request;

  request = [[[Test5987Request alloc] init] autorelease];
  request->headersValue = [headers retain];

  return request;
}

- (void) dealloc
{
  [headersValue release];
  [super dealloc];
}

- (NSString *) headerForKey: (NSString *) key
{
  return [headersValue objectForKey: key];
}

@end

@interface Test5987Context : NSObject
{
  Test5987Request *requestValue;
}
+ (Test5987Context *) contextWithRequest: (Test5987Request *) request;
- (Test5987Request *) request;
@end

@implementation Test5987Context

+ (Test5987Context *) contextWithRequest: (Test5987Request *) request
{
  Test5987Context *context;

  context = [[[Test5987Context alloc] init] autorelease];
  context->requestValue = [request retain];

  return context;
}

- (void) dealloc
{
  [requestValue release];
  [super dealloc];
}

- (Test5987Request *) request
{
  return requestValue;
}

@end

@interface TestSOGoProxyAuthenticator : SOGoTest
{
  SOGoProxyAuthenticator *authenticator;
}
@end

@implementation TestSOGoProxyAuthenticator

- (id) init
{
  if ((self = [super init]))
    authenticator = [[SOGoProxyAuthenticator alloc] init];

  return self;
}

- (void) dealloc
{
  [authenticator release];
  [super dealloc];
}

- (NSString *) _loginForHeaders: (NSDictionary *) headers
{
  WOContext *context;

  context = (WOContext *) [Test5987Context contextWithRequest:
                                      [Test5987Request requestWithHeaders: headers]];

  return [authenticator checkCredentialsInContext: context];
}

- (SOGoUserManager *) _userManagerWithStubSource: (BOOL) canAuthenticate
{
  SOGoUserManager *userManager;
  NSDictionary *source;

  userManager = [[SOGoUserManager alloc] init];

  source = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"test-5987-auth", @"id",
                          @"Test5987Source", @"type",
                          [NSNumber numberWithBool: canAuthenticate], @"canAuthenticate",
                          nil];
  [userManager _registerSource: source inDomain: nil];

  return [userManager autorelease];
}

- (void) test_remoteUserWithoutBasicCredentialsIsTrusted
{
  NSDictionary *headers;
  NSString *login;

  headers = [NSDictionary dictionaryWithObject: @"user5987"
                                       forKey: @"x-webobjects-remote-user"];
  login = [self _loginForHeaders: headers];

  testEquals(login, @"user5987");
}

- (void) test_remoteUserWithBasicCredentialsForOtherLoginIsTrusted
{
  NSDictionary *headers;
  NSString *authorization, *login;

  authorization = [NSString stringWithFormat: @"Basic %@",
                            [@"other5987:somepw" stringByEncodingBase64]];
  headers = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"user5987", @"x-webobjects-remote-user",
                          authorization, @"authorization",
                          nil];
  login = [self _loginForHeaders: headers];

  testEquals(login, @"user5987");
}

- (void) test_missingRemoteUserFallsBackToAnonymousWhenProxyAuthIsTrusted
{
  NSString *login;

  [[NSUserDefaults standardUserDefaults]
    registerDefaults: [NSDictionary dictionaryWithObject: @"YES"
                                                  forKey: @"SOGoTrustProxyAuthentication"]];
  login = [self _loginForHeaders: [NSDictionary dictionary]];

  testEquals(login, @"anonymous");
}

- (void) test_checkProxyLoginTrustsEverythingWithoutAuthenticationSources
{
  SOGoUserManager *userManager;

  userManager = [[SOGoUserManager alloc] init];

  test([[userManager authenticationSourceIDsInDomain: nil] count] == 0);
  test([userManager checkProxyLogin: @"user5987" password: @"badpw"] == YES);

  [userManager release];
}

- (void) test_checkProxyLoginRejectsWrongPasswordWithAuthenticationSource
{
  SOGoUserManager *userManager;

  userManager = [self _userManagerWithStubSource: YES];

  test([userManager checkProxyLogin: @"user5987" password: @"badpw"] == NO);
}

- (void) test_checkProxyLoginAcceptsCorrectPasswordWithAuthenticationSource
{
  SOGoUserManager *userManager;

  userManager = [self _userManagerWithStubSource: YES];

  test([userManager checkProxyLogin: @"user5987" password: @"goodpw"] == YES);
}

- (void) test_checkProxyLoginTrustsCredentialsWithNonAuthenticatingSources
{
  SOGoUserManager *userManager;

  userManager = [self _userManagerWithStubSource: NO];

  test([[userManager authenticationSourceIDsInDomain: nil] count] == 0);
  test([userManager checkProxyLogin: @"user5987" password: @"badpw"] == YES);
}

@end
