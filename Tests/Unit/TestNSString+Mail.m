/* TestNSString+Mail.m - this file is part of SOGo
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

#import <Foundation/NSString.h>

#import "SOGoTest.h"
#import <Mailer/NSString+Mail.h>
#import <NGMime/NGMimeBodyPart.h>

@interface TestNSString_plus_Mail : SOGoTest
@end

@implementation TestNSString_plus_Mail

- (void) setUp
{
  [SOGoTest loadSOGoBundle: @"Contacts" markerClass: @"SOGoDraftObject"];
  [SOGoTest loadSOGoBundle: @"Mailer" markerClass: @"SOGoDraftObject"];
}

- (NSString *) ticketHTML
{
  return @"<html><head>\n"
         @"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"></head>"
         @"<body><img width=\"1\" height=\"1\" src=\"https://t.example.com/tr/op/upMbUhF8\" style=\"mso-hide:all\">"
         @"<p>guckst Du hier</p></body></html>";
}

- (void) test_isFullHTMLDocumentWithHtmlTag
{
  test ([@"<html><head></head><body><p>x</p></body></html>" isFullHTMLDocument]);
}

- (void) test_isFullHTMLDocumentWithDoctype
{
  test ([@"<!DOCTYPE html>\n<html><body></body></html>" isFullHTMLDocument]);
}

- (void) test_isFullHTMLDocumentIsCaseInsensitive
{
  test ([@"<HTML><BODY><P>x</P></BODY></HTML>" isFullHTMLDocument]);
}

- (void) test_isFullHTMLDocumentWithFragment
{
  test (![@"<p>guckst Du hier</p>" isFullHTMLDocument]);
  test (![@"<div class=\"raw-html-embed\"><p>x</p></div>" isFullHTMLDocument]);
}

- (void) test_htmlToTextKeepsParagraphOfTicket6135
{
  testEquals ([[self ticketHTML] htmlToText], @"\nguckst Du hier");
}

- (void) test_htmlToTextWithConsecutiveParagraphs
{
  testEquals ([@"<p>a</p><p>b</p>" htmlToText], @"\na\nb");
}

- (void) test_htmlByExtractingImagesKeepsParagraphOfTicket6135
{
  NSMutableArray *images;
  NSString *result;

  images = [NSMutableArray array];
  result = [[self ticketHTML] htmlByExtractingImages: images];

  testWithMessage ([images count] == 0, @"no image should be extracted");
  test ([result rangeOfString: @"<p>guckst Du hier</p>"].length > 0);
  test ([result rangeOfString: @">p>"].length == 0);
  test ([result rangeOfString: @"mso-hide:all"].length > 0);
}

- (void) test_htmlByExtractingImagesExtractsDataURL
{
  NSMutableArray *images;
  NSString *result;

  images = [NSMutableArray array];
  result = [@"<p>a<img src=\"data:image/png;base64,iVBORw0KGgo=\">b</p>"
             htmlByExtractingImages: images];

  testWithMessage ([images count] == 1, @"the data URI image should be extracted");
  test ([result rangeOfString: @"src=\"cid:"].length > 0);
  test ([result rangeOfString: @"data:image/png"].length == 0);
  test ([result rangeOfString: @">b</p>"].length > 0);
}

- (void) test_htmlByExtractingImagesExtractsSVGDataURLOfTicket6152
{
  NSMutableArray *images;
  NSString *result;

  images = [NSMutableArray array];
  result = [@"<p>Test signature</p>"
            @"<p><img src=\"data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBzdGFuZGFsb25lPSJubyI/Pgo=\""
            @" width=\"391\" height=\"232\"></p>"
            htmlByExtractingImages: images];

  testWithMessage ([images count] == 1, @"the SVG data URI image should be extracted");
  testEquals ([[[images objectAtIndex: 0] contentType] stringValue], @"image/svg+xml");
  test ([result rangeOfString: @"src=\"cid:"].length > 0);
  test ([result rangeOfString: @"type=\"image/svg+xml\""].length > 0);
  test ([result rangeOfString: @"data:image/svg+xml"].length == 0);
  test ([result rangeOfString: @"width=\"391\" height=\"232\""].length > 0);
}

static NSString *
MessageIDShape(NSString *mailOrDomain)
{
  NSString *messageID = [NSString generateMessageID: mailOrDomain];

  return [@"<UUID" stringByAppendingString: [messageID substringFromIndex: 37]];
}



- (void) test_generateMessageID_fromAddressOrDomain
{
  testEquals(MessageIDShape(@"user@example.org"), @"<UUID@example.org>");
  testEquals(MessageIDShape(@"Example.ORG"), @"<UUID@example.org>");
}

- (void) test_generateMessageID_fromSenderWithDisplayName
{
  testEquals(MessageIDShape(@"Doe, John <user@example.org>"), @"<UUID@example.org>");
  testEquals(MessageIDShape(@"Doe, John <user@example.org> (work)"), @"<UUID@example.org>");
  testEquals(MessageIDShape(@"user@example.org>"), @"<UUID@example.org>");
}

- (void) test_generateMessageID_rejectsInjectedDomains
{
  testEquals(MessageIDShape(@"user@example.org\r\nBcc: victim"),
             @"<UUID@example.org>");
  testEquals(MessageIDShape(@"user@example.org Bcc: victim"),
             @"<UUID@example.org>");
}

- (void) test_generateMessageID_withoutDomain
{
  testEquals(MessageIDShape(@""), @"<UUID>");
  testEquals(MessageIDShape(nil), @"<UUID>");
}

@end
