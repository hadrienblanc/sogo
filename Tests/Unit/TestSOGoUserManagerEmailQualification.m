/* TestSOGoUserManagerEmailQualification.m - this file is part of SOGo
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
#import <Foundation/NSString.h>

#import <SOGo/SOGoUserManager.h>

#import "SOGoTest.h"

@interface SOGoUserManager (TestEmailQualification)
- (void) _qualifyEmails: (NSMutableArray *) emails
          withMailDomain: (NSString *) mailDomain;
@end

@interface TestSOGoUserManagerEmailQualification : SOGoTest
{
  SOGoUserManager *userManager;
}
@end

@implementation TestSOGoUserManagerEmailQualification

- (id) init
{
  if ((self = [super init]))
    userManager = [[SOGoUserManager alloc] init];

  return self;
}

- (void) dealloc
{
  [userManager release];

  [super dealloc];
}

- (NSArray *) _qualifiedEmails: (NSArray *) emails
                  withMailDomain: (NSString *) mailDomain
{
  NSMutableArray *list;

  list = [NSMutableArray arrayWithArray: emails];
  [userManager _qualifyEmails: list withMailDomain: mailDomain];

  return list;
}

- (void) test_domainlessAliasIsQualifiedWithMailDomain
{
  NSArray *emails;

  emails = [self _qualifiedEmails: [NSArray arrayWithObjects:
                                       @"l.l.robinson",
                                       @"spoons",
                                       @"leon.robinson",
                                       nil]
                           withMailDomain: @"therobinsonfamily.net"];

  testEquals([emails objectAtIndex: 0], @"l.l.robinson@therobinsonfamily.net");
  testEquals([emails objectAtIndex: 1], @"spoons@therobinsonfamily.net");
  testEquals([emails objectAtIndex: 2], @"leon.robinson@therobinsonfamily.net");
}

- (void) test_mixedListKeepsQualifiedAddressesUntouched
{
  NSArray *emails;

  emails = [self _qualifiedEmails: [NSArray arrayWithObjects:
                                       @"baggypants@therobinsonfamily.net",
                                       @"spoons",
                                       nil]
                           withMailDomain: @"therobinsonfamily.net"];

  testEquals([emails objectAtIndex: 0], @"baggypants@therobinsonfamily.net");
  testEquals([emails objectAtIndex: 1], @"spoons@therobinsonfamily.net");
}

- (void) test_emptyMailDomainLeavesEmailsUnchanged
{
  NSArray *emails;

  emails = [self _qualifiedEmails: [NSArray arrayWithObject: @"spoons"]
                    withMailDomain: nil];
  testEquals([emails objectAtIndex: 0], @"spoons");

  emails = [self _qualifiedEmails: [NSArray arrayWithObject: @"spoons"]
                    withMailDomain: @""];
  testEquals([emails objectAtIndex: 0], @"spoons");
}

- (void) test_emptyEmailValueIsLeftAlone
{
  NSArray *emails;

  emails = [self _qualifiedEmails: [NSArray arrayWithObject: @""]
                    withMailDomain: @"therobinsonfamily.net"];

  testEquals([emails objectAtIndex: 0], @"");
}

- (void) test_emptyListStaysEmpty
{
  testEquals([NSNumber numberWithUnsignedInteger:
                [[self _qualifiedEmails: [NSArray array]
                          withMailDomain: @"therobinsonfamily.net"] count]],
             [NSNumber numberWithUnsignedInteger: 0]);
}

@end
