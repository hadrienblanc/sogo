/* TestUIxMailRenderingContext.m - this file is part of SOGo
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
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGObjWeb/WOComponent.h>

#import "SOGoTest.h"
#import "UIxMailRenderingContext.h"

@interface TestMailViewerComponent : WOComponent
{
  NSString *requestedPageName;
}

- (NSString *) requestedPageName;

@end

@implementation TestMailViewerComponent

- (WOComponent *) pageWithName: (NSString *) name
{
  if (requestedPageName != name)
    {
      [requestedPageName release];
      requestedPageName = [name retain];
    }

  return self;
}

- (NSString *) requestedPageName
{
  return requestedPageName;
}

- (void) dealloc
{
  [requestedPageName release];
  [super dealloc];
}

@end

@interface TestUIxMailRenderingContext : SOGoTest
{
  TestMailViewerComponent *viewer;
  UIxMailRenderingContext *renderingContext;
}
@end

@implementation TestUIxMailRenderingContext

- (void) setUp
{
  viewer = [[TestMailViewerComponent alloc] init];
  renderingContext = [[UIxMailRenderingContext alloc] initWithViewer: viewer
                                                             context: nil];
}

- (void) tearDown
{
  [renderingContext release];
  [viewer release];
}

- (void) selectViewerForType: (NSString *) type
                     subtype: (NSString *) subtype
                      bodyId: (NSString *) bodyId
{
  NSDictionary *info;

  info = [NSDictionary dictionaryWithObjectsAndKeys:
                     type, @"type",
                   subtype, @"subtype",
                    bodyId, @"bodyId",
                     nil];

  [renderingContext viewerForBodyInfo: info];
}

- (void) test_svgImagesAreNeverRenderedThroughImageViewerOfTicket6152
{
  [self selectViewerForType: @"image" subtype: @"svg+xml" bodyId: nil];
  testEquals ([viewer requestedPageName], @"UIxMailPartLinkViewer");
}

- (void) test_inlineSvgImagesAreRenderedThroughLinkViewerOfTicket6152
{
  [self selectViewerForType: @"image" subtype: @"svg+xml"
                      bodyId: @"<signature-svg@ticket6152>"];
  testEquals ([viewer requestedPageName], @"UIxMailPartLinkViewer");
}

- (void) test_plainImagesAreRenderedThroughImageViewer
{
  [self selectViewerForType: @"image" subtype: @"png" bodyId: nil];
  testEquals ([viewer requestedPageName], @"UIxMailPartImageViewer");
}

@end
