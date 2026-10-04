/* TestSOGoMailerAccountSelection.m - this file is part of SOGo
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

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <SOGo/SOGoMailer.h>

#import "SOGoTest.h"

@interface TestSOGoMailerAccountSelection : SOGoTest
@end

@implementation TestSOGoMailerAccountSelection

- (SOGoMailer *) _mailerWithSmtpUrl: (NSString *) url
                       userIdAccount: (NSString *) account
{
  NSURL *smtpUrl;

  if (url)
    smtpUrl = [NSURL URLWithString: url];
  else
    smtpUrl = nil;

  return [SOGoMailer mailerWithDomainDefaults: nil
                                      smtpUrl: smtpUrl
                                userIdAccount: account];
}

- (void) test_auxiliaryAccountSmtpUrlIsKept
{
  SOGoMailer *mailer;

  mailer = [self _mailerWithSmtpUrl: @"smtp://mx.secondary.example.com:587/?tls=YES&tlsVerifyMode=default"
                       userIdAccount: @"2"];

  testEquals ([mailer valueForKey: @"smtpServer"],
              @"smtp://mx.secondary.example.com:587/?tls=YES&tlsVerifyMode=default");
  testEquals ([mailer valueForKey: @"userIdAccount"], @"2");

  [mailer release];
}

- (void) test_primaryAccountSmtpUrlIsKept
{
  SOGoMailer *mailer;

  mailer = [self _mailerWithSmtpUrl: @"smtp://mail.primary.example/"
                       userIdAccount: @"0"];

  testEquals ([mailer valueForKey: @"smtpServer"],
              @"smtp://mail.primary.example/");
  testEquals ([mailer valueForKey: @"userIdAccount"], @"0");

  [mailer release];
}

- (void) test_missingSmtpUrlFallsBackToDomainDefaults
{
  SOGoMailer *mailer;

  mailer = [self _mailerWithSmtpUrl: nil
                       userIdAccount: @"1"];

  testEquals ([mailer valueForKey: @"smtpServer"], nil);
  testEquals ([mailer valueForKey: @"userIdAccount"], @"0");

  [mailer release];
}

@end
