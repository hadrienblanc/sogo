/* TestNGVCardPhoto.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation; either version 2, or (at your option)
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

#import <NGCards/NGVCard.h>
#import <NGCards/NGVCardPhoto.h>

#import "SOGoTest.h"

static BOOL
LoadContactsBundle ()
{
  return [SOGoTest loadSOGoBundle: @"Contacts"
                       markerClass: @"SOGoContactGCSFolder"];
}

@implementation TestNGVCardPhoto : SOGoTest

- (NGVCardPhoto *) _photoOfCard: (NGVCard *) card
{
  return (NGVCardPhoto *)[[card childrenWithTag: @"photo"] lastObject];
}

- (NSString *) _photoCardSource: (NSString *) photoParams
{
  return [NSString stringWithFormat:
                     @"BEGIN:VCARD\n"
                     @"VERSION:3.0\n"
                     @"N:Doe;Jane;;;;\n"
                     @"FN:Jane Doe\n"
                     @"PHOTO;%@:/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a\n"
                     @"HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAQAAAAAAAAAAAAAAAAAAAAAK/9oACAEBAAA/AKQAAP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQIQAD8AVgA//EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQMQAD8AVgA//Z\n"
                     @"END:VCARD\n",
                     photoParams];
}

- (void) test_setPhotoEmitsVCard30Parameters
{
  NGVCard *card;
  NSString *versit;

  testWithMessage (LoadContactsBundle (),
                   @"Contacts bundle could not be loaded");

  card = [NGVCard cardWithUid: @"photo-test"];
  [card setPhoto: @"/9j/4AAQSkZJRgABAQAAAQABAAD"];

  versit = [card versitString];
  test([versit rangeOfString: @"TYPE=JPEG"].location != NSNotFound);
  test([versit rangeOfString: @"ENCODING=b"].location != NSNotFound);
}

- (void) test_generatedPhotoRoundTrips
{
  NGVCard *card, *parsed;
  NGVCardPhoto *photo;
  NSData *decoded;

  testWithMessage (LoadContactsBundle (),
                   @"Contacts bundle could not be loaded");

  card = [NGVCard cardWithUid: @"photo-roundtrip"];
  [card setPhoto: @"/9j/4AAQSkZJRgABAQAAAQABAAD"];

  parsed = [NGVCard parseSingleFromSource: [card versitString]];
  test(parsed != nil);

  photo = [self _photoOfCard: parsed];
  decoded = [photo decodedContent];
  test(decoded != nil);
  test([decoded length] > 0);
}

- (void) test_legacyBase64PhotoStillDecodes
{
  NGVCard *card;
  NGVCardPhoto *photo;

  testWithMessage (LoadContactsBundle (),
                   @"Contacts bundle could not be loaded");

  card = [NGVCard parseSingleFromSource:
                     [self _photoCardSource: @"ENCODING=BASE64"]];
  photo = [self _photoOfCard: card];
  test([photo decodedContent] != nil);
}

- (void) test_newEncodingPhotoDecodes
{
  NGVCard *card;
  NGVCardPhoto *photo;

  testWithMessage (LoadContactsBundle (),
                   @"Contacts bundle could not be loaded");

  card = [NGVCard parseSingleFromSource:
                     [self _photoCardSource: @"TYPE=JPEG;ENCODING=b"]];
  photo = [self _photoOfCard: card];
  test([photo decodedContent] != nil);
}

@end
