/* TestNGMimeTypeUnknownParameters.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGMime/NGMimeType.h>

#import "SOGoTest.h"

@interface TestNGMimeTypeUnknownParameters : SOGoTest
@end

@implementation TestNGMimeTypeUnknownParameters

- (void) _assertToleratedTextPlain: (NGMimeType *) mimeType
{
  testEqualsWithMessage ([mimeType type], @"text", @"type lost");
  testEqualsWithMessage ([mimeType subType], @"plain", @"subtype lost");
  testEqualsWithMessage ([mimeType characterSet], @"us-ascii", @"charset lost");
  testWithMessage ([mimeType valueOfParameter: @"type"] == nil,
                   @"unmodelled 'type' parameter exposed on text/*");
  testWithMessage ([mimeType valueOfParameter: @"boundary"] == nil,
                   @"unmodelled 'boundary' parameter exposed on text/*");
  testEqualsWithMessage ([mimeType stringValue],
                         @"text/plain; charset=us-ascii",
                         @"unmodelled parameters leaked into serialization");
}

/* bug 5910: mails gatewayed from a flattened multipart keep the obsolete
   'type' and 'boundary' parameters on a text/plain Content-Type. */
- (void) test_unknownParametersOnTextType
{
  NGMimeType *mimeType;

  mimeType = [NGMimeType mimeType:
                         @"text/plain; charset=us-ascii; "
                         @"type=multipart/alternative; "
                         @"boundary=\"_0047eb61e13b1a148d9b249c350588e0b7cictex01ictbbch_\""];
  testWithMessage (mimeType != nil, @"parsing of the Content-Type failed");

  [self _assertToleratedTextPlain: mimeType];
}

/* bug 5910: the same header, folded inside the quoted boundary value. */
- (void) test_foldedUnknownParametersOnTextType
{
  NGMimeType *mimeType;

  mimeType = [NGMimeType mimeType:
                         @"text/plain; charset=us-ascii; "
                         @"type=\"multipart/alternative\";\n\t"
                         @"boundary=\"_004\n\t"
                         @"7eb61e13b1a148d9b249c350588e0b7cictex01ictbbch\n\t\""];
  testWithMessage (mimeType != nil, @"parsing of the folded Content-Type failed");

  [self _assertToleratedTextPlain: mimeType];
}

/* bug 5910: IMAP BODYSTRUCTURE path — Dovecot hands the stale parameters
   over as a plain dictionary and SOPE builds the NGMimeType from
   type/subtype/parameters triplets. */
- (void) test_bodyStructureParametersOnTextType
{
  NSDictionary *parameters;
  NGMimeType *mimeType;

  parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"us-ascii", @"charset",
                          @"multipart/alternative", @"type",
                          @"_0047eb61e13b1a148d9b249c350588e0b7cictex01ictbbch_",
                          @"boundary",
                          nil];
  mimeType = [NGMimeType mimeType: @"text"
                          subType: @"plain"
                       parameters: parameters];
  testWithMessage (mimeType != nil, @"instantiation from BODYSTRUCTURE failed");

  [self _assertToleratedTextPlain: mimeType];
}

@end
