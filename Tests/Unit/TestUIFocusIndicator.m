#import <Foundation/NSString.h>

#import "SOGoTest.h"

@interface TestUIFocusIndicator : SOGoTest
@end

@implementation TestUIFocusIndicator

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

- (void) test_builtStylesheetRestoresAHighContrastFocusRing
{
  NSString *css;

  css = [self contentOfFile: @"UI/WebServerResources/css/styles.css"];
  testWithMessage([css rangeOfString:
                    @"html body :is(a,button,input,select,textarea,[tabindex],.md-button,.md-tab,.md-chip-content,.md-autocomplete-suggestion,md-checkbox,md-option,md-radio-group,md-select,md-slider,md-switch):focus-visible{outline:2px solid currentColor;outline-offset:2px}"].location != NSNotFound,
                  @"styles.css must repaint a 2px focus ring on every keyboard-focusable control (bug 5805)");
}

- (void) test_builtStylesheetKeepsFocusOnMailboxLinks
{
  NSString *css;

  css = [self contentOfFile: @"UI/WebServerResources/css/styles.css"];
  testWithMessage([css rangeOfString: @".sg-item-name:focus{outline:0}"].location == NSNotFound,
                  @"the mailbox list must not strip the focus outline of its links anymore");
}

- (void) test_builtStylesheetKeepsFocusOnReadonlyChips
{
  NSString *css;

  css = [self contentOfFile: @"UI/WebServerResources/css/styles.css"];
  testWithMessage([css rangeOfString: @"md-chip-template:focus{outline:0}"].location == NSNotFound,
                  @"readonly chips (mail recipients) must not strip their focus outline anymore");
}

- (void) test_builtStylesheetKeepsFocusOnTimePane
{
  NSString *css;

  css = [self contentOfFile: @"UI/WebServerResources/css/styles.css"];
  testWithMessage([css rangeOfString: @"sg-time-pane:focus{outline:0}"].location == NSNotFound,
                  @"the time picker pane must not strip its focus outline anymore");
}

- (void) test_builtStylesheetKeepsFocusOnCalendarEvents
{
  NSString *css;

  css = [self contentOfFile: @"UI/WebServerResources/css/styles.css"];
  testWithMessage([css rangeOfString: @"opacity:.9;outline:0;"].location == NSNotFound,
                  @"calendar events must not strip their focus outline anymore");
}

- (void) test_sassSourceCarriesTheFocusRingRule
{
  NSString *scss;

  scss = [self contentOfFile: @"UI/WebServerResources/scss/core/structure.scss"];
  testWithMessage([scss rangeOfString: @"md-switch):focus-visible {"].location != NSNotFound,
                  @"the structure source must carry the focus-visible rule too");
  testWithMessage([scss rangeOfString: @"outline: 2px solid currentColor;"].location != NSNotFound,
                  @"the focus indicator must inherit the control colour to keep a 3:1 ratio");
}

- (void) test_sassSourcesDontSuppressFocusOutlines
{
  NSArray *sources;
  NSString *source, *message;
  NSEnumerator *e;

  sources = [NSArray arrayWithObjects:
                        @"UI/WebServerResources/scss/views/MailerUI.scss",
                        @"UI/WebServerResources/scss/views/SchedulerUI.scss",
                        @"UI/WebServerResources/scss/components/chips/chips.scss",
                        @"UI/WebServerResources/scss/components/timepicker/timepicker.scss",
                        nil];
  e = [sources objectEnumerator];
  while ((source = [e nextObject]))
    {
      NSString *scss;

      scss = [self contentOfFile: source];
      message = [NSString stringWithFormat: @"%@ must not disable focus outlines", source];
      testWithMessage([scss rangeOfString: @"outline: none;"].location == NSNotFound, message);
      testWithMessage([scss rangeOfString: @"outline: 0;"].location == NSNotFound, message);
    }
}

@end
