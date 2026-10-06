#import <Foundation/NSString.h>

#import "SOGoTest.h"
#import <Mailer/NSString+Mail.h>

@interface TestNSStringMailFilename : SOGoTest
@end

@implementation TestNSStringMailFilename

- (void) test_asSafeFilenameKeepsNormalFilename
{
  testEquals ([@"report.pdf" asSafeFilename], @"report.pdf");
}

- (void) test_asSafeFilenameKeepsFilenameWithSpaces
{
  testEquals ([@"my file.txt" asSafeFilename], @"my file.txt");
}

- (void) test_asSafeFilenameOnDot
{
  testEquals ([@"." asSafeFilename], @"_");
}

- (void) test_asSafeFilenameOnDotDot
{
  testEquals ([@".." asSafeFilename], @"__");
}

- (void) test_asSafeFilenameOnBackslashDotDot
{
  testEquals ([@"..\\.." asSafeFilename], @"__");
}

- (void) test_asSafeFilenameOnBackslashPrefixedDot
{
  testEquals ([@"dir\\." asSafeFilename], @"_");
}

- (void) test_asSafeFilenameOnBackslashPrefixedDotDot
{
  testEquals ([@"dir\\.." asSafeFilename], @"__");
}

- (void) test_asSafeFilenameOnWindowsPath
{
  testEquals ([@"C:\\Users\\me\\file.txt" asSafeFilename], @"file.txt");
}

- (void) test_asSafeFilenameOnUnixPath
{
  testEquals ([@"/etc/passwd" asSafeFilename], @"_etc_passwd");
}

- (void) test_stringByTruncatingFilenameKeepsShortFilename
{
  testEquals ([@"report.pdf" stringByTruncatingFilenameToByteLength: 200],
              @"report.pdf");
}

- (void) test_stringByTruncatingFilenameKeepsFilenameAtByteLimit
{
  NSString *filename;

  filename = [[@"" stringByPaddingToLength: 98 withString: @"Д" startingAtIndex: 0]
              stringByAppendingString: @".pdf"];

  testEquals ([filename stringByTruncatingFilenameToByteLength: 200],
              filename);
}

- (void) test_stringByTruncatingFilenameBoundsLongCyrillicFilename
{
  NSString *filename;

  filename = [[@"" stringByPaddingToLength: 120 withString: @"Д" startingAtIndex: 0]
              stringByAppendingString: @".pdf"];

  testEquals ([filename stringByTruncatingFilenameToByteLength: 200],
              [[@"" stringByPaddingToLength: 98 withString: @"Д" startingAtIndex: 0]
               stringByAppendingString: @".pdf"]);
}

- (void) test_stringByTruncatingFilenameCutsOnUTF8Boundary
{
  testEquals ([@"ДДДД.pdf" stringByTruncatingFilenameToByteLength: 5],
              @"ДД");
}

- (void) test_stringByTruncatingFilenameFallsBackWhenExtensionTooLong
{
  NSString *filename, *expected;

  filename = [NSString stringWithFormat: @"a.%@",
                         [@"" stringByPaddingToLength: 210 withString: @"z" startingAtIndex: 0]];
  expected = [NSString stringWithFormat: @"a.%@",
                         [@"" stringByPaddingToLength: 198 withString: @"z" startingAtIndex: 0]];

  testEquals ([filename stringByTruncatingFilenameToByteLength: 200], expected);
}

@end
