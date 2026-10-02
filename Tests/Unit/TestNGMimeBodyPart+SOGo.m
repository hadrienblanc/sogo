/* TestNGMimeBodyPart+SOGo.m - this file is part of SOGo
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
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSString.h>

#import "SOGoTest.h"
#import <SOGo/NGMimeBodyPart+SOGo.h>
#import <NGExtensions/NGHashMap.h>

@interface TestNGMimeBodyPart_plus_SOGo : SOGoTest
@end

@implementation TestNGMimeBodyPart_plus_SOGo

- (NGMimeBodyPart *) bodyPartWithContentType: (NSString *) contentType
{
  NGMutableHashMap *header;
  NGMimeBodyPart *part;

  header = [[[NGMutableHashMap alloc] initWithCapacity: 2] autorelease];
  [header setObject: contentType forKey: @"content-type"];
  part = [[[NGMimeBodyPart alloc] initWithHeader: header] autorelease];

  return part;
}

- (void) test_isImageWithSVGMimeTypeOfTicket6152
{
  test ([[self bodyPartWithContentType: @"image/svg+xml"] isImage]);
  test ([[self bodyPartWithContentType: @"image/svg+xml; name=\"signature.svg\""] isImage]);
}

- (void) test_isImageWithKnownImageMimeTypes
{
  test ([[self bodyPartWithContentType: @"image/png"] isImage]);
  test ([[self bodyPartWithContentType: @"image/gif"] isImage]);
  test ([[self bodyPartWithContentType: @"image/jpeg"] isImage]);
}

- (void) test_isImageWithNonImageMimeTypes
{
  test (![[self bodyPartWithContentType: @"application/pdf"] isImage]);
  test (![[self bodyPartWithContentType: @"text/html"] isImage]);
}

@end
