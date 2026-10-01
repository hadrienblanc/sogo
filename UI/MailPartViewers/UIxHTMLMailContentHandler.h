/* UIxHTMLMailContentHandler.h - this file is part of SOGo
 *
 * Copyright (C) 2007-2026 Inverse inc.
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
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef UIXHTMLMAILCONTENTHANDLER_H
#define UIXHTMLMAILCONTENTHANDLER_H

#import <Foundation/NSDictionary.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#import <SaxObjC/SaxAttributes.h>
#import <SaxObjC/SaxContentHandler.h>
#import <SaxObjC/SaxLexicalHandler.h>

#include <libxml/encoding.h>

@interface _UIxHTMLMailContentHandler : NSObject <SaxContentHandler, SaxLexicalHandler>
{
  NSMutableString *result;
  NSMutableString *css;
  NSDictionary *attachmentIds;
  int ignoredContent, embeddedCSSLevel;
  NSString *ignoreTag;
  BOOL inBody;
  BOOL inStyle;
  BOOL inCSSDeclaration;
  BOOL hasEmbeddedCSS;
  xmlCharEncoding contentEncoding;
  BOOL rawContent;
  // Wrap libxml2-orphaned <a> around the following block element
  // (HTML5 pattern <a><table>...</table></a> auto-closed by libxml2 HTML4 DTD).
  NSString    *pendingAnchorTag;
  NSString    *anchorWrapTag;
  NSUInteger   anchorWrapDepth;
  NSString    *lastAnchorOpenString;
  NSUInteger   lastAnchorOpenEnd;
}

+ (NSArray *) voidTags;

- (NSString *) result;
- (NSString *) css;
- (void) activateRawContent;
- (void) setContentEncoding: (xmlCharEncoding) newContentEncoding;
- (void) setAttachmentIds: (NSDictionary *) newAttachmentIds;

@end

#endif /* UIXHTMLMAILCONTENTHANDLER_H */
