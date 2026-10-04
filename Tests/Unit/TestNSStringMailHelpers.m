#import <Foundation/Foundation.h>

#import <NGMime/NGMimeBodyPart.h>

#import "Mailer/NSString+Mail.h"
#import <SOGo/NSString+Utilities.h>

#import "SOGoTest.h"

@interface TestNSStringMailHelpers : SOGoTest
@end

@implementation TestNSStringMailHelpers

- (void) test_asSafeFilename
{
  testEquals([@"report.pdf" asSafeFilename], @"report.pdf");
  testEquals([@"my file.txt" asSafeFilename], @"my file.txt");
  testEquals([@"C:\\Users\\me\\file.txt" asSafeFilename], @"file.txt");
  testEquals([@"docs/report.pdf" asSafeFilename], @"docs_report.pdf");
  testEquals([@"a\\b/c.txt" asSafeFilename], @"b_c.txt");
  testEquals([@"../.." asSafeFilename], @".._..");
  testEquals([@"." asSafeFilename], @"_");
  testEquals([@".." asSafeFilename], @"__");
}

- (void) test_stringByConvertingCRLNToHTML
{
  testEquals([@"" stringByConvertingCRLNToHTML], @"");
  testEquals([@"no eol" stringByConvertingCRLNToHTML], @"no eol");
  testEquals([@"a\nb" stringByConvertingCRLNToHTML], @"a<br />b");
  testEquals([@"a\r\nb" stringByConvertingCRLNToHTML], @"a<br />b");
  testEquals([@"a\rb" stringByConvertingCRLNToHTML], @"ab");
  testEquals([@"\n" stringByConvertingCRLNToHTML], @"<br />");
}

- (void) test_plainTextMailPipelineKeepsVerificationURL
{
  NSString *body, *rendered, *expected;

  body = @"Visit the following URL (make sure it is entered as the single line):\n\nhttps://bugs.sogo.nu/verify.php?id=4129&confirm_hash=9aae6f14c8f52ee6d4c4f5a4e0d1b2c3\n\nIf you did not request any registration, ignore this message.";
  rendered = [[[[body stringByEscapingHTMLString] stringByDetectingURLs]
                stringByConvertingCRLNToHTML]
               stringWithoutHTMLInjection: NO stripAngular: NO];
  expected = @"Visit the following URL (make sure it is entered as the single line):<br /><br /><a rel=\"noopener\" href=\"https://bugs.sogo.nu/verify.php?id=4129&amp;confirm_hash=9aae6f14c8f52ee6d4c4f5a4e0d1b2c3\">https://bugs.sogo.nu/verify.php?id=4129&amp;confirm_hash=9aae6f14c8f52ee6d4c4f5a4e0d1b2c3</a><br /><br />If you did not request any registration, ignore this message.";
  testEquals(rendered, expected);

  body = @"See https://example.com/view?onload=1&onerror=2 for details";
  rendered = [[[[body stringByEscapingHTMLString] stringByDetectingURLs]
               stringByConvertingCRLNToHTML]
              stringWithoutHTMLInjection: NO stripAngular: NO];
  expected = @"See <a rel=\"noopener\" href=\"https://example.com/view?onload=1&amp;onerror=2\">https://example.com/view?onload=1&amp;onerror=2</a> for details";
  testEquals(rendered, expected);
}

- (void) test_indexOf
{
  testEquals([NSNumber numberWithInt: [@"a/b/c" indexOf: '/']],
             [NSNumber numberWithInt: 1]);
  testEquals([NSNumber numberWithInt: [@"a/b/c" indexOf: 'z']],
             [NSNumber numberWithInt: -1]);
  testEquals([NSNumber numberWithInt: [@"" indexOf: 'x']],
             [NSNumber numberWithInt: -1]);
}

- (void) test_indexOfFromIndex
{
  testEquals([NSNumber numberWithInt: [@"a/b/c" indexOf: '/' fromIndex: 2]],
             [NSNumber numberWithInt: 3]);
  testEquals([NSNumber numberWithInt: [@"hello" indexOf: 'l' fromIndex: 3]],
             [NSNumber numberWithInt: 3]);
  testEquals([NSNumber numberWithInt: [@"a/b/c" indexOf: '/' fromIndex: 99]],
             [NSNumber numberWithInt: 1]);
  testEquals([NSNumber numberWithInt: [@"a/b/c" indexOf: '/' fromIndex: -5]],
             [NSNumber numberWithInt: 1]);
}

- (void) test_decodedHeader
{
  testEquals([@"plain subject" decodedHeader], @"plain subject");
  testEquals([@"=?utf-8?q?caf=C3=A9?=" decodedHeader], @"café");
  testEquals([@"=?utf-8?B?Y2Fmw6k=?=" decodedHeader], @"café");
  testEquals([@"=?iso-8859-1?q?caf=E9?=" decodedHeader], @"café");
  testEquals([@"Re: =?utf-8?q?caf=C3=A9?=" decodedHeader], @"Re: café");
  testEquals([@"=?utf-8?q?caf=C3=A9?= tail" decodedHeader], @"café tail");
  testEquals([@"=?utf-8?q?a?= =?utf-8?q?b?=" decodedHeader], @"ab");
  testEquals([@"=?utf-8?q?caf?= =?utf-8?q?=C3=A9?=" decodedHeader], @"café");
  testEquals([@"=?utf-8?B?Y2Fm?==?utf-8?q?=C3=A9?=" decodedHeader], @"café");
  testEquals([@"=?utf-8?q?caf=C3=A9?= =?iso-8859-1?q?caf=E9?=" decodedHeader], @"cafécafé");
  testEquals([@"=?utf-8?B?6aG555uu5Lu75YqhIOS4tOacn+aPkOmGkijkuIDmsb3lpKfk?= =?utf-8?B?vJfCt0IxMMK3MuWNh+mZjeezu+e7nyk=?=" decodedHeader],
             @"项目任务 临期提醒(一汽大众·B10·2升降系统)");
}

- (void) test_asPreferredFilenameUsingPath
{
  testEquals([@"image/png" asPreferredFilenameUsingPath: @"12"], @"unknown_12");
  testEquals([@"application/pdf" asPreferredFilenameUsingPath: @"3"], @"unknown_3");
  testEquals([@"audio/ogg" asPreferredFilenameUsingPath: @"4"], @"unknown_4");
  testEquals([@"video/mp4" asPreferredFilenameUsingPath: @"5"], @"unknown_5");
  testEquals([@"message/rfc822" asPreferredFilenameUsingPath: @"7"], @"email_7.eml");
  testEquals([@"text/plain" asPreferredFilenameUsingPath: @"7"], nil);
  testEquals([@"image/png" asPreferredFilenameUsingPath: nil], @"unknown_1");
}

- (void) test_htmlToText_plainContent
{
  testEquals([@"plain text only" htmlToText], @"plain text only");
  testEquals([@"<div>   </div>" htmlToText], @"   ");
  testEquals([@"<html><body>a&amp;b&lt;c</body></html>" htmlToText], @"a&b<c");
  testEquals([@"<html><body>go http://example.com now</body></html>" htmlToText],
             @"go http://example.com now");
}

- (void) test_htmlToText_specialTreatmentTags
{
  testEquals([@"<p>a</p>b<br />c<hr />d" htmlToText],
             @"\nab\nc______________________________________________________________________________\nd");
  testEquals([@"<ul><li>one</li><li>two</li>" htmlToText], @"\n * one * two");
  testEquals([@"<ul><li>a<ul><li>b</ul></li></ul>" htmlToText], @"\n * a\n * b");
  testEquals([@"<ol><li>one</li><li>two</li></ol>" htmlToText], @"\n 1. one 2. two");
  testEquals([@"<ol><li>a<ol><li>b</ol></li></ol>" htmlToText], @"\n 1. a\n 1. b");
  testEquals([@"<ol start=\"3\"><li>x</li><li>y</li></ol>" htmlToText], @"\n 1. x 2. y");
  testEquals([@"<dl><dt>term</dt><dd>def</dd></dl>" htmlToText], @"term  def");
  testEquals([@"<table><tr><td>c1</td><th>h</th></tr></table>" htmlToText], @"c1h");
  testEquals([@"<html><head><li>inhead</li></head><body>x</body></html>" htmlToText],
             @" * inheadx");
}

- (void) test_htmlToText_metaCharsetDeclaration
{
  testEquals([@"<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\"></head><body>Buchungsbestätigung</body></html>" htmlToText],
             @"Buchungsbestätigung");
  testEquals([@"<html><head><meta charset=\"windows-1252\"></head><body>Sehr geehrter Herr Skwar, vielen Dank für Ihre Buchung.</body></html>" htmlToText],
             @"Sehr geehrter Herr Skwar, vielen Dank für Ihre Buchung.");
  testEquals([@"<meta charset=\"utf-8\">Grüße aus München" htmlToText],
             @"Grüße aus München");
}

- (void) test_htmlToText_signatureDelimiter
{
  testEquals([@"<br /><br />--&nbsp;<br />Simon" htmlToText], @"\n\n-- \nSimon");
  testEquals([@"text<br /><br />--\u00A0<br />sig" htmlToText], @"text\n\n-- \nsig");
  testEquals([@"--&nbsp;<br />sig" htmlToText], @"-- \nsig");
  testEquals([@"a&nbsp;b" htmlToText], @"a\u00A0b");
  testEquals([@"well--known&nbsp;term<br />" htmlToText], @"well--known\u00A0term\n");
}

- (void) test_htmlToText_ignoredContent
{
  testEquals([@"<html><body>before<script>var x = 1;</script>middle<style>p{}</style>after</body></html>" htmlToText],
             @"beforemiddleafter");
  testEquals([@"<html><body>a<!-- some comment -->b</body></html>" htmlToText], @"ab");
  testEquals([@"<html><body>a<?php echo 1; ?>b</body></html>" htmlToText], @"ab");
  testEquals([@"<!DOCTYPE html><html><body><p>x</p></body></html>" htmlToText], @"\nx");
  testEquals([@"<html><body><![CDATA[some cdata]]></body></html>" htmlToText], @"");
}

- (void) test_htmlByExtractingImages_textOnly
{
  NSMutableArray *images;

  images = [NSMutableArray array];
  testEquals([@"<p>a &lt; b &amp; c</p><img src=\"https://x/y.png\" /><br />tail" htmlByExtractingImages: images],
             @"<html><body><p>a &lt; b &amp; c</p><img src=\"https://x/y.png\"/><br/>tail</body></html>");
  testEquals([NSNumber numberWithInt: [images count]], [NSNumber numberWithInt: 0]);

  images = [NSMutableArray array];
  testEquals([@"before<img src=\"dat\" />after" htmlByExtractingImages: images],
             @"<html><body>before<img src=\"dat\"/>after</body></html>");

  images = [NSMutableArray array];
  testEquals([@"x<br></br><img></img>y" htmlByExtractingImages: images],
             @"<html><body>x<br/><img/>y</body></html>");

  images = [NSMutableArray array];
  testEquals([@"<div title=\"he said \\\"hi\\\" \\\">x</div><span>after</span>" htmlByExtractingImages: images],
             @"<html><body><div title=\"he said \\\\\" hi\\\"=\"\" \\\"=\"\">x</div><span>after</span></body></html>");
}

- (void) test_htmlByExtractingImages_keepsInlineFontStyles
{
  NSMutableArray *images;

  images = [NSMutableArray array];
  testEquals([@"<p><span style=\"font-size:36px;\">BIG</span></p><p><span style=\"font-size:12px;\">small</span></p>" htmlByExtractingImages: images],
             @"<html><body><p><span style=\"font-size:36px;\">BIG</span></p><p><span style=\"font-size:12px;\">small</span></p></body></html>");
  testEquals([@"<p><span style=\"font-size:20px; font-family:Arial, sans-serif;\">mixed</span></p>" htmlByExtractingImages: images],
             @"<html><body><p><span style=\"font-size:20px; font-family:Arial, sans-serif;\">mixed</span></p></body></html>");
  testEquals([NSNumber numberWithInt: [images count]], [NSNumber numberWithInt: 0]);
}

- (void) test_htmlByExtractingImages_dataUris
{
  NSMutableArray *images;
  NGMimeBodyPart *part;
  NSString *result;

  images = [NSMutableArray array];
  result = [@"<img src=\"data:image/png;base64,iVBORw0KGgo=\" alt=\"pic\" />" htmlByExtractingImages: images];
  testEquals([NSNumber numberWithInt: [images count]], [NSNumber numberWithInt: 1]);
  testWithMessage([result hasPrefix: @"<html><body><img src=\"cid:"], result);
  testWithMessage([result rangeOfString: @"\" type=\"image/png\" alt=\"pic\"/>"].location != NSNotFound, result);
  part = [images objectAtIndex: 0];
  testWithMessage([[part headerForKey: @"content-type"] hasPrefix: @"image/png; name=\""],
                  [part headerForKey: @"content-type"]);
  testWithMessage([[part headerForKey: @"content-disposition"] hasPrefix: @"inline; filename=\""],
                  [part headerForKey: @"content-disposition"]);
  testEquals([part headerForKey: @"content-transfer-encoding"], @"base64");

  images = [NSMutableArray array];
  result = [@"<img src=\"DATA:image/png;BASE64,iVBORw0KGgo=\" />" htmlByExtractingImages: images];
  testEquals([NSNumber numberWithInt: [images count]], [NSNumber numberWithInt: 1]);
  testWithMessage([result rangeOfString: @"\" type=\"image/png\"/>"].location != NSNotFound, result);

  images = [NSMutableArray array];
  result = [@"<img src=\"data:image/gif;charset=UTF-8;base64,R0lGODlh\" />" htmlByExtractingImages: images];
  testEquals([NSNumber numberWithInt: [images count]], [NSNumber numberWithInt: 1]);
  testEquals([[images objectAtIndex: 0] headerForKey: @"content-transfer-encoding"], @"base64");
  testWithMessage([[[images objectAtIndex: 0] headerForKey: @"content-type"] hasPrefix: @"image/gif; name=\""],
                  [[images objectAtIndex: 0] headerForKey: @"content-type"]);

  images = [NSMutableArray array];
  result = [@"<img src=\"data:image/gif;quoted-printable,R0lGOD===\" />" htmlByExtractingImages: images];
  testEquals([NSNumber numberWithInt: [images count]], [NSNumber numberWithInt: 1]);
  testEquals([[images objectAtIndex: 0] headerForKey: @"content-transfer-encoding"], @"quoted-printable");

  images = [NSMutableArray array];
  result = [@"<img src=\"data:;base64,iVBORw0KGgo=\" />" htmlByExtractingImages: images];
  testEquals([NSNumber numberWithInt: [images count]], [NSNumber numberWithInt: 1]);
  testWithMessage([result rangeOfString: @"\" type=\"image/jpeg\"/>"].location != NSNotFound, result);
  testEquals([[images objectAtIndex: 0] headerForKey: @"content-transfer-encoding"], @"base64");
  testWithMessage([[[images objectAtIndex: 0] headerForKey: @"content-type"] hasPrefix: @"image/jpeg; name=\""],
                  [[images objectAtIndex: 0] headerForKey: @"content-type"]);

  images = [NSMutableArray array];
  result = [@"<img src=\"data:img/x,,DATA\" />" htmlByExtractingImages: images];
  testEquals([NSNumber numberWithInt: [images count]], [NSNumber numberWithInt: 1]);
  testEquals([[images objectAtIndex: 0] headerForKey: @"content-transfer-encoding"], @"mg/x");
  testWithMessage([images objectAtIndex: 0] != nil
                  && [[images objectAtIndex: 0] headerForKey: @"content-length"] == nil,
                  @"inline image parts must not carry a content-length header (bug 5926)");
  testWithMessage([result rangeOfString: @"\" type=\"image/jpeg\"/>"].location != NSNotFound, result);

  images = [NSMutableArray array];
  result = [@"<img src=\"data:img/j;,D\" />" htmlByExtractingImages: images];
  testEquals([NSNumber numberWithInt: [images count]], [NSNumber numberWithInt: 1]);
  testEquals([[images objectAtIndex: 0] headerForKey: @"content-transfer-encoding"], @"base64");
  testWithMessage([result rangeOfString: @"\" type=\"img/j\"/>"].location != NSNotFound, result);

  images = [NSMutableArray array];
  result = [@"<img src=\"data:image/png;base64,SHORT\" />" htmlByExtractingImages: images];
  testEquals([NSNumber numberWithInt: [images count]], [NSNumber numberWithInt: 1]);
  testWithMessage([result rangeOfString: @"\" type=\"image/png\"/>"].location != NSNotFound, result);
}

- (void) test_htmlByExtractingImages_foldedBase64
{
  NSMutableArray *images;

  images = [NSMutableArray array];
  [@"<img src=\"data:image/png;base64,AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ==\" />" htmlByExtractingImages: images];
  testEquals([NSNumber numberWithInt: [images count]], [NSNumber numberWithInt: 1]);
  testWithMessage([images objectAtIndex: 0] != nil
                  && [[images objectAtIndex: 0] headerForKey: @"content-length"] == nil,
                  @"folded inline image parts must not carry a content-length header (bug 5926)");
}

- (void) test_decodedHeader_brokenInput
{
  testEquals([@"café" decodedHeader], @"café");
  testEquals([[@"" dataUsingEncoding: NSASCIIStringEncoding] decodedHeader], @"");
  testEquals([@"=?utf-8?q?" decodedHeader], @"=?utf-8?q?");
}

- (void) test_stringByConvertingCRLNToHTML_longInput
{
  NSMutableString *input;
  int i;

  input = [NSMutableString string];
  for (i = 0; i < 2000; i++)
    [input appendString: @"ab\n"];
  testEquals([NSNumber numberWithInt: [[input stringByConvertingCRLNToHTML] length]],
             [NSNumber numberWithInt: (2000 * 8)]);
}

@end
