/* TestNSDataSMIME.m - this file is part of SOGo
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

#import <Foundation/NSData.h>
#import <Foundation/NSString.h>

#import "SOGoTest.h"

@interface TestNSDataSMIME : SOGoTest
@end

@implementation TestNSDataSMIME

- (void) setUp
{
  [SOGoTest loadSOGoBundle: @"Mailer" markerClass: @"SOGoDraftObject"];
  testWithMessage ([NSData instancesRespondToSelector: @selector (convertPKCS12ToPEMUsingPassword:)],
                   @"NSData+SMIME category unavailable (Mailer.SOGo bundle missing)");
}

- (NSString *) pemStringFromResult: (NSData *) thePEM
{
  NSString *pem;

  pem = nil;
  if (thePEM != nil)
    pem = [[[NSString alloc] initWithData: thePEM encoding: NSASCIIStringEncoding] autorelease];

  return pem;
}

- (void) test_convertPKCS12RC2ToPEM
{
  NSData *pkcs12;
  NSString *pem;

  pkcs12 = [NSData dataWithContentsOfFile: @"Fixtures/ticket-5688-rc2.p12"];
  test(pkcs12 != nil);

  pem = [self pemStringFromResult: [pkcs12 convertPKCS12ToPEMUsingPassword: @"secret"]];
  test(pem != nil);
  test([pem hasPrefix: @"-----BEGIN PRIVATE KEY-----"]);
  test([pem rangeOfString: @"-----BEGIN CERTIFICATE-----"].location != NSNotFound);
}

- (void) test_convertPKCS12AESToPEM
{
  NSData *pkcs12;
  NSString *pem;

  pkcs12 = [NSData dataWithContentsOfFile: @"Fixtures/ticket-5688-aes.p12"];
  test(pkcs12 != nil);

  pem = [self pemStringFromResult: [pkcs12 convertPKCS12ToPEMUsingPassword: @"secret"]];
  test(pem != nil);
  test([pem hasPrefix: @"-----BEGIN PRIVATE KEY-----"]);
  test([pem rangeOfString: @"-----BEGIN CERTIFICATE-----"].location != NSNotFound);
}

- (void) test_convertPasswordlessPKCS12ToPEM
{
  NSData *pkcs12;
  NSString *pem;

  pkcs12 = [NSData dataWithContentsOfFile: @"Fixtures/ticket-5688-nopass.p12"];
  test(pkcs12 != nil);

  pem = [self pemStringFromResult: [pkcs12 convertPKCS12ToPEMUsingPassword: @""]];
  test(pem != nil);
  test([pem hasPrefix: @"-----BEGIN PRIVATE KEY-----"]);
  test([pem rangeOfString: @"-----BEGIN CERTIFICATE-----"].location != NSNotFound);
}

- (void) test_convertPKCS12WithWrongPassword
{
  NSData *pkcs12;

  pkcs12 = [NSData dataWithContentsOfFile: @"Fixtures/ticket-5688-rc2.p12"];
  test([pkcs12 convertPKCS12ToPEMUsingPassword: @"wrong-password"] == nil);
}

- (void) test_convertGarbageToPEM
{
  NSData *garbage;

  garbage = [@"this is not a PKCS12 blob" dataUsingEncoding: NSASCIIStringEncoding];
  test([garbage convertPKCS12ToPEMUsingPassword: @"secret"] == nil);
}

@end
