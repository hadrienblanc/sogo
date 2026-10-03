/* TestSOGoHTMLSanitizer.m - this file is part of SOGo
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
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

/* This file is encoded in utf-8. */

#import "SOGoTest.h"

#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>

#import <SaxObjC/SaxXMLReaderFactory.h>

#import <SOGo/SOGoHTMLSanitizer.h>
#import <SOGo/NSString+Utilities.h>

@interface TestSOGoHTMLSanitizer : SOGoTest
@end

@implementation TestSOGoHTMLSanitizer

- (NSString *) sanitize: (NSString *) html
{
  SOGoHTMLSanitizer *handler;
  id <NSObject, SaxXMLReader> parser;
  NSString *wrapped;
  NSData *data;

  wrapped = [NSString stringWithFormat: @"<html>%@</html>", html];
  data = [wrapped dataUsingEncoding: NSUTF8StringEncoding];

  handler = [[SOGoHTMLSanitizer new] autorelease];
  [handler setContentEncoding: XML_CHAR_ENCODING_UTF8];

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  [parser setContentHandler: handler];
  [parser parseFromSource: data];

  return [[[handler result] copy] autorelease];
}

- (void) test_contentAfterVoidTagsIsPreserved
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<p>first</p>"
              @"<img src=\"https://example.com/a.png\"/>"
              @"<br/>"
              @"<p>second <b>bold</b></p>"
              @"<img src=\"https://example.com/b.png\"/>"
              @"</body>"];

  error = [NSString stringWithFormat: @"text dropped: %@", result];
  testWithMessage ([result rangeOfString: @"first"].location != NSNotFound, error);
  testWithMessage ([result rangeOfString: @"second"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"tag dropped: %@", result];
  testWithMessage ([result rangeOfString: @"<b>bold</b>"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"image dropped: %@", result];
  testWithMessage ([result rangeOfString: @"a.png"].location != NSNotFound, error);
  testWithMessage ([result rangeOfString: @"b.png"].location != NSNotFound, error);
}

- (void) test_conditionalCommentWrappedImagesArePreserved
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<p>intro</p>"
              @"<a href=\"https://example.com/\">"
              @"<!--[if !mso]><!-->"
              @"<div><img src=\"https://example.com/big.png\"/></div>"
              @"<!--<![endif]-->"
              @"<!--[if mso]><v:roundrect></v:roundrect><![endif]-->"
              @"</a>"
              @"<p>outro</p>"
              @"</body>"];

  error = [NSString stringWithFormat: @"content after comment dropped: %@", result];
  testWithMessage ([result rangeOfString: @"intro"].location != NSNotFound, error);
  testWithMessage ([result rangeOfString: @"outro"].location != NSNotFound, error);
  testWithMessage ([result rangeOfString: @"big.png"].location != NSNotFound, error);
}

- (void) test_conditionalCommentWrappedImagesSurviveInvalidTagCleanup
{
  NSString *preparsed, *result, *error;

  preparsed = [[NSString stringWithString:
                   @"<body>"
                   @"<p>intro</p>"
                   @"<a href=\"https://example.com/\">"
                   @"<!--[if !mso]><!-->"
                   @"<div><img src=\"https://example.com/big.png\"/></div>"
                   @"<!--<![endif]-->"
                   @"<!--[if mso]><v:roundrect></v:roundrect><![endif]-->"
                   @"</a>"
                   @"<p>outro</p>"
                   @"</body>"]
                 cleanInvalidHTMLTags];
  result = [self sanitize: preparsed];

  error = [NSString stringWithFormat: @"content after comment dropped: %@", result];
  testWithMessage ([result rangeOfString: @"intro"].location != NSNotFound, error);
  testWithMessage ([result rangeOfString: @"outro"].location != NSNotFound, error);
  testWithMessage ([result rangeOfString: @"big.png"].location != NSNotFound, error);
}

- (void) test_conditionalCommentWrappedTextSurvivesInvalidTagCleanup
{
  NSString *preparsed, *result, *error;

  preparsed = [[NSString stringWithString:
                   @"<body>"
                   @"<p>intro</p>"
                   @"<!--[if !mso]><!-->"
                   @"https://domain.tld"
                   @"<!--<![endif]-->"
                   @"<p>outro</p>"
                   @"</body>"]
                 cleanInvalidHTMLTags];
  result = [self sanitize: preparsed];

  error = [NSString stringWithFormat: @"url between conditional comments dropped: %@", result];
  testWithMessage ([result rangeOfString: @"https://domain.tld"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"content after conditional comments dropped: %@", result];
  testWithMessage ([result rangeOfString: @"intro"].location != NSNotFound, error);
  testWithMessage ([result rangeOfString: @"outro"].location != NSNotFound, error);
}

- (void) test_bannedTagsAreDropped
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<p>before</p>"
              @"<script>var evil = 1;</script>"
              @"<p>after</p>"
              @"</body>"];

  error = [NSString stringWithFormat: @"script content kept: %@", result];
  testWithMessage ([result rangeOfString: @"evil"].location == NSNotFound, error);
  error = [NSString stringWithFormat: @"content after script dropped: %@", result];
  testWithMessage ([result rangeOfString: @"after"].location != NSNotFound, error);
}

- (void) test_nestedBannedTagsDoNotWedgeTheIgnoreState
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<frameset><frame src=\"x\"></frameset>"
              @"<p>kept</p>"
              @"</body>"];

  error = [NSString stringWithFormat: @"content after frameset dropped: %@", result];
  testWithMessage ([result rangeOfString: @"kept"].location != NSNotFound, error);
}

- (void) test_nestedSameNameBannedTagsAreFullyIgnored
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body><frameset><frameset></frameset>LEAK</frameset><p>kept</p></body>"];
  error = [NSString stringWithFormat: @"banned inner content leaked: %@", result];
  testWithMessage ([result rangeOfString: @"LEAK"].location == NSNotFound, error);
  error = [NSString stringWithFormat: @"content after banned block dropped: %@", result];
  testWithMessage ([result rangeOfString: @"kept"].location != NSNotFound, error);
}

- (void) test_unclosedScriptAtEOF
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body><p>kept</p><script>var evil = 1;"];
  error = [NSString stringWithFormat: @"content before unclosed script dropped: %@", result];
  testWithMessage ([result rangeOfString: @"kept"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"script content kept: %@", result];
  testWithMessage ([result rangeOfString: @"evil"].location == NSNotFound, error);
}

- (void) test_styleBlocksAreCollected
{
  SOGoHTMLSanitizer *handler;
  id <NSObject, SaxXMLReader> parser;
  NSData *data;
  NSString *css, *error;

  data = [@"<html><body><style>p { color: red; }</style><p>text</p></body></html>"
           dataUsingEncoding: NSUTF8StringEncoding];

  handler = [[SOGoHTMLSanitizer new] autorelease];
  [handler setContentEncoding: XML_CHAR_ENCODING_UTF8];

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  [parser setContentHandler: handler];
  [parser parseFromSource: data];

  css = [handler css];
  error = [NSString stringWithFormat: @"css rules not collected or not scoped: %@", css];
  testWithMessage (css != nil
                   && [css rangeOfString: @".SOGoHTMLMail-CSS-Delimiter"].location != NSNotFound,
                   error);
}

- (void) test_bannedVoidTagsDoNotWedgeTheIgnoreState
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<p>before</p>"
              @"<link rel=\"stylesheet\" href=\"https://evil/x.css\">"
              @"<frame src=\"https://evil/x\">"
              @"<p>after</p>"
              @"</body>"];

  error = [NSString stringWithFormat: @"content after banned void tags dropped: %@", result];
  testWithMessage ([result rangeOfString: @"after"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"banned link kept: %@", result];
  testWithMessage ([result rangeOfString: @"evil/x.css"].location == NSNotFound, error);
}

- (void) test_remoteImageSourcesAreNeutralized
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<img src=\"https://example.com/remote.png\"/>"
              @"<img src=\"data:image/png;base64,iVBORw0KGgo=\"/>"
              @"</body>"];

  error = [NSString stringWithFormat: @"remote src not neutralized: %@", result];
  testWithMessage ([result rangeOfString: @"unsafe-src"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"base64 src neutralized: %@", result];
  testWithMessage ([result rangeOfString: @"data:image/png"].location != NSNotFound, error);
}

- (void) test_cidReferencesAreResolved
{
  SOGoHTMLSanitizer *handler;
  id <NSObject, SaxXMLReader> parser;
  NSData *data;
  NSString *result, *error;

  data = [@"<html><body><img src=\"cid:photo@localhost\"/></body></html>"
           dataUsingEncoding: NSUTF8StringEncoding];

  handler = [[SOGoHTMLSanitizer new] autorelease];
  [handler setContentEncoding: XML_CHAR_ENCODING_UTF8];
  [handler setAttachmentIds: [NSDictionary dictionaryWithObject: @"http://x/1"
                                                         forKey: @"<photo@localhost>"]];

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  [parser setContentHandler: handler];
  [parser parseFromSource: data];

  result = [[[handler result] copy] autorelease];

  error = [NSString stringWithFormat: @"cid not resolved: %@", result];
  testWithMessage ([result rangeOfString: @"http://x/1"].location != NSNotFound, error);
}

- (SOGoHTMLSanitizer *) sanitizeHTML: (NSString *) html
                           rawContent: (BOOL) raw
{
  SOGoHTMLSanitizer *handler;
  id <NSObject, SaxXMLReader> parser;
  NSData *data;

  data = [[NSString stringWithFormat: @"<html>%@</html>", html]
           dataUsingEncoding: NSUTF8StringEncoding];

  handler = [[SOGoHTMLSanitizer new] autorelease];
  [handler setContentEncoding: XML_CHAR_ENCODING_UTF8];
  if (raw)
    [handler activateRawContent];

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  [parser setContentHandler: handler];
  [parser parseFromSource: data];

  return handler;
}

- (void) test_cidResolutionFailureDropsTheAttribute
{
  SOGoHTMLSanitizer *handler;
  id <NSObject, SaxXMLReader> parser;
  NSData *data;
  NSString *result, *error;

  data = [@"<html><body>"
          @"<img src=\"cid:photo@localhost\"/>"
          @"<img src=\"cid:missing@localhost\"/>"
          @"</body></html>"
    dataUsingEncoding: NSUTF8StringEncoding];

  handler = [[SOGoHTMLSanitizer new] autorelease];
  [handler setContentEncoding: XML_CHAR_ENCODING_UTF8];
  [handler setAttachmentIds: [NSDictionary dictionaryWithObject: @"http://x/1"
                                                          forKey: @"<photo@localhost>"]];

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  [parser setContentHandler: handler];
  [parser parseFromSource: data];

  result = [[[handler result] copy] autorelease];

  error = [NSString stringWithFormat: @"resolved cid dropped: %@", result];
  testWithMessage ([result rangeOfString: @"http://x/1"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"unknown cid kept: %@", result];
  testWithMessage ([result rangeOfString: @"missing"].location == NSNotFound, error);
}

- (void) test_rawContentBypassesStyleSanitization
{
  SOGoHTMLSanitizer *handler;
  NSString *result, *error;

  handler = [self sanitizeHTML:
               @"<body><style>p { color: red; }</style><p>text</p></body>"
                        rawContent: YES];

  result = [handler result];

  testEquals ([handler css], @"");
  error = [NSString stringWithFormat: @"body content dropped: %@", result];
  testWithMessage ([result rangeOfString: @"text"].location != NSNotFound, error);
}

- (void) test_styleCommentsAndControlCharactersAreStripped
{
  SOGoHTMLSanitizer *handler;
  NSString *css, *error;

  handler = [self sanitizeHTML:
               @"<body><style>h { color: red; } <!--\n"
               @"keep1 /* SECRET1 */ keep2 -->\n"
               @"p { color: blue; }\n"
               @"</style><p>text</p></body>"
                        rawContent: NO];

  css = [handler css];

  error = [NSString stringWithFormat: @"css comment kept: %@", css];
  testWithMessage ([css rangeOfString: @"SECRET1"].location == NSNotFound, error);
  error = [NSString stringWithFormat: @"html comment markers kept: %@", css];
  testWithMessage ([css rangeOfString: @"<!--"].location == NSNotFound, error);
  error = [NSString stringWithFormat: @"selectors lost: %@", css];
  testWithMessage ([css rangeOfString: @"keep1"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"rules not suffixed: %@", css];
  testWithMessage ([css rangeOfString: @"color: blue !important"].location != NSNotFound,
                   error);
}

- (void) test_styleAtRulesAndSelectorListsAreSanitized
{
  SOGoHTMLSanitizer *handler;
  NSString *css, *error;

  handler = [self sanitizeHTML:
               @"<body><style>p, h1 { color: red !important; } @import 'x.css'; "
               @"@media screen, print { div { margin: 0; } } } trailingzz"
               @"</style></body>"
                        rawContent: NO];

  css = [handler css];

  error = [NSString stringWithFormat: @"selector list not prefixed: %@", css];
  testWithMessage ([css rangeOfString: @".SOGoHTMLMail-CSS-Delimiter p,"].location
                     != NSNotFound, error);
  error = [NSString stringWithFormat: @"important rule mangled: %@", css];
  testWithMessage ([css rangeOfString: @"color: red !important;"].location != NSNotFound,
                   error);
  error = [NSString stringWithFormat: @"trailing css lost: %@", css];
  testWithMessage ([css rangeOfString: @"trailing"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"at-rule kept: %@", css];
  testWithMessage ([css rangeOfString: @"@import"].location == NSNotFound, error);
  testWithMessage ([css rangeOfString: @"@media"].location == NSNotFound, error);
  testWithMessage ([css rangeOfString: @"margin"].location == NSNotFound, error);
}

- (void) test_braceLessAtRuleDoesNotSwallowTheNextRule
{
  SOGoHTMLSanitizer *handler;
  NSString *css, *error;

  handler = [self sanitizeHTML:
               @"<body><style>@import url(\"x.css\"); "
               @"p.MsoNormal{ margin: 0cm; mso-pagination: widow-orphan; } "
               @"div.WordSection1{ page: WordSection1; }"
               @"</style><p>text</p></body>"
                        rawContent: NO];

  css = [handler css];

  error = [NSString stringWithFormat: @"at-rule statement kept: %@", css];
  testWithMessage ([css rangeOfString: @"@import"].location == NSNotFound, error);
  error = [NSString stringWithFormat: @"rule after brace-less at-rule swallowed: %@", css];
  testWithMessage ([css rangeOfString: @"p.MsoNormal {"].location != NSNotFound, error);
  testWithMessage ([css rangeOfString: @"margin: 0cm !important"].location != NSNotFound, error);
  testWithMessage ([css rangeOfString: @"mso-pagination: widow-orphan !important"].location
                     != NSNotFound, error);
  error = [NSString stringWithFormat: @"later rule lost: %@", css];
  testWithMessage ([css rangeOfString: @"div.WordSection1 {"].location != NSNotFound, error);
}

- (void) test_styleAttributesWithUrlAreNeutralized
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<div style=\"background:url('http://x.example/i.png'); width: 2px;\""
              @" title=\"ok\">c</div>"
              @"</body>"];

  error = [NSString stringWithFormat: @"style with url not neutralized: %@", result];
  testWithMessage ([result rangeOfString: @"unsafe-style"].location != NSNotFound, error);
  testWithMessage ([result rangeOfString: @" style=\"background"].location == NSNotFound,
                   error);
  error = [NSString stringWithFormat: @"regular attribute dropped: %@", result];
  testWithMessage ([result rangeOfString: @"title=\"ok\""].location != NSNotFound, error);
}

- (void) test_hrefSchemesAreValidated
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<a href=\"#top\">top</a>"
              @"<a href=\"mailto:x@y.example\">mail</a>"
              @"<a href=\"/relative\">rel</a>"
              @"<a href=\"javascript:x()\">js</a>"
              @"<a href=\"https://x.example/e\">web</a>"
              @"</body>"];

  error = [NSString stringWithFormat: @"fragment href dropped: %@", result];
  testWithMessage ([result rangeOfString: @"rel=\"noopener\" href=\"#top\""].location
                     != NSNotFound, error);
  error = [NSString stringWithFormat: @"mailto href dropped: %@", result];
  testWithMessage ([result rangeOfString:
                      @"rel=\"noopener\" href=\"mailto:x@y.example\""].location
                     != NSNotFound, error);
  error = [NSString stringWithFormat: @"absolute href dropped: %@", result];
  testWithMessage ([result rangeOfString:
                      @"rel=\"noopener\" href=\"https://x.example/e\""].location
                     != NSNotFound, error);
  error = [NSString stringWithFormat: @"schemeless href kept: %@", result];
  testWithMessage ([result rangeOfString: @"relative"].location == NSNotFound, error);
  error = [NSString stringWithFormat: @"javascript href kept: %@", result];
  testWithMessage ([result rangeOfString: @"javascript"].location == NSNotFound, error);
}

- (void) test_actionAttributesAreValidated
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<form action=\"https://x.example/f\">"
              @"<button formaction=\"https://x.example/b\" type=\"submit\">go</button>"
              @"</form></body>"];

  error = [NSString stringWithFormat: @"form action dropped: %@", result];
  testWithMessage ([result rangeOfString:
                      @"rel=\"noopener\" action=\"https://x.example/f\""].location
                     != NSNotFound, error);
  error = [NSString stringWithFormat: @"formaction dropped: %@", result];
  testWithMessage ([result rangeOfString:
                      @"rel=\"noopener\" formaction=\"https://x.example/b\""].location
                     != NSNotFound, error);
}

- (void) test_eventHandlerAttributesAreDropped
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<p rel=\"x\" onclick=\"evil()\" onmouseover=\"evil2()\" title=\"ok\">t</p>"
              @"</body>"];

  error = [NSString stringWithFormat: @"event handler kept: %@", result];
  testWithMessage ([result rangeOfString: @"onclick"].location == NSNotFound, error);
  testWithMessage ([result rangeOfString: @"onmouseover"].location == NSNotFound, error);
  testWithMessage ([result rangeOfString: @"evil"].location == NSNotFound, error);
  error = [NSString stringWithFormat: @"rel attribute kept: %@", result];
  testWithMessage ([result rangeOfString: @"rel=\"x\""].location == NSNotFound, error);
  error = [NSString stringWithFormat: @"regular attribute dropped: %@", result];
  testWithMessage ([result rangeOfString: @"title=\"ok\""].location != NSNotFound, error);
}

- (void) test_suspiciousElementAttributesAreRenamed
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<p background=\"https://x.example/bg.png\">c</p>"
              @"<object data=\"https://x.example/d.swf\" classid=\"clsid:evil\">o</object>"
              @"<input src=\"https://x.example/i.png\"/>"
              @"</body>"];

  error = [NSString stringWithFormat: @"background not renamed: %@", result];
  testWithMessage ([result rangeOfString: @"unsafe-background"].location != NSNotFound,
                   error);
  error = [NSString stringWithFormat: @"object data not renamed: %@", result];
  testWithMessage ([result rangeOfString: @"unsafe-data"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"classid not renamed: %@", result];
  testWithMessage ([result rangeOfString: @"unsafe-classid"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"non-image src kept: %@", result];
  testWithMessage ([result rangeOfString: @"i.png"].location == NSNotFound, error);
  testWithMessage ([result rangeOfString: @"<input/>"].location != NSNotFound, error);
}

- (void) test_emptyAnchorsWrapSubsequentBlocks
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body>"
              @"<a href=\"https://x.example/w\"></a> <div><div>i</div></div>"
              @"<a href=\"#t\"></a>tail"
              @"</body>"];

  error = [NSString stringWithFormat: @"anchor not reopened: %@", result];
  testWithMessage ([result rangeOfString: @"href=\"https://x.example/w\""].location
                     != NSNotFound, error);
  testWithMessage ([result rangeOfString: @"</div></div></a>"].location != NSNotFound,
                   error);
  error = [NSString stringWithFormat: @"text after anchor lost: %@", result];
  testWithMessage ([result rangeOfString: @"tail"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"cancelled anchor kept: %@", result];
  testWithMessage ([result rangeOfString: @"#t"].location == NSNotFound, error);
}

- (void) test_pendingAnchorIsDroppedBeforeReopenedAnchor
{
  NSString *result, *error;

  result = [self sanitize:
              @"<body><a href=\"#p\"></a><a href=\"https://x.example/q\">q</a></body>"];

  error = [NSString stringWithFormat: @"dropped anchor leaked: %@", result];
  testWithMessage ([result rangeOfString: @"#p"].location == NSNotFound, error);
  error = [NSString stringWithFormat: @"second anchor mangled: %@", result];
  testWithMessage ([result rangeOfString: @"<a rel=\"noopener\" href=\"https://x.example/q\""
                      @">q</a>"].location != NSNotFound, error);
}

- (void) test_xmlLexicalEventsFeedTheStyleSanitizer
{
  SOGoHTMLSanitizer *handler;
  id <NSObject, SaxXMLReader> parser;
  NSData *data;
  NSString *css, *result, *error;

  data = [@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
          @"<?so-go instruction ?>"
          @"<html><body><style><!-- p { color: teal; } --></style>"
          @"<p>text<![CDATA[block]]></p></body></html>"
    dataUsingEncoding: NSUTF8StringEncoding];

  handler = [[SOGoHTMLSanitizer new] autorelease];
  [handler setContentEncoding: XML_CHAR_ENCODING_UTF8];

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/xml"];
  [parser setContentHandler: handler];
  [parser setProperty: @"http://xml.org/sax/properties/lexical-handler"
                   to: handler];
  [parser parseFromSource: data];

  css = [handler css];
  result = [[[handler result] copy] autorelease];

  error = [NSString stringWithFormat: @"style comment not collected: %@", css];
  testWithMessage ([css rangeOfString: @"teal"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"cdata content dropped: %@", result];
  testWithMessage ([result rangeOfString: @"block"].location != NSNotFound, error);
  error = [NSString stringWithFormat: @"regular text dropped: %@", result];
  testWithMessage ([result rangeOfString: @"text"].location != NSNotFound, error);
}

- (void) test_unusedSaxCallbacksAreHarmless
{
  SOGoHTMLSanitizer *handler;
  unichar chars[] = { ' ' };

  handler = [[SOGoHTMLSanitizer new] autorelease];
  [handler startDocument];
  [handler startDTD: @"html" publicId: @"-//W3C//DTD" systemId: @"html.dtd"];
  [handler endDTD];
  [handler startEntity: @"ent"];
  [handler endEntity: @"ent"];
  [handler ignorableWhitespace: chars length: 1];
  [handler skippedEntity: @"ent"];
  [handler endDocument];

  testEquals ([handler result], @"");
}

@end
