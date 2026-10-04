/* TestSOGoMailReply.m - this file is part of SOGo
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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#import "SOGoTest.h"

#define REPLY_CLASS_NAME @"SOGoMailEnglishReply"

static NSString *CitePrefixOpen = @"<div class=\"moz-cite-prefix\">";
static NSString *CitePrefixClose = @"</div>";

@interface TestSOGoMailReplySourceMail : NSObject
{
  NSString *editingContent;
  NSString *messageID;
}

- (id) initWithEditingContent: (NSString *) newEditingContent
                    messageID: (NSString *) newMessageID;

@end

@implementation TestSOGoMailReplySourceMail

- (id) initWithEditingContent: (NSString *) newEditingContent
                    messageID: (NSString *) newMessageID
{
  if ((self = [super init]))
    {
      editingContent = [newEditingContent retain];
      messageID = [newMessageID retain];
    }

  return self;
}

- (void) dealloc
{
  [editingContent release];
  [messageID release];
  [super dealloc];
}

- (NSString *) contentForEditing
{
  return editingContent;
}

- (id) envelope
{
  return self;
}

- (NSString *) messageID
{
  return messageID;
}

@end

@interface TestSOGoMailReply : SOGoTest
{
  Class replyClass;
}

@end

@implementation TestSOGoMailReply

- (void) setUp
{
  if (!replyClass)
    {
      if (![SOGoTest loadSOGoBundle: @"Contacts"
                          markerClass: REPLY_CLASS_NAME])
        [SOGoTest loadSOGoBundle: @"Mailer"
                      markerClass: REPLY_CLASS_NAME];
      replyClass = NSClassFromString (REPLY_CLASS_NAME);
    }

  testWithMessage (replyClass != Nil,
                   @"SOGoMailEnglishReply class unavailable (Mailer.SOGo bundle missing)");
}

- (id) _pageWithSourceMail: (TestSOGoMailReplySourceMail *) mail
                     isHTML: (BOOL) isHTML
{
  id page;

  page = [[replyClass alloc] init];
  if (mail)
    [page setValue: mail forKey: @"sourceMail"];
  [page setValue: [NSNumber numberWithBool: isHTML] forKey: @"htmlComposition"];

  return [page autorelease];
}

- (void) test_htmlReplyCitePrefixOpen
{
  testEquals (CitePrefixOpen,
              [[self _pageWithSourceMail: nil isHTML: YES] performSelector: @selector(citePrefixOpen)]);
}

- (void) test_htmlReplyCitePrefixClose
{
  testEquals (CitePrefixClose,
              [[self _pageWithSourceMail: nil isHTML: YES] performSelector: @selector(citePrefixClose)]);
}

- (void) test_textReplyCitePrefixOpen
{
  testEquals (@"",
              [[self _pageWithSourceMail: nil isHTML: NO] performSelector: @selector(citePrefixOpen)]);
}

- (void) test_textReplyCitePrefixClose
{
  testEquals (@"",
              [[self _pageWithSourceMail: nil isHTML: NO] performSelector: @selector(citePrefixClose)]);
}

- (void) test_htmlReplyMessageBodyQuotesWithCite
{
  TestSOGoMailReplySourceMail *mail;
  NSString *value;

  mail = [[TestSOGoMailReplySourceMail alloc] initWithEditingContent: @"<p>hello</p>"
                                                           messageID: @"<abc@example.org>"];
  value = [[self _pageWithSourceMail: mail isHTML: YES] performSelector: @selector(messageBody)];
  testEquals (@"<blockquote type=\"cite\" cite=\"abc@example.org\"><p>hello</p></blockquote>",
              value);
  [mail release];
}

- (void) test_allReplyTemplatesMarkCitePrefix
{
  NSFileManager *fm;
  NSString *baseDir, *resourcesPath, *woDir, *path, *content;
  NSArray *entries;
  NSEnumerator *entry;
  unsigned int count;

  fm = [NSFileManager defaultManager];
  baseDir = [[[fm currentDirectoryPath] stringByAppendingPathComponent: @"../.."]
                    stringByStandardizingPath];
  resourcesPath = [[baseDir stringByAppendingPathComponent: @"SoObjects/Mailer/Mailer.SOGo"]
                          stringByAppendingPathComponent: @"Resources"];
  entries = [fm directoryContentsAtPath: resourcesPath];

  count = 0;
  entry = [entries objectEnumerator];
  while ((woDir = [entry nextObject]))
    {
      if (![woDir hasPrefix: @"SOGoMail"] || ![woDir hasSuffix: @"Reply.wo"])
        continue;

      path = [[resourcesPath stringByAppendingPathComponent: woDir]
                      stringByAppendingPathComponent:
                        [woDir stringByAppendingString: @".html"]];
      content = [NSString stringWithContentsOfFile: path];
      testWithMessage (([content rangeOfString: @"<#standardMode><#citePrefixOpen/>"].length > 0),
                       path);
      testWithMessage (([content rangeOfString: @"<#citePrefixClose/></#standardMode"].length > 0),
                       path);

      path = [[resourcesPath stringByAppendingPathComponent: woDir]
                      stringByAppendingPathComponent:
                        [woDir stringByAppendingString: @".wod"]];
      content = [NSString stringWithContentsOfFile: path];
      testWithMessage (([content rangeOfString: @"citePrefixOpen: WOString"].length > 0),
                       path);
      testWithMessage (([content rangeOfString: @"citePrefixClose: WOString"].length > 0),
                       path);

      count++;
    }

  testWithMessage ((count > 40),
                   ([NSString stringWithFormat: @"only %u reply templates found in %@",
                             count, resourcesPath]));
}

@end
