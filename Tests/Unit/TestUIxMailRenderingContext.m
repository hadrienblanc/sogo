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

- (void) selectNonRootRelatedViewerForType: (NSString *) type
                                   subtype: (NSString *) subtype
{
  NSDictionary *info;

  info = [NSDictionary dictionaryWithObjectsAndKeys:
                     type, @"type",
                   subtype, @"subtype",
                     nil];

  [renderingContext viewerForNonRootRelatedBodyInfo: info];
}

- (NSDictionary *) relatedInfoWithStart: (NSString *) start
                             childBodyIds: (NSArray *) childBodyIds
{
  NSMutableArray *parts;
  NSString *bodyId;
  NSUInteger i, max;

  parts = [NSMutableArray arrayWithCapacity: [childBodyIds count]];
  max = [childBodyIds count];
  for (i = 0; i < max; i++)
    {
      bodyId = [childBodyIds objectAtIndex: i];
      [parts addObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"text", @"type",
                                   @"html", @"subtype",
                                   bodyId, @"bodyId",
                                    nil]];
    }

  return [NSDictionary dictionaryWithObjectsAndKeys:
                    @"multipart", @"type",
                  @"related", @"subtype",
      [NSDictionary dictionaryWithObject: (start ? (id)start : (id)@"")
                                forKey: @"start"],
                   @"parameterList",
                              parts, @"parts",
                               nil];
}

- (void) test_rootPartOfRelatedWithoutStartIsFirstPartOfTicket6240
{
  NSDictionary *info;

  info = [self relatedInfoWithStart: nil
                       childBodyIds: [NSArray arrayWithObjects: @"", @"<resource>", nil]];
  test ([renderingContext rootPartIndexOfRelatedBodyInfo: info] == 0);
}

- (void) test_rootPartOfRelatedWithStartMatchesContentIdOfTicket6240
{
  NSDictionary *info;

  info = [self relatedInfoWithStart: @"<resource>"
                       childBodyIds: [NSArray arrayWithObjects: @"", @"<resource>", nil]];
  test ([renderingContext rootPartIndexOfRelatedBodyInfo: info] == 1);
}

- (void) test_rootPartOfRelatedWithBracketlessStartMatchesContentId
{
  NSDictionary *info;

  info = [self relatedInfoWithStart: @"resource"
                       childBodyIds: [NSArray arrayWithObjects: @"", @"<resource>", nil]];
  test ([renderingContext rootPartIndexOfRelatedBodyInfo: info] == 1);
}

- (void) test_rootPartOfRelatedWithUnknownStartFallsBackToFirstPart
{
  NSDictionary *info;

  info = [self relatedInfoWithStart: @"<unknown>"
                       childBodyIds: [NSArray arrayWithObjects: @"", @"<resource>", nil]];
  test ([renderingContext rootPartIndexOfRelatedBodyInfo: info] == 0);
}

- (void) test_rootPartOfEmptyRelatedIsFirstPart
{
  test ([renderingContext rootPartIndexOfRelatedBodyInfo:
          [self relatedInfoWithStart: @"<resource>" childBodyIds: [NSArray array]]] == 0);
}

- (void) test_rootTextPartsOfRelatedKeepTheirViewer
{
  [self selectViewerForType: @"text" subtype: @"html" bodyId: nil];
  testEquals ([viewer requestedPageName], @"UIxMailPartHTMLViewer");

  [self selectViewerForType: @"text" subtype: @"plain" bodyId: nil];
  testEquals ([viewer requestedPageName], @"UIxMailPartTextViewer");
}

- (void) test_nonRootInlineHtmlOfRelatedIsRenderedAsAttachmentOfTicket6240
{
  [self selectNonRootRelatedViewerForType: @"text" subtype: @"html"];
  testEquals ([viewer requestedPageName], @"UIxMailPartLinkViewer");
}

- (void) test_nonRootPlainTextOfRelatedIsRenderedAsAttachment
{
  [self selectNonRootRelatedViewerForType: @"text" subtype: @"plain"];
  testEquals ([viewer requestedPageName], @"UIxMailPartLinkViewer");
}

- (void) test_nonRootNonTextPartsOfRelatedKeepTheirViewer
{
  [self selectNonRootRelatedViewerForType: @"image" subtype: @"png"];
  testEquals ([viewer requestedPageName], @"UIxMailPartImageViewer");

  [self selectNonRootRelatedViewerForType: @"multipart" subtype: @"alternative"];
  testEquals ([viewer requestedPageName], @"UIxMailPartAlternativeViewer");
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
