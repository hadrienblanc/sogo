#import <Foundation/NSString.h>

#import "SOGoTest.h"

@interface TestUICalendarSwitchKeyboard : SOGoTest
@end

@implementation TestUICalendarSwitchKeyboard

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

- (void) test_calendarSwitchTemplateBindsTheEnterKey
{
  NSString *source;

  source = [self contentOfFile: @"UI/WebServerResources/js/Scheduler/sgCalendarListItem.directive.js"];
  testWithMessage([source rangeOfString:
                    @"sg-enter=\"$ctrl.toggleFolder()\""].location != NSNotFound,
                  @"the calendar switch must be operable with the Enter key (bug 5802)");
}

- (void) test_calendarSwitchControllerTogglesActivation
{
  NSString *source;

  source = [self contentOfFile: @"UI/WebServerResources/js/Scheduler/sgCalendarListItem.directive.js"];
  testWithMessage([source rangeOfString:
                    @"this.toggleFolder = function() {\n      this.calendar.active = this.calendar.active ? 0 : 1;\n    };"].location != NSNotFound,
                  @"the Enter key must flip calendar.active between 1 and 0 like a click on the switch");
}

- (void) test_builtBundleBindsTheEnterKey
{
  NSString *bundle;

  bundle = [self contentOfFile: @"UI/WebServerResources/js/Scheduler.services.js"];
  testWithMessage([bundle rangeOfString:
                    @"sg-enter=\"$ctrl.toggleFolder()\""].location != NSNotFound,
                  @"Scheduler.services.js must ship the Enter key binding of the calendar switch");
  testWithMessage([bundle rangeOfString:
                    @"this.toggleFolder=function(){this.calendar.active=this.calendar.active?0:1}"].location != NSNotFound,
                  @"Scheduler.services.js must ship the Enter key toggle of the calendar switch");
}

- (void) test_enterDirectiveIsLoadedOnTheCalendarPage
{
  NSString *template, *bundle;

  template = [self contentOfFile: @"UI/Templates/SchedulerUI/UIxCalMainView.wox"];
  testWithMessage([template rangeOfString: @", Common.js,"].location != NSNotFound,
                  @"the calendar page must load Common.js, which defines sg-enter");

  bundle = [self contentOfFile: @"UI/WebServerResources/js/Common.js"];
  testWithMessage([bundle rangeOfString:
                    @".directive(\"sgEnter\""].location != NSNotFound,
                  @"the Common.js bundle must ship the sgEnter directive");
}

@end
