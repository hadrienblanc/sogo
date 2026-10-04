/* TestLDAPSourceEncryption.m - this file is part of SOGo
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
 * Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <EOControl/EOControl.h>
#import <SOGo/LDAPSource.h>

#import "SOGoTest.h"

@interface LDAPSource (TestEncryptionState)
- (NSString *) test_hostname;
- (unsigned int) test_port;
- (NSString *) test_encryption;
@end

@implementation LDAPSource (TestEncryptionState)

- (NSString *) test_hostname
{
  return _hostname;
}

- (unsigned int) test_port
{
  return _port;
}

- (NSString *) test_encryption
{
  return _encryption;
}

@end

@interface TestLDAPSourceEncryption : SOGoTest
@end

@implementation TestLDAPSourceEncryption

- (LDAPSource *) _sourceWithHostname: (NSString *) hostname
                                port: (NSString *) port
                          encryption: (NSString *) encryption
{
  NSMutableDictionary *udSource;

  udSource = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                          @"test-5917-ldap", @"id",
                          @"ldap", @"type",
                          @"ou=users,dc=example,dc=com", @"baseDN",
                          hostname, @"hostname",
                          nil];
  if (port)
    [udSource setObject: port forKey: @"port"];
  if (encryption)
    [udSource setObject: encryption forKey: @"encryption"];

  return [LDAPSource sourceFromUDSource: udSource inDomain: nil];
}

- (void) test_ldapsURLWithSSLEncryptionDefaultsToPort636
{
  LDAPSource *source;

  source = [self _sourceWithHostname: @"ldaps://ad.example.com"
                                port: nil
                          encryption: @"SSL"];

  testEqualsWithMessage(@"ldaps://ad.example.com", [source test_hostname],
                        @"hostname 'ldaps://ad.example.com' -> kept verbatim"
                        @" for ldap_initialize (bug 5917)");
  testWithMessage([source test_port] == 636,
                  @"encryption SSL without port -> 636");
  testEqualsWithMessage(@"SSL", [source test_encryption],
                        @"encryption SSL -> SSL");
}

- (void) test_bareHostWithSSLEncryptionDefaultsToPort636
{
  LDAPSource *source;

  source = [self _sourceWithHostname: @"ad.example.com"
                                port: nil
                          encryption: @"SSL"];

  testWithMessage([source test_port] == 636,
                  @"bare host, encryption SSL without port -> 636");
}

- (void) test_startTLSEncryptionKeepsDefaultPort389
{
  LDAPSource *source;

  source = [self _sourceWithHostname: @"ad.example.com"
                                port: nil
                          encryption: @"STARTTLS"];

  testWithMessage([source test_port] == 389,
                  @"encryption STARTTLS without port -> 389");
  testEqualsWithMessage(@"STARTTLS", [source test_encryption],
                        @"encryption STARTTLS -> STARTTLS");
}

- (void) test_noEncryptionKeepsDefaultPort389
{
  LDAPSource *source;

  source = [self _sourceWithHostname: @"ldap://ad.example.com"
                                port: nil
                          encryption: nil];

  testWithMessage([source test_port] == 389,
                  @"no encryption without port -> 389");
  testWithMessage(![source test_encryption],
                  @"no encryption -> no encryption scheme recorded");
}

- (void) test_explicitPortOverridesSSLDefault
{
  LDAPSource *source;

  source = [self _sourceWithHostname: @"ldaps://ad.example.com"
                                port: @"1636"
                          encryption: @"SSL"];

  testWithMessage([source test_port] == 1636,
                  @"explicit port 1636 with encryption SSL -> 1636");
}

- (void) test_encryptionValueIsNormalizedToUppercase
{
  LDAPSource *source;

  source = [self _sourceWithHostname: @"ad.example.com"
                                port: nil
                          encryption: @"ssl"];

  testEqualsWithMessage(@"SSL", [source test_encryption],
                        @"encryption 'ssl' -> 'SSL'");
  testWithMessage([source test_port] == 636,
                  @"encryption 'ssl' without port -> 636");

  source = [self _sourceWithHostname: @"ad.example.com"
                                port: nil
                          encryption: @"StartTLS"];

  testEqualsWithMessage(@"STARTTLS", [source test_encryption],
                        @"encryption 'StartTLS' -> 'STARTTLS'");
  testWithMessage([source test_port] == 389,
                  @"encryption 'StartTLS' without port -> 389");
}

@end
