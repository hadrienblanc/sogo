/* SOGoDraftObjectTestCase.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 2, or (at your option) any
 * later version.
 *
 * This file is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
 * 02110-1301, USA.
 */

#import "SOGoDraftObjectTestCase.h"

#import <NGMime/NGMimeHeaderFieldGenerator.h>

@implementation SOGoDraftObjectTestCase

static Class
LoadDraftClass ()
{
  static Class draftClass = Nil;

  if (!draftClass)
    {
      if (![SOGoTest loadSOGoBundle: @"Contacts"
                          markerClass: @"SOGoDraftObject"])
        [SOGoTest loadSOGoBundle: @"Mailer"
                      markerClass: @"SOGoDraftObject"];
      draftClass = NSClassFromString (@"SOGoDraftObject");
    }

  return draftClass;
}

- (NSString *) draftName
{
  return @"draftObjectTestCase";
}

- (void) setUp
{
  Class draftClass;

  draftClass = LoadDraftClass ();
  testWithMessage (draftClass != Nil,
                   @"SOGoDraftObject class unavailable (Mailer.SOGo bundle missing)");
  if (!draftClass)
    return;

  draft = [[draftClass alloc] initWithName: [self draftName]
                                inContainer: nil];
}

- (void) tearDown
{
  [draft release];
  [super tearDown];
}

- (NSString *) generatedHeaderFor: (NSString *) value
{
  NGMimeAddressHeaderFieldGenerator *generator;

  generator = [NGMimeAddressHeaderFieldGenerator headerFieldGenerator];

  return [[[NSString alloc] initWithData:
              [generator generateDataForHeaderFieldNamed: @"from"
                                                    value: value]
                              encoding: NSASCIIStringEncoding] autorelease];
}

@end
