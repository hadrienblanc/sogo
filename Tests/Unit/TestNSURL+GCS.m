/* TestNSURL+GCS.m - this file is part of SOGo
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

#import <Foundation/NSURL.h>

#import <GDLContentStore/NSURL+GCS.h>

#import "SOGoTest.h"

@interface TestNSURL_plusGCS : SOGoTest
@end

@implementation TestNSURL_plusGCS

- (void) test_gcsURLWithoutCredentials
{
  testEquals([[[NSURL URLWithString: @"mysql://sogo:secret@127.0.0.1:3306/sogo/sogo_folder_info"]
                gcsURLWithoutCredentials] absoluteString],
             @"mysql://127.0.0.1:3306/sogo/sogo_folder_info");
  testEquals([[[NSURL URLWithString: @"postgresql://sogo:sec%40ret@db.example.org:5432/sogo/sogox001"]
                gcsURLWithoutCredentials] absoluteString],
             @"postgresql://db.example.org:5432/sogo/sogox001");
  testEquals([[[NSURL URLWithString: @"mysql://sogo@127.0.0.1:3306/sogo/sogox001"]
                gcsURLWithoutCredentials] absoluteString],
             @"mysql://127.0.0.1:3306/sogo/sogox001");
  testEquals([[[NSURL URLWithString: @"mysql://127.0.0.1:3306/sogo/sogox001"]
                gcsURLWithoutCredentials] absoluteString],
             @"mysql://127.0.0.1:3306/sogo/sogox001");
  testEquals([[[NSURL URLWithString: @"mysql://sogo:secret@[::1]:3306/sogo/sogox001"]
                gcsURLWithoutCredentials] absoluteString],
             @"mysql://[::1]:3306/sogo/sogox001");
  testEquals([[[NSURL URLWithString: @"sqlite:///var/lib/sogo/sogo_folder_info"]
                gcsURLWithoutCredentials] absoluteString],
             @"sqlite:///var/lib/sogo/sogo_folder_info");
  testEquals([[NSURL URLWithString: @"mysql://sogo:secret@127.0.0.1:3306/sogo/sogox001"]
                gcsURLWithoutCredentials],
             [NSURL URLWithString: @"mysql://127.0.0.1:3306/sogo/sogox001"]);
}

- (void) test_gcsURLWithCredentialsFromURL
{
  testEquals([[[NSURL URLWithString: @"mysql://127.0.0.1:3306/sogo/sogox001"]
                gcsURLWithCredentialsFromURL:
                  [NSURL URLWithString: @"mysql://sogo:secret@127.0.0.1:3306/sogo/sogo_folder_info"]]
               absoluteString],
             @"mysql://sogo:secret@127.0.0.1:3306/sogo/sogox001");
  testEquals([[[NSURL URLWithString: @"mysql://127.0.0.1:3306/sogo/sogox001_quick"]
                gcsURLWithCredentialsFromURL:
                  [NSURL URLWithString: @"mysql://sogo:sec%40ret@127.0.0.1:3306/sogo/sogo_folder_info"]]
               absoluteString],
             @"mysql://sogo:sec%40ret@127.0.0.1:3306/sogo/sogox001_quick");
  testEquals([[[NSURL URLWithString: @"mysql://127.0.0.1:3306/sogo/sogox001"]
                gcsURLWithCredentialsFromURL:
                  [NSURL URLWithString: @"mysql://sogo:secret@[::1]:3306/sogo/sogo_folder_info"]]
               absoluteString],
             @"mysql://sogo:secret@127.0.0.1:3306/sogo/sogox001");
  testEquals([[[NSURL URLWithString: @"mysql://sogo:oldpass@127.0.0.1:3306/sogo/sogox001"]
                gcsURLWithCredentialsFromURL:
                  [NSURL URLWithString: @"mysql://sogo:secret@127.0.0.1:3306/sogo/sogo_folder_info"]]
               absoluteString],
             @"mysql://sogo:oldpass@127.0.0.1:3306/sogo/sogox001");
  testEquals([[[NSURL URLWithString: @"mysql://127.0.0.1:3306/sogo/sogox001"]
                gcsURLWithCredentialsFromURL:
                  [NSURL URLWithString: @"mysql://127.0.0.1:3306/sogo/sogo_folder_info"]]
               absoluteString],
             @"mysql://127.0.0.1:3306/sogo/sogox001");
  testEquals([[[NSURL URLWithString: @"sqlite:///var/lib/sogo/sogox001"]
                gcsURLWithCredentialsFromURL:
                  [NSURL URLWithString: @"sqlite:///var/lib/sogo/sogo_folder_info"]]
               absoluteString],
             @"sqlite:///var/lib/sogo/sogox001");
  testEquals([[[NSURL URLWithString: @"mysql://127.0.0.1:3306/sogo/sogox001"]
                gcsURLWithCredentialsFromURL: nil] absoluteString],
             @"mysql://127.0.0.1:3306/sogo/sogox001");
}

- (void) test_folderLocationRoundTripKeepsCredentialsOutOfStoredURL
{
  NSURL *folderInfoLocation, *storedLocation, *folderLocation;
  NSString *baseURL, *sanitizedBaseURL;
  NSRange range;

  folderInfoLocation
    = [NSURL URLWithString: @"mysql://sogo:sec%40ret@127.0.0.1:3306/sogo/sogo_folder_info"];

  baseURL = [[folderInfoLocation gcsURLWithoutCredentials] absoluteString];
  range = [baseURL rangeOfString: @"/" options: NSBackwardsSearch];
  sanitizedBaseURL = [baseURL substringToIndex: range.location];
  storedLocation = [NSURL URLWithString:
                             [NSString stringWithFormat: @"%@/sogouserabc001",
                                      sanitizedBaseURL]];

  testEquals([storedLocation absoluteString],
             @"mysql://127.0.0.1:3306/sogo/sogouserabc001");
  testEquals([storedLocation gcsTableName], @"sogouserabc001");

  folderLocation = [storedLocation gcsURLWithCredentialsFromURL: folderInfoLocation];
  testEquals([folderLocation absoluteString],
             @"mysql://sogo:sec%40ret@127.0.0.1:3306/sogo/sogouserabc001");
  testEquals([folderLocation user], @"sogo");
  testEquals([folderLocation password], @"sec@ret");
  testEquals([folderLocation gcsTableName], @"sogouserabc001");
  testEquals([folderLocation gcsURLId],
             [folderInfoLocation gcsURLId]);
}

@end
