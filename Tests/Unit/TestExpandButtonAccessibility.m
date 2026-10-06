#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import "SOGoTest.h"

@interface TestExpandButtonAccessibility : SOGoTest
@end

@implementation TestExpandButtonAccessibility

- (NSArray *) expandButtonTemplates
{
  return [NSArray arrayWithObjects:
                    @"UI/Templates/MailerUI/UIxMailViewTemplate.wox",
                    @"UI/Templates/MailerUI/UIxMailEditor.wox",
                    @"UI/Templates/ContactsUI/UIxContactViewTemplate.wox",
                    @"UI/Templates/ContactsUI/UIxContactEditorTemplate.wox",
                    @"UI/Templates/SchedulerUI/UIxCalDayView.wox",
                    @"UI/Templates/SchedulerUI/UIxCalWeekView.wox",
                    @"UI/Templates/SchedulerUI/UIxCalMonthView.wox",
                    @"UI/Templates/SchedulerUI/UIxCalMulticolumnDayView.wox",
                    @"UI/Templates/SchedulerUI/UIxAppointmentEditorTemplate.wox",
                    nil];
}

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

- (NSString *) expandButtonBlockOfTemplate: (NSString *) relativePath
{
  NSString *content, *block, *message;
  NSRange buttonRange, clickRange, closeRange;

  content = [self contentOfFile: relativePath];
  clickRange = [content rangeOfString: @"toggleCenter("];
  if (clickRange.location == NSNotFound)
    clickRange = [content rangeOfString: @"toggleFullscreen("];
  message = [NSString stringWithFormat: @"%@ must render the expand/reduce button", relativePath];
  testWithMessage(clickRange.location != NSNotFound, message);

  buttonRange = [content rangeOfString: @"<md-button"
                               options: NSBackwardsSearch
                                 range: NSMakeRange(0, clickRange.location)];
  message = [NSString stringWithFormat: @"%@ must bind the expand/reduce handler on an md-button", relativePath];
  testWithMessage(buttonRange.location != NSNotFound, message);

  closeRange = [content rangeOfString: @"</md-button>"
                              options: 0
                                range: NSMakeRange(clickRange.location, [content length] - clickRange.location)];
  message = [NSString stringWithFormat: @"%@ must close the expand/reduce md-button after its handler", relativePath];
  testWithMessage(closeRange.location != NSNotFound, message);

  block = [content substringWithRange: NSMakeRange(buttonRange.location,
                                                   NSMaxRange(closeRange) - buttonRange.location)];

  return block;
}

- (NSString *) openingTagOfBlock: (NSString *) block
{
  NSRange tagRange;

  tagRange = [block rangeOfString: @">"];

  return [block substringToIndex: NSMaxRange(tagRange)];
}

- (void) test_expandButtonIsNotHiddenFromScreenReaders
{
  NSString *block, *openingTag, *message;
  NSEnumerator *e;
  NSString *template;

  e = [[self expandButtonTemplates] objectEnumerator];
  while ((template = [e nextObject]))
    {
      block = [self expandButtonBlockOfTemplate: template];
      openingTag = [self openingTagOfBlock: block];
      message = [NSString stringWithFormat: @"the expand/reduce button of %@ must stay exposed to screen readers (bug 5810)", template];
      testWithMessage([openingTag rangeOfString: @"aria-hidden"].location == NSNotFound, message);
    }
}

- (void) test_expandButtonIsNamedByExpandAndReduceTooltips
{
  NSString *block, *message;
  NSEnumerator *e;
  NSString *template;

  e = [[self expandButtonTemplates] objectEnumerator];
  while ((template = [e nextObject]))
    {
      block = [self expandButtonBlockOfTemplate: template];
      message = [NSString stringWithFormat: @"the expand/reduce button of %@ must offer the 'Reduce' tooltip as accessible name", template];
      testWithMessage([block rangeOfString: @"'Reduce' | loc"].location != NSNotFound, message);
      message = [NSString stringWithFormat: @"the expand/reduce button of %@ must offer the 'Expand' tooltip as accessible name", template];
      testWithMessage([block rangeOfString: @"'Expand' | loc"].location != NSNotFound, message);
    }
}

@end
