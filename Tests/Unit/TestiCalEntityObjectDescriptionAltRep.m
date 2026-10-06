/* TestiCalEntityObjectDescriptionAltRep.m - this file is part of SOGo
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

#import <NGCards/CardElement.h>
#import <NGCards/iCalCalendar.h>
#import <NGCards/iCalEvent.h>

#import "SOGoTest.h"

@interface TestiCalEntityObjectDescriptionAltRep : SOGoTest
@end

@implementation TestiCalEntityObjectDescriptionAltRep

- (iCalEvent *) _eventWithDescriptionLine: (NSString *) descriptionLine
{
  iCalCalendar *calendar;

  calendar = [iCalCalendar parseSingleFromSource:
                        [NSString stringWithFormat:
                                      @"BEGIN:VCALENDAR\r\n"
                                      @"VERSION:2.0\r\n"
                                      @"BEGIN:VEVENT\r\n"
                                      @"UID:test-5851\r\n"
                                      @"SUMMARY:test 5851\r\n"
                                      @"DTSTART:20261015T100000Z\r\n"
                                      @"DTEND:20261015T110000Z\r\n"
                                      @"%@\r\n"
                                      @"END:VEVENT\r\n"
                                      @"END:VCALENDAR\r\n",
                                      descriptionLine]];
  testWithMessage (calendar != nil, @"could not parse iCalendar content");

  return [[calendar events] objectAtIndex: 0];
}

- (void) test_altrepDroppedWhenDescriptionChanges
{
  iCalEvent *event;
  CardElement *description;

  event = [self _eventWithDescriptionLine:
                      @"DESCRIPTION;ALTREP=\"data:text/html,%3Cbody%3EThunderbirdEdit%3C%2Fbody%3E\":ThunderbirdEdit"];
  description = [event uniqueChildWithTag: @"description"];

  testEquals ([event comment], @"ThunderbirdEdit");
  [event setComment: @"SogoEdit"];
  testEquals ([event comment], @"SogoEdit");
  testEquals ([description versitString], @"DESCRIPTION:SogoEdit");
}

- (void) test_altrepKeptWhenDescriptionUnchanged
{
  iCalEvent *event;
  CardElement *description;

  event = [self _eventWithDescriptionLine:
                      @"DESCRIPTION;ALTREP=\"data:text/html,%3Cx%3E\":TBEdit"];
  description = [event uniqueChildWithTag: @"description"];

  [event setComment: @"TBEdit"];
  testEquals ([description versitString],
              @"DESCRIPTION;ALTREP=\"data:text/html,%3Cx%3E\":TBEdit");
}

- (void) test_otherParametersKeptWhenDescriptionChanges
{
  iCalEvent *event;
  CardElement *description;

  event = [self _eventWithDescriptionLine:
                      @"DESCRIPTION;LANGUAGE=de;ALTREP=\"data:text/html,%3Cp%3EText%3C%2Fp%3E\":Text"];
  description = [event uniqueChildWithTag: @"description"];

  [event setComment: @"Neuer Text"];
  testEquals ([description versitString], @"DESCRIPTION;LANGUAGE=de:Neuer Text");
}

- (void) test_removeAttributeIsCaseInsensitive
{
  CardElement *element;

  element = [CardElement elementWithTag: @"description"];
  [element setSingleValue: @"v" forKey: @""];
  [element addAttribute: @"AltRep" value: @"data:text/html,x"];
  [element addAttribute: @"language" value: @"de"];
  [element removeAttribute: @"ALTREP"];
  testEquals ([element versitString], @"DESCRIPTION;LANGUAGE=de:v");
}

@end
