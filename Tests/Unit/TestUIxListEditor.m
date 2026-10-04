/* TestUIxListEditor.m - this file is part of SOGo
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGCards/NGVList.h>

#import <Contacts/UIxListEditor.h>

#import "SOGoTest.h"

__attribute__((weak)) char __objc_class_name_SOGoContactGCSEntry = 0;
__attribute__((weak)) char __objc_class_name_SOGoContactSourceFolder = 0;

@interface UIxListEditor (Test6065Attributes)
- (void) setAttributes: (NSDictionary *) attributes;
@end

@interface Test6065ListEditor : UIxListEditor
@end

@implementation Test6065ListEditor

- (NGVList *) testList
{
  return list;
}

- (void) setTestList: (NGVList *) newList
{
  [newList retain];
  [list release];
  list = newList;
}

@end

@interface TestUIxListEditor : SOGoTest
@end

@implementation TestUIxListEditor

- (Test6065ListEditor *) _editorWithNewList
{
  Test6065ListEditor *editor;
  NGVList *list;

  testWithMessage ([SOGoTest loadSOGoBundle: @"Contacts"
                                 markerClass: @"SOGoContactGCSFolder"],
                   @"Contacts bundle could not be loaded");

  editor = [[[Test6065ListEditor alloc] init] autorelease];
  list = [[[NGVList alloc] initWithUid: @"list-uid"] autorelease];
  [editor setTestList: list];

  return editor;
}

- (void) test_setAttributesKeepsDisplayWhenProvided
{
  Test6065ListEditor *editor;
  NGVList *list;

  editor = [self _editorWithNewList];
  list = [editor testList];

  [editor setAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"Sales Team", @"c_cn",
                                     @"sales", @"nickname",
                                     @"quarterly review", @"description",
                                     nil]];

  testEquals([list fn], @"Sales Team");
  testEquals([list nickname], @"sales");
  testEquals([list description], @"quarterly review");
}

- (void) test_setAttributesFallsBackToNicknameWhenDisplayIsMissing
{
  Test6065ListEditor *editor;
  NGVList *list;

  editor = [self _editorWithNewList];
  list = [editor testList];

  [editor setAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"sales", @"nickname",
                                     @"quarterly review", @"description",
                                     nil]];

  testEquals([list fn], @"sales");
  testEquals([list nickname], @"sales");
  testEquals([list description], @"quarterly review");
}

- (void) test_setAttributesFallsBackToNicknameWhenDisplayIsEmpty
{
  Test6065ListEditor *editor;
  NGVList *list;

  editor = [self _editorWithNewList];
  list = [editor testList];

  [editor setAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"", @"c_cn",
                                     @"sales", @"nickname",
                                     nil]];

  testEquals([list fn], @"sales");
  testEquals([list nickname], @"sales");
}

- (void) test_setAttributesWithoutDisplayOrNicknameKeepsFnEmpty
{
  Test6065ListEditor *editor;
  NGVList *list;

  editor = [self _editorWithNewList];
  list = [editor testList];

  [editor setAttributes: [NSDictionary dictionaryWithObject: @"quarterly review"
                                                     forKey: @"description"]];

  test([[list fn] length] == 0);
  testEquals([list description], @"quarterly review");
}

@end
