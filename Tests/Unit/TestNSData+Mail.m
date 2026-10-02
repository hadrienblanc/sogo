/* TestNSData+Mail.m - this file is part of SOGo
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

#import <Foundation/NSData.h>
#import <Foundation/NSString.h>

#import "SOGoTest.h"

@interface TestNSData_plus_Mail : SOGoTest
@end

@implementation TestNSData_plus_Mail

- (void) setUp
{
  [SOGoTest loadSOGoBundle: @"Contacts" markerClass: @"SOGoDraftObject"];
  [SOGoTest loadSOGoBundle: @"Mailer" markerClass: @"SOGoDraftObject"];
  testWithMessage ([NSData instancesRespondToSelector: @selector (sanitizedContentUsingVoidTags:)],
                   @"NSData+Mail category unavailable (Mailer.SOGo bundle missing)");
}

- (NSString *) sanitized: (NSString *) html
{
  NSData *data, *sanitized;

  data = [html dataUsingEncoding: NSUTF8StringEncoding];
  sanitized = [data sanitizedContentUsingVoidTags: nil];

  return [[[NSString alloc] initWithData: sanitized
                                 encoding: NSUTF8StringEncoding] autorelease];
}

- (void) test_officeParagraphMarkIsStripped
{
  testEquals ([self sanitized: @"<p>a<o:p>&nbsp;</o:p>b</p>"],
              @"<p>a&nbsp;b</p>");
}

- (void) test_officeParagraphMarkCloseTagIsStripped
{
  testEquals ([self sanitized: @"<p>x</o:p>y</p>"],
              @"<p>xy</p>");
}

- (void) test_officeParagraphMarkCaseAndAttributes
{
  testEquals ([self sanitized: @"<O:P style='x'>t</O:P>"],
              @"t");
}

- (void) test_emptyOfficeParagraphMarksAreStripped
{
  testEquals ([self sanitized: @"<p class=MsoNormal><o:p></o:p></p>"],
              @"<p class=MsoNormal></p>");
}

- (void) test_otherPrefixedTagsAreLeftAlone
{
  NSString *html;

  html = @"<w:sdt>x</w:sdt><v:rect>y</v:rect><st1:place>z</st1:place>";

  testEquals ([self sanitized: html], html);
}

- (void) test_regularTagsAreLeftAlone
{
  NSString *html;

  html = @"<p>hello</p><pre>code</pre><o:other>o</o:other>";

  testEquals ([self sanitized: html], html);
}

- (void) test_truncatedOfficeParagraphMarkIsLeftAlone
{
  NSString *html;

  html = @"<o:p";

  testEquals ([self sanitized: html], html);
}

- (void) test_metaCharsetIsStripped
{
  testEquals ([self sanitized: @"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=Windows-1252\">"],
              @"<meta http-equiv=\"Content-Type\" content=\"text/html; \">");
}

- (void) test_slashedVoidEndTagIsRepaired
{
  testEquals ([self sanitized: @"<div>a</br>b</div>"],
              @"<div>a<br>b</div>");
}

@end
