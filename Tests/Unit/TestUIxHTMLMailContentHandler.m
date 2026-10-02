/* TestUIxHTMLMailContentHandler.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any
 * later version.
 *
 * This file is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

#import <Foundation/Foundation.h>
#import <SaxObjC/SaxAttributes.h>

#import "UIxHTMLMailContentHandler.h"
#import "SOGoTest.h"

@interface TestUIxHTMLMailContentHandler : SOGoTest
{
  _UIxHTMLMailContentHandler *handler;
}

- (void) feedStyle: (NSString *) css;
- (void) feedBodyCharacters: (NSString *) text;
- (void) feedBodyElement: (NSString *) name
              attributes: (SaxAttributes *) attributes
                  rawTag: (NSString *) rawTag;

@end

@implementation TestUIxHTMLMailContentHandler

- (void) setUp
{
  handler = [[_UIxHTMLMailContentHandler alloc] init];
  [handler setContentEncoding: XML_CHAR_ENCODING_UTF8];
  [handler startDocument];
  [handler startElement: @"html" namespace: nil rawName: @"html" attributes: nil];
}

- (void) tearDown
{
  [handler release];
}

- (void) _sendCharacters: (NSString *) text
{
  unichar *characters;

  characters = malloc (sizeof (unichar) * [text length]);
  [text getCharacters: characters];
  [handler characters: characters length: [text length]];
  free (characters);
}

- (void) _openBody
{
  [handler startElement: @"body" namespace: nil rawName: @"body" attributes: nil];
}

- (void) _closeBody
{
  [handler endElement: @"body" namespace: nil rawName: @"body"];
}

- (void) feedStyle: (NSString *) css
{
  [handler startElement: @"head" namespace: nil rawName: @"head" attributes: nil];
  [handler startElement: @"style" namespace: nil rawName: @"style" attributes: nil];
  [self _sendCharacters: css];
  [handler endElement: @"style" namespace: nil rawName: @"style"];
  [handler endElement: @"head" namespace: nil rawName: @"head"];
}

- (void) feedBodyCharacters: (NSString *) text
{
  [self _openBody];
  [self _sendCharacters: text];
  [self _closeBody];
}

- (void) feedBodyElement: (NSString *) name
              attributes: (SaxAttributes *) attributes
                  rawTag: (NSString *) rawTag
{
  [self _openBody];
  [handler startElement: name namespace: nil rawName: rawTag attributes: attributes];
  [handler endElement: name namespace: nil rawName: rawTag];
  [self _closeBody];
}

- (void) test_atRuleStatementDoesNotSwallowNextRule
{
  [self feedStyle: @"@import url(\"https://fonts.example.com/css?family=Calibri\");p.MsoNormal {margin:0cm;}"];
  [self feedBodyCharacters: @"x"];

  testWithMessage ([[handler css] rangeOfString: @".SOGoHTMLMail-CSS-Delimiter p.MsoNormal"].location != NSNotFound,
                   @"rule following brace-less at-rule must be kept");
  testWithMessage ([[handler css] rangeOfString: @"margin:0cm !important;"].location != NSNotFound,
                   @"declaration following brace-less at-rule must be kept");
  testWithMessage ([[handler css] rangeOfString: @"@import"].location == NSNotFound,
                   @"at-rule statement must not leak in css");
}

- (void) test_charsetAtRuleDoesNotSwallowNextRule
{
  [self feedStyle: @"@charset \"utf-8\";p.MsoNormal {margin:0cm;}"];
  [self feedBodyCharacters: @"x"];

  testWithMessage ([[handler css] rangeOfString: @".SOGoHTMLMail-CSS-Delimiter p.MsoNormal"].location != NSNotFound,
                   @"rule following @charset must be kept");
  testWithMessage ([[handler css] rangeOfString: @"margin:0cm !important;"].location != NSNotFound,
                   @"declaration following @charset must be kept");
}

- (void) test_atRuleSemicolonInsideBlockIsNotATerminator
{
  [self feedStyle: @"@font-face {font-family:\"Cambria Math\";panose-1:2 4 5 3;}p.MsoNormal {margin:0cm;}"];
  [self feedBodyCharacters: @"x"];

  testWithMessage ([[handler css] rangeOfString: @"Cambria Math"].location == NSNotFound,
                   @"braced at-rule block must stay dropped");
  testWithMessage ([[handler css] rangeOfString: @".SOGoHTMLMail-CSS-Delimiter p.MsoNormal"].location != NSNotFound,
                   @"rule following braced at-rule must be kept");
}

- (void) test_pageAtRuleOfWordMails
{
  [self feedStyle: @"@page WordSection1 {size:612.0pt 792.0pt;margin:72.0pt 72.0pt;}div.WordSection1 {page:WordSection1;}"];
  [self feedBodyCharacters: @"x"];

  testWithMessage ([[handler css] rangeOfString: @"size:612.0pt"].location == NSNotFound,
                   @"@page block must stay dropped");
  testWithMessage ([[handler css] rangeOfString: @"div.WordSection1"].location != NSNotFound,
                   @"rule following @page must be kept");
  testWithMessage ([[handler css] rangeOfString: @"page:WordSection1 !important;"].location != NSNotFound,
                   @"declaration following @page must be kept");
}

- (void) test_mediaBlockRulesStayDropped
{
  [self feedStyle: @"@media screen {p.MsoPlain {margin:0cm;}}p.MsoNormal {margin:0cm;}"];
  [self feedBodyCharacters: @"x"];

  testWithMessage ([[handler css] rangeOfString: @"MsoPlain"].location == NSNotFound,
                   @"@media inner rules must stay dropped");
  testWithMessage ([[handler css] rangeOfString: @".SOGoHTMLMail-CSS-Delimiter p.MsoNormal"].location != NSNotFound,
                   @"rule following @media must be kept");
}

- (void) test_msoPropertiesArePreserved
{
  [self feedStyle: @"p.MsoNormal {mso-margin-top-alt:0;mso-line-height-rule:exactly;line-height:24px;}"];
  [self feedBodyCharacters: @"x"];

  testWithMessage ([[handler css] rangeOfString: @"mso-margin-top-alt:0 !important;"].location != NSNotFound,
                   @"mso-margin-top-alt must be passed through");
  testWithMessage ([[handler css] rangeOfString: @"mso-line-height-rule:exactly !important;"].location != NSNotFound,
                   @"mso-line-height-rule must be passed through");
}

- (void) test_msoRuleFromWordMails
{
  [self feedStyle: @"p.MsoNormal, li.MsoNormal, div.MsoNormal {margin:0cm;margin-bottom:.0001pt;font-family:\"Calibri\",sans-serif;}"];
  [self feedBodyCharacters: @"x"];

  testWithMessage ([[handler css] rangeOfString: @".SOGoHTMLMail-CSS-Delimiter p.MsoNormal,"].location != NSNotFound,
                   @"first selector must be prefixed");
  testWithMessage ([[handler css] rangeOfString: @".SOGoHTMLMail-CSS-Delimiter  li.MsoNormal,"].location != NSNotFound,
                   @"comma-separated selectors must be prefixed");
  testWithMessage ([[handler css] rangeOfString: @".SOGoHTMLMail-CSS-Delimiter  div.MsoNormal"].location != NSNotFound,
                   @"last selector must be prefixed");
  testWithMessage ([[handler css] rangeOfString: @"margin-bottom:.0001pt !important;"].location != NSNotFound,
                   @"declarations must receive !important");
}

- (void) test_existingImportantIsNotDuplicated
{
  [self feedStyle: @"p {color:red !important;font-size:10pt;}"];
  [self feedBodyCharacters: @"x"];

  testWithMessage ([[handler css] rangeOfString: @"!important !important"].location == NSNotFound,
                   @"!important must not be duplicated");
  testWithMessage ([[handler css] rangeOfString: @"font-size:10pt !important;"].location != NSNotFound,
                   @"trailing declaration must receive !important");
}

- (void) test_bodySelectorIsReplaced
{
  [self feedStyle: @"body {margin:0;}"];
  [self feedBodyCharacters: @"x"];

  testWithMessage ([[handler css] rangeOfString: @".SOGoHTMLMail-CSS-Delimiter body"].location == NSNotFound,
                   @"body selector must be rewritten");
  testWithMessage ([[handler css] rangeOfString: @".SOGoHTMLMail-CSS-Delimiter  {margin:0 !important;}"].location != NSNotFound,
                   @"body selector must be rewritten to the delimiter class");
}

- (void) test_htmlCommentsInStyleAreStripped
{
  [self feedStyle: @"<!--p.MsoNormal {margin:0cm;}-->"];
  [self feedBodyCharacters: @"x"];

  testWithMessage ([[handler css] rangeOfString: @"<!--"].location == NSNotFound,
                   @"html comment delimiters must be stripped");
  testWithMessage ([[handler css] rangeOfString: @"margin:0cm !important;"].location != NSNotFound,
                   @"rule inside html comment must be kept");
}

- (void) test_cssCommentsInStyleAreStripped
{
  [self feedStyle: @"/* Style Definitions */p.MsoNormal {margin:0cm;}"];
  [self feedBodyCharacters: @"x"];

  testWithMessage ([[handler css] rangeOfString: @"/*"].location == NSNotFound,
                   @"css comments must be stripped");
  testWithMessage ([[handler css] rangeOfString: @"margin:0cm !important;"].location != NSNotFound,
                   @"rule after css comment must be kept");
}

- (void) test_bannedTagsAreDroppedFromBody
{
  [self _openBody];
  [handler startElement: @"script" namespace: nil rawName: @"script" attributes: nil];
  [self _sendCharacters: @"alert(1)"];
  [handler endElement: @"script" namespace: nil rawName: @"script"];
  [self _sendCharacters: @"visible"];
  [self _closeBody];

  testWithMessage ([[handler result] rangeOfString: @"alert"].location == NSNotFound,
                   @"script content must be dropped");
  testWithMessage ([[handler result] rangeOfString: @"visible"].location != NSNotFound,
                   @"body content must be kept");
}

- (void) test_onEventAttributesAreDropped
{
  SaxAttributes *attributes;

  attributes = [[[SaxAttributes alloc] init] autorelease];
  [attributes addAttribute: @"onclick" uri: nil rawName: @"onclick"
                      type: @"CDATA" value: @"alert(1)"];

  [self feedBodyElement: @"p" attributes: attributes rawTag: @"p"];

  testWithMessage ([[handler result] rangeOfString: @"onclick"].location == NSNotFound,
                   @"on* attributes must be dropped");
}

- (void) test_styleAttributeWithUrlIsRenamed
{
  SaxAttributes *attributes;

  attributes = [[[SaxAttributes alloc] init] autorelease];
  [attributes addAttribute: @"style" uri: nil rawName: @"style"
                      type: @"CDATA" value: @"background:url('http://www.example.com/x.png')"];

  [self feedBodyElement: @"div" attributes: attributes rawTag: @"div"];

  testWithMessage ([[handler result] rangeOfString: @"unsafe-style"].location != NSNotFound,
                   @"style attributes holding an url must be renamed");
}

- (void) test_cidImageSrcIsRewritten
{
  SaxAttributes *attributes;
  NSDictionary *attachmentIds;

  attributes = [[[SaxAttributes alloc] init] autorelease];
  [attributes addAttribute: @"src" uri: nil rawName: @"src"
                      type: @"CDATA" value: @"cid:logo@example.com"];

  attachmentIds = [NSDictionary dictionaryWithObject: @"/attachment/42"
                                              forKey: @"<logo@example.com>"];
  [handler setAttachmentIds: attachmentIds];
  [self feedBodyElement: @"img" attributes: attributes rawTag: @"img"];

  testWithMessage ([[handler result] rangeOfString: @"/attachment/42"].location != NSNotFound,
                   @"cid: sources must be rewritten");
  testWithMessage ([[handler result] rangeOfString: @"cid:"].location == NSNotFound,
                   @"cid: sources must not leak");
}

- (void) test_externalImageSrcIsRenamed
{
  SaxAttributes *attributes;

  attributes = [[[SaxAttributes alloc] init] autorelease];
  [attributes addAttribute: @"src" uri: nil rawName: @"src"
                      type: @"CDATA" value: @"http://www.example.com/x.png"];

  [self feedBodyElement: @"img" attributes: attributes rawTag: @"img"];

  testWithMessage ([[handler result] rangeOfString: @"unsafe-src"].location != NSNotFound,
                   @"external img sources must be renamed");
}

- (void) test_bodyTextIsEscaped
{
  [self feedBodyCharacters: @"<b>bold</b>"];

  testWithMessage ([[handler result] rangeOfString: @"&lt;b&gt;bold&lt;/b&gt;"].location != NSNotFound,
                   @"body text must be html-escaped");
}

- (void) test_voidTagIsEmittedSelfClosed
{
  [self feedBodyElement: @"br" attributes: nil rawTag: @"br"];

  testWithMessage ([[handler result] rangeOfString: @"<br/>"].location != NSNotFound,
                   @"void tags must be emitted self-closed");
}

@end
