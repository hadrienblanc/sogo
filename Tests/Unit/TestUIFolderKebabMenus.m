#import <Foundation/NSArray.h>
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

@interface TestUIFolderKebabMenus : SOGoTest
@end

@implementation TestUIFolderKebabMenus

- (NSString *) contentOfFile: (NSString *) relativePath
{
  NSString *path, *content, *message;

  path = [@"../../" stringByAppendingString: relativePath];
  message = [NSString stringWithFormat: @"%@ must be readable as UTF-8", path];
  content = [NSString stringWithContentsOfFile: path
                                       encoding: NSUTF8StringEncoding
                                          error: NULL];
  testWithMessage(content != nil, message);

  return content;
}

- (NSArray *) substringsFrom: (NSString *) startMarker
                          to: (NSString *) endMarker
                   inString: (NSString *) content
{
  NSMutableArray *substrings;
  NSRange searchRange, startRange, endRange;

  substrings = [NSMutableArray array];
  searchRange = NSMakeRange(0, [content length]);

  startRange = [content rangeOfString: startMarker options: 0 range: searchRange];
  while (startRange.location != NSNotFound)
    {
      endRange = [content rangeOfString: endMarker
                                options: 0
                                  range: NSMakeRange(NSMaxRange(startRange),
                                                     [content length] - NSMaxRange(startRange))];
      if (endRange.location == NSNotFound)
        break;
      [substrings addObject: [content substringWithRange:
                                      NSMakeRange(startRange.location,
                                                  NSMaxRange(endRange) - startRange.location)]];
      searchRange = NSMakeRange(NSMaxRange(endRange),
                                [content length] - NSMaxRange(endRange));
      startRange = [content rangeOfString: startMarker options: 0 range: searchRange];
    }

  return substrings;
}

- (void) test_mailFolderKebabExposesRoleHaspopupAndState
{
  NSString *script, *kebab, *message;

  script = [self contentOfFile: @"UI/WebServerResources/js/Mailer/sgMailboxListItem.directive.js"];
  kebab = [[self substringsFrom: @"md-menu md-secondary-container"
                             to: @"more_vert</md-icon>"
                      inString: script] lastObject];
  message = @"the mail folder kebab trigger must be found in sgMailboxListItem.directive.js";
  testWithMessage(kebab != nil, message);
  if (kebab == nil)
    return;

  message = @"the mail folder kebab must expose a button role instead of the md-icon default img role (bug 5803)";
  testWithMessage([kebab rangeOfString: @"role=\"button\""].location != NSNotFound, message);
  message = @"the mail folder kebab must announce that it opens a menu";
  testWithMessage([kebab rangeOfString: @"aria-haspopup=\"true\""].location != NSNotFound, message);
  message = @"the mail folder kebab must reflect its expanded state for assistive technologies";
  testWithMessage([kebab rangeOfString: @"ng-attr-aria-expanded=\"$ctrl.menuIsOpen\""].location != NSNotFound, message);
  message = @"the mail folder kebab must keep its accessible name";
  testWithMessage([kebab rangeOfString: @"aria-label=\"' + l(\"Options\") + '\""].location != NSNotFound, message);
}

- (void) test_calendarKebabExposesRoleHaspopupAndState
{
  NSString *script, *kebab, *message;

  script = [self contentOfFile: @"UI/WebServerResources/js/Scheduler/sgCalendarListItem.directive.js"];
  kebab = [[self substringsFrom: @"md-menu md-secondary-container sg-list-sortable-hide"
                             to: @"more_vert</md-icon>"
                      inString: script] lastObject];
  message = @"the calendar kebab trigger must be found in sgCalendarListItem.directive.js";
  testWithMessage(kebab != nil, message);
  if (kebab == nil)
    return;

  message = @"the calendar kebab must expose a button role instead of the md-icon default img role (bug 5803)";
  testWithMessage([kebab rangeOfString: @"role=\"button\""].location != NSNotFound, message);
  message = @"the calendar kebab must announce that it opens a menu";
  testWithMessage([kebab rangeOfString: @"aria-haspopup=\"true\""].location != NSNotFound, message);
  message = @"the calendar kebab must reflect its expanded state for assistive technologies";
  testWithMessage([kebab rangeOfString: @"ng-attr-aria-expanded=\"$ctrl.menuIsOpen\""].location != NSNotFound, message);
  message = @"the calendar kebab must keep its accessible name";
  testWithMessage([kebab rangeOfString: @"aria-label=\"' + l(\"Options\") + '\""].location != NSNotFound, message);
}

- (void) test_mailFolderKebabStateFollowsTheMenuPanelLifecycle
{
  NSString *script, *body, *message;

  script = [self contentOfFile: @"UI/WebServerResources/js/Mailer/sgMailboxListItem.directive.js"];

  body = BodyOfFunction(script, @"this.$onInit = function");
  message = @"$onInit must be found in sgMailboxListItem.directive.js";
  testWithMessage(body != nil, message);
  if (body != nil)
    {
      message = @"the mail folder kebab must start collapsed";
      testWithMessage([body rangeOfString: @"this.menuIsOpen = false"].location != NSNotFound, message);
    }

  body = BodyOfFunction(script, @"this.showMenu = function");
  message = @"showMenu must be found in sgMailboxListItem.directive.js";
  testWithMessage(body != nil, message);
  if (body != nil)
    {
      message = @"opening the mail folder menu must expand the kebab";
      testWithMessage([body rangeOfString: @"$ctrl.menuIsOpen = true"].location != NSNotFound, message);
      message = @"any close path of the mail folder menu (action, escape, click outside) must collapse the kebab";
      testWithMessage([body rangeOfString: @"$ctrl.menuIsOpen = false"].location != NSNotFound, message);
    }
}

- (void) test_calendarKebabStateFollowsTheMenuPanelLifecycle
{
  NSString *script, *body, *message;

  script = [self contentOfFile: @"UI/WebServerResources/js/Scheduler/sgCalendarListItem.directive.js"];

  body = BodyOfFunction(script, @"this.$onInit = function");
  message = @"$onInit must be found in sgCalendarListItem.directive.js";
  testWithMessage(body != nil, message);
  if (body != nil)
    {
      message = @"the calendar kebab must start collapsed";
      testWithMessage([body rangeOfString: @"this.menuIsOpen = false"].location != NSNotFound, message);
    }

  body = BodyOfFunction(script, @"this.showMenu = function");
  message = @"showMenu must be found in sgCalendarListItem.directive.js";
  testWithMessage(body != nil, message);
  if (body != nil)
    {
      message = @"opening the calendar menu must expand the kebab";
      testWithMessage([body rangeOfString: @"$ctrl.menuIsOpen = true"].location != NSNotFound, message);
      message = @"any close path of the calendar menu (action, escape, click outside) must collapse the kebab";
      testWithMessage([body rangeOfString: @"$ctrl.menuIsOpen = false"].location != NSNotFound, message);
    }
}

- (void) test_addressBookKebabExposesAButtonRole
{
  NSArray *kebabs;
  NSString *template, *kebab, *message;
  NSEnumerator *e;

  template = [self contentOfFile: @"UI/Templates/ContactsUI/UIxContactFoldersView.wox"];
  kebabs = [self substringsFrom: @"label:aria-label=\"Options\""
                             to: @"more_vert</md-icon>"
                      inString: template];
  message = @"both address book kebab triggers (own folders and subscriptions) must be found";
  testWithMessage([kebabs count] == 2, message);

  e = [kebabs objectEnumerator];
  while ((kebab = [e nextObject]))
    {
      message = @"the address book kebab must expose a button role instead of the md-icon default img role (bug 5803)";
      testWithMessage([kebab rangeOfString: @"role=\"button\""].location != NSNotFound, message);
    }
}

- (void) test_folderMenuPanelsExposeAMenuRole
{
  NSArray *segments;
  NSString *template, *segment, *message;

  template = [self contentOfFile: @"UI/Templates/MailerUI/UIxMailMainFrame.wox"];
  segments = [self substringsFrom: @"id=\"UIxMailFolderMenu\""
                               to: @"markFolderRead"
                        inString: template];
  message = @"the mail folder menu panel must be found in UIxMailMainFrame.wox";
  testWithMessage([segments count] == 1, message);
  if ([segments count] == 1)
    {
      segment = [segments objectAtIndex: 0];
      message = @"the mail folder menu panel must expose a menu role (bug 5803)";
      testWithMessage([segment rangeOfString: @"role=\"menu\""].location != NSNotFound, message);
    }

  template = [self contentOfFile: @"UI/Templates/SchedulerUI/UIxCalMainView.wox"];
  segments = [self substringsFrom: @"id=\"UIxCalendarMenu\""
                               to: @"showOnly"
                        inString: template];
  message = @"the calendar menu panel must be found in UIxCalMainView.wox";
  testWithMessage([segments count] == 1, message);
  if ([segments count] == 1)
    {
      segment = [segments objectAtIndex: 0];
      message = @"the calendar menu panel must expose a menu role (bug 5803)";
      testWithMessage([segment rangeOfString: @"role=\"menu\""].location != NSNotFound, message);
    }
}

@end
