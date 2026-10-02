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

@end
