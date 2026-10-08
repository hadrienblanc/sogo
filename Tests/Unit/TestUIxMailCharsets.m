/* TestUIxMailCharsets.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import "UIxMailCharsets.h"

#import "SOGoTest.h"

@implementation TestUIxMailCharsets : SOGoTest

- (void) test_thaiCharsetsTriggerConversion
{
  test(UIxMailCharsetToXMLEncoding(@"iso-8859-11") == XML_CHAR_ENCODING_ERROR);
  test(UIxMailCharsetToXMLEncoding(@"tis-620") == XML_CHAR_ENCODING_ERROR);
  test(UIxMailCharsetToXMLEncoding(@"windows-874") == XML_CHAR_ENCODING_ERROR);
}

- (void) test_knownCharsetsMapToNativeEncodings
{
  test(UIxMailCharsetToXMLEncoding(@"utf-8") == XML_CHAR_ENCODING_UTF8);
  test(UIxMailCharsetToXMLEncoding(@"iso-8859-1") == XML_CHAR_ENCODING_8859_1);
  test(UIxMailCharsetToXMLEncoding(@"us-ascii") == XML_CHAR_ENCODING_ASCII);
}

- (void) test_unknownCharsetFallsBackToLatin1
{
  test(UIxMailCharsetToXMLEncoding(@"x-unknown-charset") == XML_CHAR_ENCODING_8859_1);
}

@end
