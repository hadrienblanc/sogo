/* TestWORequest+SOGo.m - this file is part of SOGo
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
 * along with this program; if not, see <http://www.gnu.org/licenses/>.
 */

/* This file is encoded in utf-8. */

#import <Foundation/Foundation.h>
#import <NGHttp/NGHttp.h>
#import <NGObjWeb/WORequest.h>

#import "SOGo/WORequest+SOGo.h"

#import "SOGoTest.h"

@interface WORequest (SOGoTests)
- (void) _setHttpRequest: (id) request;
@end

@interface TestWORequest_plus_SOGo : SOGoTest
@end

@implementation TestWORequest_plus_SOGo

- (WORequest *) _requestWithContentType: (NSString *) contentType
                                  body: (NSData *) body
{
  NSDictionary *headers;

  headers = nil;
  if (contentType)
    headers = [NSDictionary dictionaryWithObject: contentType
                                         forKey: @"content-type"];

  return [[[WORequest alloc] initWithMethod: @"PUT"
                                        uri: @"/SOGo/dav/test/test.vcf"
                                httpVersion: @"HTTP/1.1"
                                    headers: headers
                                    content: body
                                  userInfo: nil] autorelease];
}

- (NSData *) _vcardDataWithEncoding: (NSStringEncoding) encoding
{
  NSString *vcard;

  vcard = @"BEGIN:VCARD\r\nVERSION:3.0\r\nN:Tachtler;Kl\u00e4us\r\n"
          @"END:VCARD\r\n";

  return [vcard dataUsingEncoding: encoding];
}

- (void) test_davBodyEncodingForContentType
{
  test ([WORequest davBodyEncodingForContentType: nil]
        == NSUTF8StringEncoding);
  test ([WORequest davBodyEncodingForContentType: @"text/x-vcard"]
        == NSUTF8StringEncoding);
  test ([WORequest davBodyEncodingForContentType: @"text/vcard"]
        == NSUTF8StringEncoding);
  test ([WORequest davBodyEncodingForContentType: @"text/calendar"]
        == NSUTF8StringEncoding);
  test ([WORequest davBodyEncodingForContentType: @"text/calendar; charset=utf-8"]
        == NSUTF8StringEncoding);
  test ([WORequest davBodyEncodingForContentType: @"text/vcard; charset=ISO-8859-1"]
        == NSISOLatin1StringEncoding);
  test ([WORequest davBodyEncodingForContentType: @"text/vcard; charset=unknown-charset"]
        == NSUTF8StringEncoding);
}

- (void) test_davBodyAsString_utf8_without_charset
{
  WORequest *request;
  NSString *s;

  request = [self _requestWithContentType: @"text/x-vcard"
                                      body: [self _vcardDataWithEncoding:
                                                    NSUTF8StringEncoding]];
  s = [request davBodyAsString];
  test (s != nil);
  test ([s rangeOfString: @"N:Tachtler;Kl\u00e4us"].length > 0);
}

- (void) test_davBodyAsString_no_content_type
{
  WORequest *request;
  NSString *s;

  request = [self _requestWithContentType: nil
                                      body: [self _vcardDataWithEncoding:
                                                    NSUTF8StringEncoding]];
  s = [request davBodyAsString];
  test (s != nil);
  test ([s rangeOfString: @"N:Tachtler;Kl\u00e4us"].length > 0);
}

- (void) test_davBodyAsString_explicit_charset
{
  WORequest *request;
  NSString *s;

  request = [self _requestWithContentType: @"text/vcard; charset=iso-8859-1"
                                      body: [self _vcardDataWithEncoding:
                                                    NSISOLatin1StringEncoding]];
  s = [request davBodyAsString];
  test (s != nil);
  test ([s rangeOfString: @"N:Tachtler;Kl\u00e4us"].length > 0);
}

- (void) test_davBodyAsString_latin1_fallback
{
  WORequest *request;
  NSString *s;

  request = [self _requestWithContentType: @"text/x-vcard"
                                      body: [self _vcardDataWithEncoding:
                                                    NSISOLatin1StringEncoding]];
  s = [request davBodyAsString];
  test (s != nil);
  test ([s rangeOfString: @"N:Tachtler;Kl\u00e4us"].length > 0);
}

- (void) test_davBodyAsString_body_dropped_by_adaptor
{
  NGHttpRequest *httpRequest;
  WORequest *request;
  NSData *data;
  NSString *body;
  NSString *s;

  request = [self _requestWithContentType: nil body: nil];
  httpRequest = [[NGHttpRequest alloc] initWithMethod: @"PUT"
                                                   uri: @"/SOGo/dav/test/test.vcf"
                                                 header: nil
                                                version: @"HTTP/1.1"];
  data = [self _vcardDataWithEncoding: NSUTF8StringEncoding];
  body = [[[NSString alloc] initWithBytes: [data bytes]
                                   length: [data length]
                                 encoding: NSUTF8StringEncoding] autorelease];
  [httpRequest setBody: body];
  [request _setHttpRequest: httpRequest];
  [httpRequest release];

  s = [request davBodyAsString];
  test (s != nil);
  test ([s rangeOfString: @"N:Tachtler;Kl\u00e4us"].length > 0);
}

- (void) test_davBodyAsString_empty_request
{
  WORequest *request;

  request = [self _requestWithContentType: nil body: nil];
  test ([request davBodyAsString] == nil);
}

@end
