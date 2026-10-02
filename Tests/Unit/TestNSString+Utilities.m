/* TestNSString+Utilities.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
 * Copyright (C) 2014 Zentyal
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Jesús García Sáez <jgarcia@zentyal.com>
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

/* This file is encoded in utf-8. */

#import <SOGo/NSString+Utilities.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSException.h>
#import "SOGoTest.h"

@interface TestNSString_plus_Utilities : SOGoTest
@end

@implementation TestNSString_plus_Utilities

- (void) test_countOccurrencesOfString
{
  NSUInteger count;

  count = [@"abcdefa" countOccurrencesOfString: @"a"];
  failIf(count != 2);
  count = [@"abcdefa" countOccurrencesOfString: @"b"];
  failIf(count != 1);
  count = [@"" countOccurrencesOfString: @""];
  failIf(count != 0);
  count = [@"" countOccurrencesOfString: @"b"];
  failIf(count != 0);
  count = [@"roge" countOccurrencesOfString: @"roger"];
  failIf(count != 0);
}

- (void) test_encryptdecrypt
{
  NSString *secret = @"this is a secret";
  NSString *password = @"qwerty";
  NSString *encresult, *decresult;

  encresult = [secret encryptWithKey: nil];
  failIf(encresult != nil);
  encresult = [secret encryptWithKey: @""];
  failIf(encresult != nil);

  encresult = [secret encryptWithKey: password];
  failIf(encresult == nil);

  decresult = [encresult decryptWithKey: nil];
  failIf(decresult != nil);
  decresult = [encresult decryptWithKey: @""];
  failIf(decresult != nil);

  decresult = [encresult decryptWithKey: password];
  failIf(![decresult isEqualToString: secret]);
}

- (void) test_objectFromJSONString_single_values
{
  NSString *json, *error;
  NSInteger expected = 1;
  id result;

  // Decode null
  json = [NSString stringWithFormat:@"null"];
  result = [json objectFromJSONString];
  testWithMessage(result == [NSNull null], @"Result should be null");

  // Decode number
  json = [NSString stringWithFormat:@"1"];
  result = [json objectFromJSONString];
  error = [NSString stringWithFormat: @"result %@ != expected %d",
                    result, expected];
  testWithMessage((long)result != (long)expected, error);

  // Decode string
  json = [NSString stringWithFormat:@"\"kill me\""];
  result = [json objectFromJSONString];
  testEquals(result, @"kill me");
}


- (void) test_stringWithoutHTMLInjection
{
  testEquals([[NSString stringWithString:@"<a href=\"\">foo</a>bar"] stringWithoutHTMLInjection: YES stripAngular: NO], @" foo bar");
  testEquals([[NSString stringWithString:@"fb <foo@bar.com>"] stringWithoutHTMLInjection: YES stripAngular: NO], @"fb <foo@bar.com>");
  testEquals([[NSString stringWithString:@"Test\n<script>alert(\"foobar\");"] stringWithoutHTMLInjection: NO stripAngular: NO], @"Test\n<scr***>alert(\"foobar\");");
  testEquals([[NSString stringWithString:@"<img vbscript:test"] stringWithoutHTMLInjection: NO stripAngular: NO], @"<img test");
  testEquals([[NSString stringWithString:@"<img javascript:test"] stringWithoutHTMLInjection: NO stripAngular: NO], @"<img test");
  testEquals([[NSString stringWithString:@"<img livescript:test"] stringWithoutHTMLInjection: NO stripAngular: NO], @"<img test");
  testEquals([[NSString stringWithString:@"foobar <form action=\"\">bar</form>"] stringWithoutHTMLInjection: NO stripAngular: NO], @"foobar <for* action=\"\">bar</for*>");
  testEquals([[NSString stringWithString:@"foobar <iframe src=\"\">bar</iframe>"] stringWithoutHTMLInjection: NO stripAngular: NO], @"foobar <ifr*** src=\"\">bar</iframe>");
  testEquals([[NSString stringWithString:@"foobar <img onload=foo bar"] stringWithoutHTMLInjection: NO stripAngular: NO], @"foobar <img data-blocked=foo bar");
  testEquals([[NSString stringWithString:@"foobar <img onmouseover=foo bar"] stringWithoutHTMLInjection: NO stripAngular: NO], @"foobar <img data-blocked=foo bar");
  // any on...= handler is neutralised, including whitespace before '=' and names
  // that were never in the old list
  testEquals([[NSString stringWithString:@"<img src=x onerror =alert(1)>"] stringWithoutHTMLInjection: NO stripAngular: NO], @"<img src=x data-blocked=alert(1)>");
  testEquals([[NSString stringWithString:@"<input autofocus onfocus=alert(1)>"] stringWithoutHTMLInjection: NO stripAngular: NO], @"<input autofocus data-blocked=alert(1)>");
  // deletion filters loop until stable, so nesting cannot rebuild the scheme
  testEquals([[NSString stringWithString:@"javajavascript:script:"] stringWithoutHTMLInjection: NO stripAngular: NO], @"");
  testEquals([[NSString stringWithString:@"<!DOCTYPE html><html><head><style>@import url(https://foo.bar/malicious.css);.foo{background-color: red; @import url(https://bar.foo/malicious2.css);</style></head><body><table><tr><td>A</td><td>B</td><td>C</td></tr></table></body></html>"] stringWithoutHTMLInjection: NO stripAngular: NO], @"<!DOCTYPE html><html><head><style>@im**** url(https://foo.bar/malicious.css);.foo{background-color: red; @im**** url(https://bar.foo/malicious2.css);</style></head><body><table><tr><td>A</td><td>B</td><td>C</td></tr></table></body></html>");
  // the @import cleanup must still run when angular interpolation is stripped as well
  testEquals([[NSString stringWithString:@"<style>@import url(https://foo.bar/malicious.css);</style>"] stringWithoutHTMLInjection: NO stripAngular: YES], @"<style>@im**** url(https://foo.bar/malicious.css);</style>");
  // literal braces are rewritten so AngularJS cannot interpolate them
  testEquals([[NSString stringWithString:@"{{1337*1337}}"] stringWithoutHTMLInjection: NO stripAngular: YES], @"{\\{1337*1337}/}");
  // ... and so are the decimal HTML entities the browser would decode back to braces
  testEquals([[NSString stringWithString:@"&#123;&#123;1337*1337&#125;&#125;"] stringWithoutHTMLInjection: NO stripAngular: YES], @"{\\{1337*1337}/}");
}

- (void) test_stringWithoutHTMLInjectionKeepingSubjectMarkup
{
  testEquals([[NSString stringWithString:@"[Wikitech-l] Re: VisualEditor inserting <br />"] stringWithoutHTMLInjection: NO stripAngular: NO], @"[Wikitech-l] Re: VisualEditor inserting <br />");
  testEquals([[NSString stringWithString:@"Re: <b>bold</b> and <i>italic</i>"] stringWithoutHTMLInjection: NO stripAngular: NO], @"Re: <b>bold</b> and <i>italic</i>");
  testEquals([[NSString stringWithString:@"5 < 6 > 4"] stringWithoutHTMLInjection: NO stripAngular: NO], @"5 < 6 > 4");
  testEquals([[NSString stringWithString:@"<img src=x onerror =alert(1)> <b>bold</b>"] stringWithoutHTMLInjection: NO stripAngular: NO], @"<img src=x data-blocked=alert(1)> <b>bold</b>");
  testEquals([[NSString stringWithString:@"Re: <br /> and {{1337*1337}}"] stringWithoutHTMLInjection: NO stripAngular: YES], @"Re: <br /> and {\\{1337*1337}/}");
}

- (void) test_stringCleanInvalidHTMLTags
{
  testEquals([[NSString stringWithString:@"<div>Test<!--></div>"] cleanInvalidHTMLTags], @"<div>Test</div>");
  testEquals([[NSString stringWithString:@"<div><!--[if !mso]><span>Test</span><!--<![endif]--></div>"] cleanInvalidHTMLTags], @"<div><!--[if !mso]><span>Test</span><!--[endif]--></div>");
}

- (void) test_stringRemoveHTMLTagsExceptAnchorTags
{
   testEquals([[NSString stringWithString:@"<div>Test<img src=\"foo\" />bar <a href=\"https://www.sogo.nu\" target=\"_blank\">link</a> <strong>foobar</strong></div>"] removeHTMLTagsExceptAnchorTags], @"Testbar <a href=\"https://www.sogo.nu\" target=\"_blank\">link</a> foobar");
}

- (void) test_stringByDetectingURLs
{
  testEquals([@"see http://example.com/x now" stringByDetectingURLs],
             @"see <a rel=\"noopener\" href=\"http://example.com/x\">http://example.com/x</a> now");
  testEquals([@"see http://example.com/x." stringByDetectingURLs],
             @"see <a rel=\"noopener\" href=\"http://example.com/x\">http://example.com/x</a>.");
  testEquals([@"(http://example.com/x)" stringByDetectingURLs],
             @"(<a rel=\"noopener\" href=\"http://example.com/x\">http://example.com/x</a>)");
  testEquals([@"&lt;https://example.com/x&gt;" stringByDetectingURLs],
             @"&lt;<a rel=\"noopener\" href=\"https://example.com/x\">https://example.com/x</a>&gt;");
  testEquals([@"See &lt;http://a.de&gt; end" stringByDetectingURLs],
             @"See &lt;<a rel=\"noopener\" href=\"http://a.de\">http://a.de</a>&gt; end");
  testEquals([@"http://a.b/x;y?z=1&2" stringByDetectingURLs],
             @"<a rel=\"noopener\" href=\"http://a.b/x;y?z=1&2\">http://a.b/x;y?z=1&2</a>");
  testEquals([@"http://a.b/x (http://c.d/y)" stringByDetectingURLs],
             @"<a rel=\"noopener\" href=\"http://a.b/x\">http://a.b/x</a> (<a rel=\"noopener\" href=\"http://c.d/y\">http://c.d/y</a>)");
  testEquals([@"no urls here" stringByDetectingURLs], @"no urls here");
}

- (void) test_stringByDetectingURLs_emailAddresses
{
  testEquals([@"mail a@b.co now" stringByDetectingURLs],
             @"mail <a rel=\"noopener\" href=\"mailto:a@b.co\">a@b.co</a> now");
  testEquals([@"(a@b.co)" stringByDetectingURLs],
             @"(<a rel=\"noopener\" href=\"mailto:a@b.co\">a@b.co</a>)");
  testEquals([@"john.doe+tag@example.co.uk," stringByDetectingURLs],
             @"<a rel=\"noopener\" href=\"mailto:john.doe+tag@example.co.uk\">john.doe+tag@example.co.uk</a>,");
  testEquals([@"mailto:a@b.co" stringByDetectingURLs],
             @"mailto:<a rel=\"noopener\" href=\"mailto:a@b.co\">a@b.co</a>");
  testEquals([@"http://user@host/x" stringByDetectingURLs],
             @"<a rel=\"noopener\" href=\"http://user@host/x\">http://user@host/x</a>");
  testEquals([@" @example.com" stringByDetectingURLs], @" @example.com");
  testEquals([@"to:@example.com" stringByDetectingURLs], @"to:@example.com");
  testEquals([@"1://x" stringByDetectingURLs],
             @"1<a rel=\"noopener\" href=\"://x\">://x</a>");
}

- (void) test_asSafeJSString
{
  testEquals([@"plain" asSafeJSString], @"plain");
  testEquals([@"café" asSafeJSString], @"café");
  testEquals([@"a\"b\\c" asSafeJSString], @"a\\\"b\\\\c");
  testEquals([@"\t\n\r" asSafeJSString], @"\\t\\n\\r");
  testEquals([@"\b\f" asSafeJSString], @"\\b\\f");
  testEquals([@"a\033b" asSafeJSString], @"a\\u001bb");
  testEquals([@"a\"b" doubleQuotedString], @"\"a\\\"b\"");
}

- (void) test_safeString
{
  testEquals([@"a\033b" safeString], @"ab");
  testEquals([@"a\u0301b" safeString], @"ab");
  testEquals([@"\u2603" safeString], @"\u2603");
  testEquals([@"😀x" safeString], @"😀x");
  testEquals([@"" safeString], @"");
}

- (void) test_safeStringByEscapingXMLString
{
  testEquals([@"" safeStringByEscapingXMLString], @"");
  testEquals([@"plain" safeStringByEscapingXMLString], @"plain");
  testEquals([@"a&b\"c<d>e" safeStringByEscapingXMLString], @"a&amp;b&quot;c&lt;d&gt;e");
  testEquals([@"a\rb" safeStringByEscapingXMLString], @"a\rb");
  testEquals([@"a\rb" safeStringByEscapingXMLString: YES], @"a&#13;b");
  testEquals([@"😀" safeStringByEscapingXMLString], @"&#128512;");
  testEquals([@"a\033b" safeStringByEscapingXMLString], @"ab");
}

- (void) test_jsonRepresentation
{
  testEquals([@"a\"b\033c" jsonRepresentation], @"\"a\\\"bc\"");
}

- (void) test_isJSONString
{
  failIf(![@"{\"a\":1}" isJSONString]);
  failIf([@"{invalid" isJSONString]);
  failIf(![@"null" isJSONString]);
}

- (void) test_objectFromJSONString_brokenInput
{
  testEquals([@"[1," objectFromJSONString], nil);
  testEquals([@"{invalid" objectFromJSONString], nil);
  testEquals([@"\"a\\\\\"b\"" objectFromJSONString], @"a\"b");
}

- (void) test_asSafeSQLString
{
  testEquals([@"it's a \\ test" asSafeSQLString], @"it\\'s a \\\\ test");
  testEquals([@"a%b" asSafeSQLLikeString], @"a\\%b");
  testEquals([@"plain" asSafeSQLLikeString], @"plain");
}

- (void) test_stringByReplacingPrefix
{
  testEquals([@"oldX" stringByReplacingPrefix: @"old" withPrefix: @"new"], @"newX");
  testEquals([@"a" stringByReplacingPrefix: @"a" withPrefix: @"b"], @"b");
  NS_DURING
    {
      [@"abc" stringByReplacingPrefix: @"z" withPrefix: @"y"];
    }
  NS_HANDLER
    {
    }
  NS_ENDHANDLER;
}

- (void) test_asCSSIdentifier
{
  testEquals([@"a_b.c#d@e*f:g;h,i j'k\"l(m)n[o]p{q}r&s+t$u" asCSSIdentifier],
             @"a_U_b_D_c_H_d_A_e_S_f_C_g_SC_h_CO_i_SP_j_SQ_k_DQ_l_LP_m_RP_n_LS_o_RS_p_LC_q_RC_r_AM_s_P_t_DS_u");
  testEquals([@"1abc" asCSSIdentifier], @"_1abc");
  testEquals([@"7" asCSSIdentifier], @"_7");
  testEquals([@"" asCSSIdentifier], @"");
  testEquals([@"plain" asCSSIdentifier], @"plain");
  testEquals([@"😀_SP_x" asCSSIdentifier], @"😀_U_SP_U_x");
  testEquals([@"x😀y" asCSSIdentifier], @"x😀y");
}

- (void) test_fromCSSIdentifier
{
  testEquals([@"_U_" fromCSSIdentifier], @"_");
  testEquals([@"_SC_" fromCSSIdentifier], @";");
  testEquals([@"_1a" fromCSSIdentifier], @"1a");
  testEquals([@"_U" fromCSSIdentifier], @"_U");
  testEquals([@"a_U_b" fromCSSIdentifier], @"a_b");
  testEquals([@"a_SC_b" fromCSSIdentifier], @"a;b");
  testEquals([@"a__b" fromCSSIdentifier], @"a__b");
  testEquals([@"a_b" fromCSSIdentifier], @"a_b");
  testEquals([@"_U__SC_" fromCSSIdentifier], @"_;");
  testEquals([@"_U__U_" fromCSSIdentifier], @"__");
  testEquals([@"_SC__SC_" fromCSSIdentifier], @";;");
  testEquals([@"_D__SP__SQ__DQ__LP__RP__LS__RS__LC__RC__AM__P__DS_" fromCSSIdentifier],
             @". '\"()[]{}&+$");
  testEquals([@"_H__A__S__C__CO_" fromCSSIdentifier], @"#@*:,");
  testEquals([@"x_U_y" fromCSSIdentifier], @"x_y");
  testEquals([@"héé" fromCSSIdentifier], @"héé");
  testEquals([@".foo" fromCSSIdentifier], @".foo");
  testEquals([@".x" fromCSSIdentifier], @".x");
  testEquals([@"😀_SP_x" fromCSSIdentifier], @"😀 x");
}

- (void) test_mailDomain
{
  testEquals([@"user@example.org" mailDomain], @"example.org");
  testEquals([@"example.com" mailDomain], nil);
  testEquals([@"a@b@c" mailDomain], nil);
}

- (void) test_pureEMailAddress
{
  testEquals([@"a@b.c" pureEMailAddress], @"a@b.c");
  testEquals([@"Name <a@b.c>" pureEMailAddress], @"a@b.c");
  testEquals([@"Name <a@b.c" pureEMailAddress], @"a@b.c");
  testEquals([@"<a@b.c> <d@e.f>" pureEMailAddress], @"a@b.c");
}

- (void) test_asQPSubjectString
{
  testEquals([@"hello" asQPSubjectString: @"utf-8"], @"hello");
  testEquals([@"café" asQPSubjectString: @"utf-8"], @"=?utf-8?q?caf=C3=A9?=");
}

- (void) test_caseInsensitiveMatches
{
  failIf(![@"Hello" caseInsensitiveMatches: @"hel*"]);
  failIf([@"Hello" caseInsensitiveMatches: @"wor*"]);
}

- (void) test_componentsFromMultilineDN
{
  NSArray *expected;

  expected = [NSArray arrayWithObjects:
                         [NSArray arrayWithObjects: @"CN", @"Joe Doe", nil],
                         [NSArray arrayWithObjects: @"O", @"Inverse", nil],
                         nil];
  testEquals([@"CN=Joe Doe\nO=Inverse\n" componentsFromMultilineDN], expected);
  expected = [NSArray arrayWithObjects:
                         [NSArray arrayWithObjects: @"CN", @"Joe Doe", nil],
                         [NSArray arrayWithObjects: @"X", @"y", nil],
                         [NSArray arrayWithObjects: @"O", @"Inverse", nil],
                         nil];
  testEquals([@"CN=Joe Doe + X=y\nO=Inverse\n" componentsFromMultilineDN], expected);
  testEquals([@"not a dn" componentsFromMultilineDN], [NSArray array]);
}

- (void) test_timeValue
{
  testEquals([NSNumber numberWithInt: [@"Hello World" timeValue]], [NSNumber numberWithInt: 0]);
  testEquals([NSNumber numberWithInt: [@"42" timeValue]], [NSNumber numberWithInt: 42]);
  testEquals([NSNumber numberWithInt: [@"" timeValue]], [NSNumber numberWithInt: -1]);
  testEquals([NSNumber numberWithInt: [@"10:30" timeValue]], [NSNumber numberWithInt: 10]);
}

- (void) test_hostlessURL
{
  testEquals([@"/a/b/c" hostlessURL], @"/a/b/c");
  testEquals([@"http://host/path/x?q=1" hostlessURL], @"/path/x?q=1");
  testEquals([@"http://host" hostlessURL], @"");
}

- (void) test_urlWithoutParameters
{
  testEquals([@"http://a.b/c?a=b" urlWithoutParameters], @"http://a.b/c");
  testEquals([@"http://a.b/c" urlWithoutParameters], @"http://a.b/c");
  testEquals([@"http://a.b/c?a=b?c=d" urlWithoutParameters], @"http://a.b/c?a=b");
}

- (void) test_composeURLWithAction
{
  testEquals([@"http://a.b/c" composeURLWithAction: @"save"
                                        parameters: [NSDictionary dictionaryWithObject: @"1" forKey: @"x"]
                                           andHash: YES],
             @"http://a.b/c/save?x=1#");
  testEquals([@"http://a.b/c?z=9" composeURLWithAction: @"view" parameters: nil andHash: NO],
             @"http://a.b/c/view");
  testEquals([@"http://a.b/" composeURLWithAction: @"save" parameters: nil andHash: NO],
             @"http://a.b/save");
}

@end
