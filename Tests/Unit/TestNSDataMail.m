#import <Foundation/Foundation.h>

#import "Mailer/NSData+Mail.h"

#import "SOGoTest.h"

@interface TestNSDataMail : SOGoTest
@end

@implementation TestNSDataMail

- (void) test_bodyDataFromEncoding
{
  NSData *data;
  NSData *result;

  data = [@"aGVsbG8=" dataUsingEncoding: NSASCIIStringEncoding];
  result = [data bodyDataFromEncoding: @"base64"];
  testEquals([[[NSString alloc] initWithData: result encoding: NSASCIIStringEncoding] autorelease], @"hello");
  result = [data bodyDataFromEncoding: @"7bit"];
  testEquals([[[NSString alloc] initWithData: result encoding: NSASCIIStringEncoding] autorelease], @"aGVsbG8=");
  result = [data bodyDataFromEncoding: @"8Bit"];
  testEquals([[[NSString alloc] initWithData: result encoding: NSASCIIStringEncoding] autorelease], @"aGVsbG8=");
  result = [data bodyDataFromEncoding: @"BINARY"];
  testEquals([[[NSString alloc] initWithData: result encoding: NSASCIIStringEncoding] autorelease], @"aGVsbG8=");

  data = [@"caf=C3=A9" dataUsingEncoding: NSASCIIStringEncoding];
  result = [data bodyDataFromEncoding: @"quoted-printable"];
  testEquals([[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease], @"café");
  testEquals([data bodyDataFromEncoding: @"unknown-encoding"], nil);
  testEquals([data bodyDataFromEncoding: @""], data);
  testEquals([data bodyDataFromEncoding: nil], data);
}

- (void) test_bodyStringFromCharset
{
  NSData *data;

  data = [@"café" dataUsingEncoding: NSUTF8StringEncoding];
  testEquals([data bodyStringFromCharset: @"utf-8"], @"café");
  testEquals([data bodyStringFromCharset: @"UTF-8"], @"café");
  testEquals([data bodyStringFromCharset: nil], @"café");
  testEquals([data bodyStringFromCharset: @"inexistent_encoding"], @"café");
  testEquals([[NSData data] bodyStringFromCharset: @"utf-8"], @"");

  data = [NSData dataWithBytes: "\xff\xfe\xfd\xfc\xfb\xfa\xf9" length: 7];
  testEquals([data bodyStringFromCharset: @"utf-8"],
             [[[NSString alloc] initWithData: data encoding: NSISOLatin1StringEncoding] autorelease]);
}

- (void) test_decodedHeader
{
  NSData *data;

  data = [NSData data];
  testEquals([data decodedHeader], @"");

  data = [@"=?utf-8?q?" dataUsingEncoding: NSASCIIStringEncoding];
  testEquals([data decodedHeader], @"=?utf-8?q?");

  data = [NSData dataWithBytes: "\xff\xfe\xfd\xfc\xfb\xfa\xf9\xf8" length: 8];
  testEquals([data decodedHeader],
             [[[NSString alloc] initWithData: data encoding: NSISOLatin1StringEncoding] autorelease]);

  data = [@"Re: =?utf-8?q?caf=C3=A9?=" dataUsingEncoding: NSASCIIStringEncoding];
  testEquals([data decodedHeader], @"Re: café");

  data = [@"=?utf-8?B?6aG555uu5Lu75YqhIOS4tOacn+aPkOmGkijkuIDmsb3lpKfk?=\r\n\t=?utf-8?B?vJfCt0IxMMK3MuWNh+mZjeezu+e7nyk=?=" dataUsingEncoding: NSASCIIStringEncoding];
  testEquals([data decodedHeader], @"项目任务 临期提醒(一汽大众·B10·2升降系统)");

  data = [@"=?utf-8?B?Y2Fm?= =?utf-8?q?=C3=A9?=" dataUsingEncoding: NSASCIIStringEncoding];
  testEquals([data decodedHeader], @"café");
}

- (void) test_sanitizedContentUsingVoidTags_charsetSubstitution
{
  NSData *data;
  NSString *result;

  data = [@"<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=Windows-1252\"></head><body>x</body></html>" dataUsingEncoding: NSUTF8StringEncoding];
  result = [[[NSString alloc] initWithData: [data sanitizedContentUsingVoidTags: nil] encoding: NSUTF8StringEncoding] autorelease];
  testEquals(result, @"<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; \"></head><body>x</body></html>");

  data = [@"<META HTTP-EQUIV=\"x\" CONTENT=\"y; CHARSET=iso-8859-1\">ab" dataUsingEncoding: NSUTF8StringEncoding];
  result = [[[NSString alloc] initWithData: [data sanitizedContentUsingVoidTags: nil] encoding: NSUTF8StringEncoding] autorelease];
  testEquals(result, @"<META HTTP-EQUIV=\"x\" CONTENT=\"y; \">ab");

  data = [@"<meta content='text/html; charset=utf-8'>x" dataUsingEncoding: NSUTF8StringEncoding];
  result = [[[NSString alloc] initWithData: [data sanitizedContentUsingVoidTags: nil] encoding: NSUTF8StringEncoding] autorelease];
  testEquals(result, @"<meta content='text/html; '>x");

  data = [@"<meta content=\"text/html; charset=" dataUsingEncoding: NSUTF8StringEncoding];
  result = [[[NSString alloc] initWithData: [data sanitizedContentUsingVoidTags: nil] encoding: NSUTF8StringEncoding] autorelease];
  testEquals(result, @"<meta content=\"text/html; charset=");

  data = [@"<meta charset=x>y" dataUsingEncoding: NSUTF8StringEncoding];
  result = [[[NSString alloc] initWithData: [data sanitizedContentUsingVoidTags: nil] encoding: NSUTF8StringEncoding] autorelease];
  testEquals(result, @"<meta charset=x>y");
}

- (void) test_sanitizedContentUsingVoidTags_endTags
{
  NSData *data;
  NSString *result;

  data = [@"<br/>a</br>b</img>c</p><p>d</html>tail" dataUsingEncoding: NSUTF8StringEncoding];
  result = [[[NSString alloc] initWithData: [data sanitizedContentUsingVoidTags: nil] encoding: NSUTF8StringEncoding] autorelease];
  testEquals(result, @"<br/>a<br>b<img>c</p><p>dtail</html>");

  data = [@"<br/>a</br>b</html>" dataUsingEncoding: NSUTF8StringEncoding];
  result = [[[NSString alloc] initWithData: [data sanitizedContentUsingVoidTags: [NSArray arrayWithObject: @"br"]] encoding: NSUTF8StringEncoding] autorelease];
  testEquals(result, @"<br/>a<br>b</html>");

  data = [@"<html><body>a</HTML>b</html>" dataUsingEncoding: NSUTF8StringEncoding];
  result = [[[NSString alloc] initWithData: [data sanitizedContentUsingVoidTags: nil] encoding: NSUTF8StringEncoding] autorelease];
  testEquals(result, @"<html><body>ab</html></html>");

  data = [@"</p>" dataUsingEncoding: NSUTF8StringEncoding];
  result = [[[NSString alloc] initWithData: [data sanitizedContentUsingVoidTags: nil] encoding: NSUTF8StringEncoding] autorelease];
  testEquals(result, @"</p>");

  data = [@"a</b" dataUsingEncoding: NSUTF8StringEncoding];
  result = [[[NSString alloc] initWithData: [data sanitizedContentUsingVoidTags: nil] encoding: NSUTF8StringEncoding] autorelease];
  testEquals(result, @"a</b");

  data = [@"a</bx" dataUsingEncoding: NSUTF8StringEncoding];
  result = [[[NSString alloc] initWithData: [data sanitizedContentUsingVoidTags: nil] encoding: NSUTF8StringEncoding] autorelease];
  testEquals(result, @"a</bx");

  data = [@"x</" dataUsingEncoding: NSUTF8StringEncoding];
  result = [[[NSString alloc] initWithData: [data sanitizedContentUsingVoidTags: nil] encoding: NSUTF8StringEncoding] autorelease];
  testEquals(result, @"x</");

  data = [@"<br /></br ><hr/></hr>" dataUsingEncoding: NSUTF8StringEncoding];
  result = [[[NSString alloc] initWithData: [data sanitizedContentUsingVoidTags: nil] encoding: NSUTF8StringEncoding] autorelease];
  testEquals(result, @"<br /></br ><hr/><hr>");
}

@end
