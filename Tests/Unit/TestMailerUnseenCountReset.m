/* TestMailerUnseenCountReset.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any
 * later version.
 *
 * This file is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSFileManager.h>
#import <Foundation/NSRange.h>
#import <Foundation/NSString.h>

#import "SOGoTest.h"

static NSString *BodyOfFunction(NSString *content, NSString *signature)
{
  NSRange signatureRange, scanRange, braceRange;
  NSUInteger start, depth, i, max;
  unichar c;

  signatureRange = [content rangeOfString: signature];
  if (signatureRange.location == NSNotFound)
    return nil;

  scanRange = NSMakeRange(NSMaxRange(signatureRange),
                          [content length] - NSMaxRange(signatureRange));
  braceRange = [content rangeOfString: @"{" options: 0 range: scanRange];
  if (braceRange.location == NSNotFound)
    return nil;

  start = braceRange.location;
  depth = 0;
  max = [content length];
  for (i = start; i < max; i++)
    {
      c = [content characterAtIndex: i];
      if (c == '{')
        depth++;
      else if (c == '}')
        {
          depth--;
          if (depth == 0)
            return [content substringWithRange: NSMakeRange(start, i - start + 1)];
        }
    }

  return nil;
}

@interface TestMailerUnseenCountReset : SOGoTest
@end

@implementation TestMailerUnseenCountReset

- (NSString *) mailerScript: (NSString *) relativePath
{
  NSString *path, *content, *message;

  path = [@"../../" stringByAppendingString: relativePath];
  message = [NSString stringWithFormat: @"%@ must be reachable from the unit tests", path];
  testWithMessage([[NSFileManager defaultManager] fileExistsAtPath: path], message);
  content = [NSString stringWithContentsOfFile: path];
  testWithMessage(content != nil, @"the script must be readable");

  return content;
}

- (void) test_omitKeepsUnseenCountOutOfTheShadowSnapshot
{
  NSString *content, *body;

  content = [self mailerScript: @"UI/WebServerResources/js/Mailer/Mailbox.service.js"];
  body = BodyOfFunction(content, @"Mailbox.prototype.$omit = function");
  testWithMessage(body != nil,
                  @"Mailbox.prototype.$omit must be found in Mailbox.service.js");
  testWithMessage([body rangeOfString: @"key != 'unseenCount'"].location != NSNotFound,
                  @"$omit must exclude unseenCount so it never enters $shadowData nor the save payload");
}

- (void) test_resetLeavesTheUnseenCountUntouched
{
  NSString *content, *body;

  content = [self mailerScript: @"UI/WebServerResources/js/Mailer/Mailbox.service.js"];
  body = BodyOfFunction(content, @"Mailbox.prototype.$reset = function");
  testWithMessage(body != nil,
                  @"Mailbox.prototype.$reset must be found in Mailbox.service.js");
  testWithMessage([body rangeOfString: @"unseenCount"].location == NSNotFound,
                  @"$reset must not handle unseenCount: a restored or passed counter resurrects stale values (bug 6064)");
}

- (void) test_selectFolderNeverInjectsAnUnseenCount
{
  NSString *content, *body;

  content = [self mailerScript: @"UI/WebServerResources/js/Mailer/sgMailboxListItem.directive.js"];
  body = BodyOfFunction(content, @"this.selectFolder = function");
  testWithMessage(body != nil,
                  @"selectFolder must be found in sgMailboxListItem.directive.js");
  testWithMessage([body rangeOfString: @"unseenCount"].location == NSNotFound,
                  @"leaving a folder or a search must not re-inject an unread counter");
}

- (void) test_selectFolderOnlyResetsTheFilter
{
  NSString *content, *body;

  content = [self mailerScript: @"UI/WebServerResources/js/Mailer/sgMailboxListItem.directive.js"];
  body = BodyOfFunction(content, @"this.selectFolder = function");
  testWithMessage(body != nil,
                  @"selectFolder must be found in sgMailboxListItem.directive.js");
  testWithMessage([body rangeOfString: @"$reset({ filter: true })"].location != NSNotFound,
                  @"selectFolder must reset the previous folder with the filter option only");
}

@end
