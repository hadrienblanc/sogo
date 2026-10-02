/* TestApacheAliasDirectives.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import "SOGoTest.h"

#import <Foundation/NSCharacterSet.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSString.h>

static int ApacheAliasMatches(const char *uri, const char *aliasFakename)
{
  const char *aliasp = aliasFakename;
  const char *urip = uri;

  while (*aliasp)
    {
      if (*aliasp == '/')
        {
          if (*urip != '/')
            return 0;

          do
            {
              ++aliasp;
            }
          while (*aliasp == '/');
          do
            {
              ++urip;
            }
          while (*urip == '/');
        }
      else
        {
          if (*urip++ != *aliasp++)
            return 0;
        }
    }

  if (aliasp[-1] != '/' && *urip != '\0' && *urip != '/')
    return 0;

  return (int) (urip - uri);
}

static NSArray *ApacheAliasDirectivesInFile(NSString *path)
{
  NSMutableArray *directives;
  NSArray *lines;
  NSString *content, *pending;
  NSUInteger i, max;

  content = [NSString stringWithContentsOfFile: path];
  if (content == nil)
    return nil;

  directives = [NSMutableArray array];
  pending = nil;
  lines = [content componentsSeparatedByString: @"\n"];
  max = [lines count];
  for (i = 0; i < max; i++)
    {
      NSString *line, *trimmed;
      NSMutableArray *tokens;
      NSArray *chunks;
      NSUInteger c, cmax;

      line = [lines objectAtIndex: i];
      if (pending != nil)
        {
          line = [pending stringByAppendingString: line];
          pending = nil;
        }
      trimmed = [line stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if ([trimmed length] == 0)
        continue;
      if ([trimmed hasSuffix: @"\\"])
        {
          pending = [trimmed substringToIndex: [trimmed length] - 1];
          continue;
        }
      if ([trimmed hasPrefix: @"#"])
        continue;

      chunks = [trimmed componentsSeparatedByString: @" "];
      tokens = [NSMutableArray array];
      cmax = [chunks count];
      for (c = 0; c < cmax; c++)
        {
          NSString *chunk = [chunks objectAtIndex: c];

          if ([chunk length] > 0)
            [tokens addObject: chunk];
        }

      if ([tokens count] >= 3
          && [[tokens objectAtIndex: 0] isEqualToString: @"Alias"])
        [directives addObject:
                     [NSDictionary dictionaryWithObjectsAndKeys:
                                  [tokens objectAtIndex: 1], @"fake",
                                  [tokens objectAtIndex: 2], @"real",
                                  nil]];
    }

  return directives;
}

static NSArray *IndicesOfShadowedAliasFakes(NSArray *fakes)
{
  NSMutableArray *shadowed;
  NSUInteger i, j, max;

  shadowed = [NSMutableArray array];
  max = [fakes count];
  for (i = 0; i < max; i++)
    {
      BOOL isShadowed;

      isShadowed = NO;
      for (j = 0; j < i; j++)
        {
          if (ApacheAliasMatches([[fakes objectAtIndex: i] UTF8String],
                                 [[fakes objectAtIndex: j] UTF8String]) > 0)
            {
              isShadowed = YES;
              break;
            }
        }
      if (isShadowed)
        [shadowed addObject: [NSNumber numberWithUnsignedInteger: i]];
    }

  return shadowed;
}

@interface TestApacheAliasDirectives : SOGoTest
@end

@implementation TestApacheAliasDirectives

- (NSArray *) aliasDirectivesOfShippedConf
{
  NSString *path;
  NSArray *directives;

  path = @"../../Apache/SOGo.conf";
  testWithMessage([[NSFileManager defaultManager] fileExistsAtPath: path],
                  @"Apache/SOGo.conf must be reachable from the unit tests");
  directives = ApacheAliasDirectivesInFile(path);
  testWithMessage(directives != nil, @"Apache/SOGo.conf must be parsable");

  return directives;
}

- (void) test_shippedConfExposesBothWebServerResourcesPrefixes
{
  NSArray *directives, *fakes;
  NSDictionary *woa, *plain;
  NSUInteger i, max;

  directives = [self aliasDirectivesOfShippedConf];
  fakes = [directives valueForKey: @"fake"];
  testWithMessage([fakes containsObject: @"/SOGo.woa/WebServerResources/"],
                  @"the shipped conf must alias the legacy .woa prefix");
  testWithMessage([fakes containsObject: @"/SOGo/WebServerResources/"],
                  @"the shipped conf must alias the plain /SOGo prefix");

  woa = nil;
  plain = nil;
  max = [directives count];
  for (i = 0; i < max; i++)
    {
      NSDictionary *directive = [directives objectAtIndex: i];

      if ([[directive objectForKey: @"fake"]
               isEqualToString: @"/SOGo.woa/WebServerResources/"])
        woa = directive;
      else if ([[directive objectForKey: @"fake"]
                    isEqualToString: @"/SOGo/WebServerResources/"])
        plain = directive;
    }

  testWithMessage((woa != nil && plain != nil),
                  @"both WebServerResources aliases must be present");
  testEquals([woa objectForKey: @"real"], [plain objectForKey: @"real"]);
}

- (void) test_shippedConfDoesNotTriggerApacheOverlapWarning
{
  NSArray *fakes;

  fakes = [[self aliasDirectivesOfShippedConf] valueForKey: @"fake"];
  failIf([fakes count] == 0);
  testWithMessage([IndicesOfShadowedAliasFakes(fakes) count] == 0,
                  @"a single clean inclusion of Apache/SOGo.conf must not raise AH00671");
}

- (void) test_confIncludedTwiceReproducesBug5908Warnings
{
  NSArray *fakes, *twice, *shadowed;

  fakes = [[self aliasDirectivesOfShippedConf] valueForKey: @"fake"];
  twice = [fakes arrayByAddingObjectsFromArray: fakes];
  shadowed = IndicesOfShadowedAliasFakes(twice);
  testWithMessage([shadowed count] == 2,
                  @"only the directives of the second inclusion must be flagged");
  testEquals([shadowed objectAtIndex: 0],
             [NSNumber numberWithUnsignedInteger: [fakes count]]);
  testEquals([shadowed objectAtIndex: 1],
             [NSNumber numberWithUnsignedInteger: [fakes count] + 1]);
}

- (void) test_aliasMatchesComparesWholePathSegmentsOnly
{
  testWithMessage(ApacheAliasMatches("/SOGo/dav/", "/SOGo") > 0,
                  @"an alias must match a complete segment");
  testWithMessage(ApacheAliasMatches("/SOGo.woa/WebServerResources/img/a.png",
                                    "/SOGo") == 0,
                  @"SOGo.woa is a distinct segment, not under /SOGo");
  testWithMessage(ApacheAliasMatches("/SOGo/WebServerResources/img/a.png",
                                     "/SOGo/WebServerResources/") > 0,
                  @"a trailing-slash alias must match its subtree");
}

- (void) test_sogoWebServerResourcesAliasesDoNotOverlapEachOther
{
  testWithMessage(ApacheAliasMatches("/SOGo/WebServerResources/",
                                     "/SOGo.woa/WebServerResources/") == 0,
                  @"the plain prefix must not be shadowed by the .woa one");
  testWithMessage(ApacheAliasMatches("/SOGo.woa/WebServerResources/",
                                     "/SOGo/WebServerResources/") == 0,
                  @"the .woa prefix must not be shadowed by the plain one");
}

@end
