/* TestWORequestMacOSXClientDetection.m - this file is part of SOGo
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
 * along with this program; see the file COPYING.  If not, see
 * <http://www.gnu.org/licenses/>.
 */

#import <Foundation/Foundation.h>
#import <NGObjWeb/WORequest.h>

#import "SOGo/WORequest+SOGo.h"

#import "SOGoTest.h"

@interface TestWORequestMacOSXClientDetection : SOGoTest
@end

@implementation TestWORequestMacOSXClientDetection

- (WORequest *) _requestWithUserAgent: (NSString *) userAgent
{
  NSDictionary *headers;

  headers = nil;
  if (userAgent)
    headers = [NSDictionary dictionaryWithObject: userAgent
                                         forKey: @"user-agent"];

  return [[[WORequest alloc] initWithMethod: @"PROPFIND"
                                        uri: @"/SOGo/dav/user/Contacts/personal/"
                                httpVersion: @"HTTP/1.1"
                                    headers: headers
                                    content: nil
                                  userInfo: nil] autorelease];
}

- (void) test_isMacOSXCalendarForVenturaDataaccessd
{
  test ([[self _requestWithUserAgent:
            @"macOS/13.3 (22E252) dataaccessd/2050.22.1"] isMacOSXCalendar]);
  test ([[self _requestWithUserAgent:
            @"macOS/14.1 (23B74) dataaccessd/2600.20.1"] isMacOSXCalendar]);
}

- (void) test_isMacOSXCalendarForIOSDataaccessd
{
  test (![[self _requestWithUserAgent:
             @"iOS/16.4 (20E239) dataaccessd/1.0"] isMacOSXCalendar]);
}

- (void) test_isMacOSXCalendarForCalendarAgent
{
  test (![[self _requestWithUserAgent:
             @"macOS/11.0.1 (20B50) CalendarAgent/954"] isMacOSXCalendar]);
}

- (void) test_isMacOSXCalendarWithoutUserAgent
{
  test (![[self _requestWithUserAgent: nil] isMacOSXCalendar]);
}

- (void) test_isMacOSXAddressBookAppForVenturaContacts
{
  test ([[self _requestWithUserAgent:
            @"macOS/13.3 (22E252) AddressBookCore/2452"] isMacOSXAddressBookApp]);
  test (![[self _requestWithUserAgent:
             @"macOS/13.3 (22E252) AddressBookCore/2452"] isMacOSXCalendar]);
}

- (void) test_isMacOSXAddressBookAppForLegacyContacts
{
  test ([[self _requestWithUserAgent:
            @"Mac OS X/10.8.2 (12C60) AddressBook/1167"] isMacOSXAddressBookApp]);
  test ([[self _requestWithUserAgent:
            @"AddressBook/6.1.2 (1090) CardDAVPlugin/200 CFNetwork/520.4.3 Mac_OS_X/10.7.4 (11E53)"]
         isMacOSXAddressBookApp]);
}

- (void) test_isMacOSXAddressBookAppForVenturaDataaccessd
{
  test (![[self _requestWithUserAgent:
             @"macOS/13.3 (22E252) dataaccessd/2050.22.1"] isMacOSXAddressBookApp]);
}

@end
