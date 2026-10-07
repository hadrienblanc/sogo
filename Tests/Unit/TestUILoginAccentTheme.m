/* TestUILoginAccentTheme.m - this file is part of SOGo
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

#import <Foundation/NSString.h>

#import "SOGoTest.h"

@interface TestUILoginAccentTheme : SOGoTest
@end

@implementation TestUILoginAccentTheme

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

- (void) test_themeCssRestoresLoginFormContrast
{
  NSString *css;

  css = [self contentOfFile: @"UI/WebServerResources/css/theme-default.css"];
  testWithMessage([css rangeOfString:
                    @".sg-login.md-accent.md-bg md-input-container:not(.md-input-invalid) label"].location != NSNotFound,
                  @"the login panel labels must be repainted with the accent contrast color (bug 5687)");
  testWithMessage([css rangeOfString:
                    @".sg-login.md-accent.md-bg md-input-container:not(.md-input-invalid) .md-placeholder"].location != NSNotFound,
                  @"the login panel placeholders must follow the accent contrast color");
  testWithMessage([css rangeOfString:
                    @".sg-login.md-accent.md-bg md-input-container:not(.md-input-invalid) .md-input"].location != NSNotFound,
                  @"the login panel input text must follow the accent contrast color");
  testWithMessage([css rangeOfString:
                    @".sg-login.md-accent.md-bg md-input-container:not(.md-input-invalid) md-icon"].location != NSNotFound,
                  @"the login panel icons must follow the accent contrast color");
  testWithMessage([css rangeOfString:
                    @".sg-login.md-accent.md-bg md-select .md-select-value {  color: rgb(255,255,255);}"].location != NSNotFound,
                  @"the login panel select value must be white, the accent contrast of sogo-green 500");
  testWithMessage([css rangeOfString:
                    @".md-select-value.md-select-placeholder"].location != NSNotFound,
                  @"angular-material must still own the base select placeholder rules overridden at equal specificity");
}

- (void) test_themeSourceRegistersLoginStyles
{
  NSString *source;

  source = [self contentOfFile: @"UI/WebServerResources/js/Common/Common.app.js"];
  testWithMessage([source rangeOfString:
                    @".sg-login.md-accent.md-bg md-select .md-select-value {'"].location != NSNotFound,
                  @"the login rules must be registered through $mdThemingProvider so regenerated themes keep them");
  testWithMessage([source rangeOfString:
                    @"color: \\'{{accent-default-contrast}}\\';"].location != NSNotFound,
                  @"the login rules must resolve the contrast color from the theme instead of hardcoding white");
}

- (void) test_builtBundleRegistersLoginStyles
{
  NSString *bundle;

  bundle = [self contentOfFile: @"UI/WebServerResources/js/Common.js"];
  testWithMessage([bundle rangeOfString:
                    @".sg-login.md-accent.md-bg md-input-container:not(.md-input-invalid) label,"].location != NSNotFound,
                  @"Common.js must ship the login page theming rules");
  testWithMessage([bundle rangeOfString:
                    @"color: '{{accent-default-contrast}}';"].location != NSNotFound,
                  @"Common.js must ship the theme-resolved contrast color of the login rules");
}

- (void) test_loginTemplateKeepsAccentPanel
{
  NSString *template;

  template = [self contentOfFile: @"UI/Templates/MainUI/SOGoRootPage.wox"];
  testWithMessage([template rangeOfString:
                    @"class=\"sg-login md-default-theme md-bg md-accent\""].location != NSNotFound,
                  @"the login panel must keep the theme classes the panel color and the overrides are anchored on");
}

- (void) test_loginTemplateDoesNotThemeFormElementsIndividually
{
  NSString *template;

  template = [self contentOfFile: @"UI/Templates/MainUI/SOGoRootPage.wox"];
  testWithMessage([template rangeOfString:
                    @"<label class=\"md-default-theme md-accent md-bg\""].location == NSNotFound,
                  @"login form elements must not carry md-accent md-bg classes, reverted upstream in d802b92a1 for breaking customizations");
}

@end
