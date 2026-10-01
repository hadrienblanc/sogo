/* SaxXMLReaderFactory+SOGoTests.m - this file is part of $PROJECT_NAME_HERE$
 *
 * Copyright (C) 2011 Inverse inc
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSProcessInfo.h>

#import <SaxObjC/SaxXMLReaderFactory.h>

@interface SaxXMLReaderFactory (SOGoTests)

- (NSArray *) saxReaderSearchPathes;

@end

@implementation SaxXMLReaderFactory (SOGoTests)

- (NSArray *) saxReaderSearchPathes
{
  NSMutableArray *pathes;
  NSArray *args, *libraryPaths;
  NSString *exedir, *libraryPath;
  NSUInteger i;

  args = [[NSProcessInfo processInfo] arguments];
  exedir = [[args objectAtIndex: 0] stringByDeletingLastPathComponent];
  pathes = [NSMutableArray arrayWithObject:
                       [NSString stringWithFormat: @"%@/%@",
                                 exedir,
                                 @"../../../SOPE/NGCards/versitCardsSaxDriver/"]];

  libraryPaths = NSStandardLibraryPaths();
  for (i = 0; i < [libraryPaths count]; i++)
    {
      libraryPath = [[libraryPaths objectAtIndex: i]
                             stringByAppendingPathComponent: @"SaxDrivers-4.9"];
      if (![pathes containsObject: libraryPath])
        [pathes addObject: libraryPath];
    }

  return pathes;
}

@end
