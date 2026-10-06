#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import "SOGoTest.h"

@interface TestUIHeadingStructure : SOGoTest
@end

@implementation TestUIHeadingStructure

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

- (unsigned int) countOfString: (NSString *) needle
                       inString: (NSString *) haystack
{
  NSRange searchRange, foundRange;
  unsigned int count;

  count = 0;
  searchRange = NSMakeRange(0, [haystack length]);
  foundRange = [haystack rangeOfString: needle options: 0 range: searchRange];
  while (foundRange.location != NSNotFound)
    {
      count++;
      searchRange = NSMakeRange(NSMaxRange(foundRange), [haystack length] - NSMaxRange(foundRange));
      foundRange = [haystack rangeOfString: needle options: 0 range: searchRange];
    }

  return count;
}

- (void) test_sidenavCarriesExactlyOneLevelOneHeading
{
  NSString *template, *message;

  template = [self contentOfFile: @"UI/Templates/UIxSidenavToolbarTemplate.wox"];
  message = @"the sidenav must expose the user identification as the page heading (bug 5812)";
  testWithMessage([template rangeOfString: @"<h1 class=\"sg-md-title sg-no-wrap\" ng-bind=\"::activeUser.identification\">"].location != NSNotFound,
                  message);
  testEquals([NSNumber numberWithInt: [self countOfString: @"<h1" inString: template]], [NSNumber numberWithInt: 1]);
}

- (void) test_everyModuleFrameIncludesTheSidenavHeading
{
  NSArray *frames;
  NSString *frame, *template, *message;
  NSEnumerator *e;

  frames = [NSArray arrayWithObjects:
                        @"UI/Templates/MailerUI/UIxMailMainFrame.wox",
                        @"UI/Templates/SchedulerUI/UIxCalMainView.wox",
                        @"UI/Templates/ContactsUI/UIxContactFoldersView.wox",
                        @"UI/Templates/PreferencesUI/UIxPreferences.wox",
                        @"UI/Templates/AdministrationUI/UIxAdministration.wox",
                        nil];
  e = [frames objectEnumerator];
  while ((frame = [e nextObject]))
    {
      template = [self contentOfFile: frame];
      message = [NSString stringWithFormat: @"%@ must include UIxSidenavToolbarTemplate so its page carries an h1", frame];
      testWithMessage([template rangeOfString: @"UIxSidenavToolbarTemplate"].location != NSNotFound,
                      message);
    }
}

- (void) test_mailViewerSubjectIsALevelTwoHeadingWithNoSubjectFallback
{
  NSString *template;

  template = [self contentOfFile: @"UI/Templates/MailerUI/UIxMailViewTemplate.wox"];
  testWithMessage([template rangeOfString: @"<h2 class=\"sg-md-headline\" ng-bind=\"viewer.message.subject || ('(no subject)' | loc)\">"].location != NSNotFound,
                  @"the message subject must be a level-two heading that never renders empty (bug 5812)");
  testEquals([NSNumber numberWithInt: [self countOfString: @"<h5" inString: template]], [NSNumber numberWithInt: 0]);
}

- (void) test_mailDialogHeadingIsLevelTwo
{
  NSString *template;

  template = [self contentOfFile: @"UI/Templates/MailerUI/UIxMailFolderTemplate.wox"];
  testWithMessage([template rangeOfString: @"<h2 class=\"md-title\">"].location != NSNotFound,
                  @"dialog titles must start at level two like every other dialog");
  testEquals([NSNumber numberWithInt: [self countOfString: @"<h4" inString: template]], [NSNumber numberWithInt: 0]);
  testEquals([NSNumber numberWithInt: [self countOfString: @"<h5" inString: template]], [NSNumber numberWithInt: 0]);
}

- (void) test_contactCardTitleIsLevelTwoAndMembersNestBelowIt
{
  NSString *template;

  template = [self contentOfFile: @"UI/Templates/ContactsUI/UIxContactViewTemplate.wox"];
  testWithMessage([template rangeOfString: @"<h2 class=\"sg-md-display-2--thin\" ng-bind-html=\"editor.card.$fullname({html: true})\">"].location != NSNotFound,
                  @"the displayed contact must be the level-two heading of the address book page");
  testWithMessage([template rangeOfString: @"<h3>"].location != NSNotFound,
                  @"member names must remain level-three headings");
  testWithMessage([template rangeOfString: @"<h4 ng-show=\"ref.$preferredEmail()\">"].location != NSNotFound,
                  @"member e-mail addresses must remain level-four headings");
}

- (void) test_preferencesSectionHeadingsAreLevelTwo
{
  NSString *template;

  template = [self contentOfFile: @"UI/Templates/PreferencesUI/UIxPreferences.wox"];
  testWithMessage([template rangeOfString: @"<h2 class=\"md-title\"><var:string label:value=\"Password recovery\"/></h2>"].location != NSNotFound,
                  @"'Password recovery' must be a level-two section heading");
  testWithMessage([template rangeOfString: @"<h2 class=\"md-title\"><var:string label:value=\"Password change\"/></h2>"].location != NSNotFound,
                  @"'Password change' must be a level-two section heading");
  testWithMessage([template rangeOfString: @"<h2 class=\"md-title\"><var:string label:value=\"Activation Constraints\"/></h2>"].location != NSNotFound,
                  @"'Activation Constraints' must be a level-two section heading");
  testEquals([NSNumber numberWithInt: [self countOfString: @"<h5" inString: template]], [NSNumber numberWithInt: 0]);
}

- (void) test_themePreviewHeadingsAreLevelTwo
{
  testEquals([NSNumber numberWithInt: [self countOfString: @"<h2 class=\"md-title\">" inString: [self contentOfFile: @"UI/Templates/AdministrationUI/UIxThemePreview.wox"]]], [NSNumber numberWithInt: 5]);
  testEquals([NSNumber numberWithInt: [self countOfString: @"<h3" inString: [self contentOfFile: @"UI/Templates/AdministrationUI/UIxThemePreview.wox"]]], [NSNumber numberWithInt: 0]);
}

- (void) test_noSubjectLabelShipsInEnglish
{
  NSString *strings;

  strings = [self contentOfFile: @"UI/MailerUI/English.lproj/Localizable.strings"];
  testWithMessage([strings rangeOfString: @"\"(no subject)\" = \"(no subject)\";"].location != NSNotFound,
                  @"MailerUI must define the '(no subject)' label used by the subject heading fallback");
}

- (void) test_bundledCssResetsHeadingMargins
{
  NSString *css;

  css = [self contentOfFile: @"UI/WebServerResources/css/styles.css"];
  testWithMessage([css rangeOfString: @"html h1.sg-md-title,html h2.sg-md-display-2--thin{margin:0}"].location != NSNotFound,
                  @"the shipped stylesheet must keep the swapped headings margin-free (bug 5812)");
}

- (void) test_sassSourceResetsHeadingMargins
{
  NSString *scss;

  scss = [self contentOfFile: @"UI/WebServerResources/scss/core/typography.scss"];
  testWithMessage([scss rangeOfString: @"html h1.sg-md-title,"].location != NSNotFound,
                  @"the typography source must carry the heading margin reset too");
}

@end
