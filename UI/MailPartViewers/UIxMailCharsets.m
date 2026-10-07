/* UIxMailCharsets.m - this file is part of SOGo
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

#import <Foundation/NSString.h>

#import "UIxMailCharsets.h"

xmlCharEncoding UIxMailCharsetToXMLEncoding(NSString *charset)
{
  struct { NSString *name; xmlCharEncoding encoding; } xmlEncodings[] = {
    { @"us-ascii", XML_CHAR_ENCODING_ASCII},
    { @"utf-8", XML_CHAR_ENCODING_UTF8},
    { @"utf8", XML_CHAR_ENCODING_UTF8},		// broken mailers
    { @"utf-16le", XML_CHAR_ENCODING_UTF16LE},
    { @"utf-16be",  XML_CHAR_ENCODING_UTF16BE},
    { @"ucs-4le", XML_CHAR_ENCODING_UCS4LE},
    { @"ucs-4be", XML_CHAR_ENCODING_UCS4BE},
    { @"ebcdic", XML_CHAR_ENCODING_EBCDIC},
    { @"iso8859_1", XML_CHAR_ENCODING_8859_1},
    { @"iso-8859-1", XML_CHAR_ENCODING_8859_1},
    { @"iso-8859-2",  XML_CHAR_ENCODING_8859_2},
    { @"iso-8859-3", XML_CHAR_ENCODING_8859_3},
    { @"iso-8859-4", XML_CHAR_ENCODING_8859_4},
    { @"iso-8859-5", XML_CHAR_ENCODING_8859_5},
    { @"iso-8859-6", XML_CHAR_ENCODING_8859_6},
    { @"iso-8859-7", XML_CHAR_ENCODING_8859_7},
    { @"iso-8859-8", XML_CHAR_ENCODING_8859_8},
    { @"iso-8859-9", XML_CHAR_ENCODING_8859_9},
    { @"iso-8859-11", XML_CHAR_ENCODING_ERROR},
    { @"iso-8859-13", XML_CHAR_ENCODING_ERROR},
    { @"iso-2022-jp", XML_CHAR_ENCODING_2022_JP},
//     { @"iso-2022-jp", XML_CHAR_ENCODING_SHIFT_JIS},
    { @"koi8-r", XML_CHAR_ENCODING_ERROR},       // unsupported, will trigger koi8-r -> utf8 conversion
    { @"koi8-u", XML_CHAR_ENCODING_ERROR},       // unsupported, will trigger koi8-u -> utf8 conversion
    { @"windows-1250", XML_CHAR_ENCODING_ERROR}, // unsupported, will trigger windows-1250 -> utf8 conversion
    { @"windows-1251", XML_CHAR_ENCODING_ERROR}, // unsupported, will trigger windows-1251 -> utf8 conversion
    { @"windows-1255", XML_CHAR_ENCODING_ERROR}, // unsupported, will trigger windows-1255 -> utf8 conversion
    { @"windows-1256", XML_CHAR_ENCODING_ERROR}, // unsupported, will trigger windows-1255 -> utf8 conversion
    { @"windows-1257", XML_CHAR_ENCODING_ERROR}, // unsupported, will trigger windows-1257 -> utf8 conversion
    { @"windows-874", XML_CHAR_ENCODING_ERROR},  // unsupported, will trigger windows-874 -> utf8 conversion
    { @"tis-620", XML_CHAR_ENCODING_ERROR},      // unsupported, will trigger windows-874 -> utf8 conversion
    { @"gb2312", XML_CHAR_ENCODING_ERROR},       // unsupported, will trigger gb2312 -> utf8 conversion
    { @"gbk", XML_CHAR_ENCODING_ERROR},          // unsupported, will trigger gb2312 -> utf8 conversion
    { @"gb18030", XML_CHAR_ENCODING_ERROR},      // unsupported, will trigger gb2312 -> utf8 conversion
    { @"big5", XML_CHAR_ENCODING_ERROR},         // unsupported, will trigger gb2312 -> utf8 conversion
    { @"euc-jp", XML_CHAR_ENCODING_EUC_JP}};
  unsigned count;
  xmlCharEncoding encoding;

  encoding = XML_CHAR_ENCODING_NONE;
  count = 0;

  while (encoding == XML_CHAR_ENCODING_NONE
	 && count < (sizeof (xmlEncodings) / sizeof (xmlEncodings[0])))
    if ([charset isEqualToString: xmlEncodings[count].name])
      encoding = xmlEncodings[count].encoding;
    else
      count++;

  if (encoding == XML_CHAR_ENCODING_NONE)
    encoding = XML_CHAR_ENCODING_8859_1;

  return encoding;
}
