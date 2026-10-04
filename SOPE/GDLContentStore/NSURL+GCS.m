/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#import "NSURL+GCS.h"

@implementation NSURL(GCS)

- (NSString *) gcsPathComponent: (unsigned) _idx
{
  NSString *p;
  NSArray  *pcs;
  unsigned len;
  
  p = [self path];
  if ([p length] == 0)
    return nil;
  
  pcs = [p componentsSeparatedByString:@"/"];
  if ((len = [pcs count]) == 0)
    return nil;
  if (len <= _idx)
    return  nil;
  return [pcs objectAtIndex:_idx];
}

- (NSString *) gcsDatabaseName
{
  return [self gcsPathComponent: 1];
}

- (NSString *) gcsTableName
{
  return [[self path] lastPathComponent];
}

- (NSString *) gcsURLId
{
  /*
    We need to build a proper key that omits passwords and URL path components
    which are not required.
  */
  return [NSString stringWithFormat: @"%@:%@:%@:%@",
                   [self host], [self port],
                   [self user], [self gcsDatabaseName]];
}

- (NSURL *) gcsURLWithoutCredentials
{
  NSString *urlString, *prefix, *rest;
  NSRange schemeRange, atRange, slashRange;

  urlString = [self absoluteString];
  schemeRange = [urlString rangeOfString: @"://"];
  if (schemeRange.location == NSNotFound)
    return self;

  rest = [urlString substringFromIndex: NSMaxRange (schemeRange)];
  atRange = [rest rangeOfString: @"@"];
  if (atRange.location == NSNotFound)
    return self;

  slashRange = [rest rangeOfString: @"/"];
  if (slashRange.location != NSNotFound
      && slashRange.location < atRange.location)
    return self;

  prefix = [urlString substringToIndex: NSMaxRange (schemeRange)];

  return [NSURL URLWithString:
                   [prefix stringByAppendingString:
                            [rest substringFromIndex: NSMaxRange (atRange)]]];
}

- (NSURL *) gcsURLWithCredentialsFromURL: (NSURL *) _url
{
  NSString *urlString, *credentials, *otherString;
  NSRange schemeRange, atRange, slashRange;

  if (_url == nil || [self user] != nil)
    return self;

  otherString = [_url absoluteString];
  schemeRange = [otherString rangeOfString: @"://"];
  if (schemeRange.location == NSNotFound)
    return self;

  otherString = [otherString substringFromIndex: NSMaxRange (schemeRange)];
  atRange = [otherString rangeOfString: @"@"];
  if (atRange.location == NSNotFound)
    return self;

  slashRange = [otherString rangeOfString: @"/"];
  if (slashRange.location != NSNotFound
      && slashRange.location < atRange.location)
    return self;

  credentials = [otherString substringToIndex: NSMaxRange (atRange)];

  urlString = [self absoluteString];
  schemeRange = [urlString rangeOfString: @"://"];
  if (schemeRange.location == NSNotFound)
    return self;

  return [NSURL URLWithString:
                  [[urlString substringToIndex: NSMaxRange (schemeRange)]
                    stringByAppendingString:
                    [credentials stringByAppendingString:
                              [urlString substringFromIndex:
                                             NSMaxRange (schemeRange)]]]];
}

@end /* NSURL(GCS) */
