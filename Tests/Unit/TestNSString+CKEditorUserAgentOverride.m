/* TestNSString+CKEditorUserAgentOverride.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <SOGo/NSString+Utilities.h>
#import "SOGoTest.h"

@interface TestNSString_plus_CKEditorUserAgentOverride : SOGoTest
@end

@implementation TestNSString_plus_CKEditorUserAgentOverride

- (void) test_firefoxAndroidPhoneIsMasked
{
  NSString *ua, *override;

  ua = @"Mozilla/5.0 (Android 16; Mobile; rv:149.0) Gecko/149.0 Firefox/149.0";
  override = [ua ckEditorUserAgentOverride];
  testEquals(override, @"Mozilla/5.0 (X11; Linux x86_64) Gecko/149 Firefox/149");

  ua = @"Mozilla/5.0 (Android 14; Mobile; rv:132.0) Gecko/132.0 Firefox/132.0";
  override = [ua ckEditorUserAgentOverride];
  testEquals(override, @"Mozilla/5.0 (X11; Linux x86_64) Gecko/132 Firefox/132");
}

- (void) test_firefoxAndroidTabletIsMasked
{
  NSString *ua, *override;

  ua = @"Mozilla/5.0 (Android 16; Tablet; rv:149.0) Gecko/149.0 Firefox/149.0";
  override = [ua ckEditorUserAgentOverride];
  testEquals(override, @"Mozilla/5.0 (X11; Linux x86_64) Gecko/149 Firefox/149");
}

- (void) test_chromeAndroidIsLeftAlone
{
  NSString *ua;

  ua = @"Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36";
  failIf([ua ckEditorUserAgentOverride] != nil);
}

- (void) test_firefoxDesktopIsLeftAlone
{
  NSString *ua;

  ua = @"Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/20100101 Firefox/149.0";
  failIf([ua ckEditorUserAgentOverride] != nil);
}

- (void) test_firefoxAndroidDesktopViewIsLeftAlone
{
  NSString *ua;

  ua = @"Mozilla/5.0 (X11; Linux x86_64; rv:149.0) Gecko/149.0 Firefox/149.0";
  failIf([ua ckEditorUserAgentOverride] != nil);
}

- (void) test_safariAndEdgeAreLeftAlone
{
  NSString *ua;

  ua = @"Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1";
  failIf([ua ckEditorUserAgentOverride] != nil);

  ua = @"Mozilla/5.0 (Linux; Android 10; Pixel 3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36 EdgA/124.0.2478.50";
  failIf([ua ckEditorUserAgentOverride] != nil);
}

- (void) test_emptyAndMissingGeckoReturnNoOverride
{
  failIf([@"" ckEditorUserAgentOverride] != nil);
  failIf([@"Android without gecko token" ckEditorUserAgentOverride] != nil);
  failIf([@"Gecko/149.0 without android token" ckEditorUserAgentOverride] != nil);
}

- (void) test_hostileUserAgentCannotInjectJavaScript
{
  NSString *ua, *override;

  ua = @"Mozilla/5.0 (Android 16; Mobile; rv:149.0) Gecko/149.0'; alert(1); Firefox/149.0";
  override = [ua ckEditorUserAgentOverride];
  testEquals(override, @"Mozilla/5.0 (X11; Linux x86_64) Gecko/149 Firefox/149");

  ua = @"Android Gecko/9'; window.xss=1";
  override = [ua ckEditorUserAgentOverride];
  testEquals(override, @"Mozilla/5.0 (X11; Linux x86_64) Gecko/9 Firefox/9");
}

@end
