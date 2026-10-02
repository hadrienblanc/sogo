#import <Foundation/Foundation.h>

#import "Mailer/NSString+Mail.h"

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
  testEquals([@"=?utf-8?q?a?= =?utf-8?q?b?=" decodedHeader], @"a b");
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

@end
