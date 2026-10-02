/* TestSOGoMailForward.m - this file is part of SOGo
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
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#import "SOGoTest.h"

#define FORWARD_CLASS_NAME @"SOGoMailEnglishForward"

static NSString *TicketMsgID = @"<dudpr@imb11375a27a6d84913ed336c9e2eb74a@dudpr@imb11375.eurprddl.prod.gelabs.com>";
static NSString *TicketMsgIDEscaped = @"&lt;dudpr@imb11375a27a6d84913ed336c9e2eb74a@dudpr@imb11375.eurprddl.prod.gelabs.com&gt;";

@interface TestSOGoMailForwardSourceMail : NSObject
{
  NSString *subject;
  NSDictionary *mailHeaders;
}

- (id) initWithSubject: (NSString *) newSubject
           mailHeaders: (NSDictionary *) newMailHeaders;

@end

@implementation TestSOGoMailForwardSourceMail

- (id) initWithSubject: (NSString *) newSubject
           mailHeaders: (NSDictionary *) newMailHeaders
{
  if ((self = [super init]))
    {
      subject = [newSubject retain];
      mailHeaders = [newMailHeaders retain];
    }

  return self;
}

- (void) dealloc
{
  [subject release];
  [mailHeaders release];
  [super dealloc];
}

- (NSString *) decodedSubject
{
  return subject;
}

- (NSDictionary *) mailHeaders
{
  return mailHeaders;
}

@end

@interface TestSOGoMailForward : SOGoTest
{
  Class forwardClass;
}

@end

@implementation TestSOGoMailForward

- (void) setUp
{
  if (!forwardClass)
    {
      if (![SOGoTest loadSOGoBundle: @"Contacts"
                          markerClass: FORWARD_CLASS_NAME])
        [SOGoTest loadSOGoBundle: @"Mailer"
                      markerClass: FORWARD_CLASS_NAME];
      forwardClass = NSClassFromString (FORWARD_CLASS_NAME);
    }

  testWithMessage (forwardClass != Nil,
                   @"SOGoMailEnglishForward class unavailable (Mailer.SOGo bundle missing)");
}

- (id) _pageWithSubject: (NSString *) aSubject
            mailHeaders: (NSDictionary *) headers
                 isHTML: (BOOL) isHTML
{
  id page, mail;

  mail = [[TestSOGoMailForwardSourceMail alloc] initWithSubject: aSubject
                                                    mailHeaders: headers];
  page = [[forwardClass alloc] init];
  [page setValue: mail forKey: @"sourceMail"];
  [mail release];
  [page setValue: [NSNumber numberWithBool: isHTML] forKey: @"htmlComposition"];

  return [page autorelease];
}

- (void) test_htmlCompositionEscapesSubject
{
  id page;
  NSString *value;

  page = [self _pageWithSubject: @"WG: <Testinhalt> 6186"
                    mailHeaders: nil
                         isHTML: YES];
  value = [page performSelector: @selector(subject)];
  testEquals (@"WG: &lt;Testinhalt&gt; 6186", value);
}

- (void) test_textCompositionKeepsSubject
{
  id page;
  NSString *value;

  page = [self _pageWithSubject: @"WG: <Testinhalt> 6186"
                    mailHeaders: nil
                         isHTML: NO];
  value = [page performSelector: @selector(subject)];
  testEquals (@"WG: <Testinhalt> 6186", value);
}

- (void) test_missingSubjectYieldsNoValue
{
  id page;

  page = [self _pageWithSubject: nil
                    mailHeaders: nil
                         isHTML: YES];
  test ([page performSelector: @selector(subject)] == nil);
}

- (void) test_htmlCompositionEscapesReferences
{
  id page;
  NSDictionary *headers;

  headers = [NSDictionary dictionaryWithObject: TicketMsgID
                                       forKey: @"references"];
  page = [self _pageWithSubject: @"test 6186"
                    mailHeaders: headers
                         isHTML: YES];
  testEquals (([NSString stringWithFormat: @"%@<br/>", TicketMsgIDEscaped]),
              [page performSelector: @selector(references)]);
}

- (void) test_textCompositionKeepsReferences
{
  id page;
  NSDictionary *headers;

  headers = [NSDictionary dictionaryWithObject: TicketMsgID
                                       forKey: @"references"];
  page = [self _pageWithSubject: @"test 6186"
                    mailHeaders: headers
                         isHTML: NO];
  testEquals (([NSString stringWithFormat: @"%@\n", TicketMsgID]),
              [page performSelector: @selector(references)]);
}

- (void) test_htmlCompositionEscapesOrganization
{
  id page;
  NSDictionary *headers;

  headers = [NSDictionary dictionaryWithObject: @"ACME <inc>"
                                       forKey: @"organization"];
  page = [self _pageWithSubject: @"test 6186"
                    mailHeaders: headers
                         isHTML: YES];
  testEquals (@"ACME &lt;inc&gt;<br/>",
              [page performSelector: @selector(organization)]);
}

- (void) test_htmlCompositionEscapesNewsgroups
{
  id page;
  NSDictionary *headers;

  headers = [NSDictionary dictionaryWithObject: @"comp.lang.<objc>"
                                       forKey: @"newsgroups"];
  page = [self _pageWithSubject: @"test 6186"
                    mailHeaders: headers
                         isHTML: YES];
  testEquals (@"comp.lang.&lt;objc&gt;<br/>",
              [page performSelector: @selector(newsgroups)]);
}

- (void) test_htmlCompositionEscapesAddresses
{
  id page;
  NSDictionary *headers;

  headers = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"Brwa Baban <brwa.baban@bearingpoint.com>", @"from",
                          [NSArray arrayWithObject: @"admin3 <sogo-tests1@example.org>"], @"to",
                          [NSArray arrayWithObjects: @"a <a@example.org>",
                            @"b <b@example.org>", nil], @"cc",
                          @"list <list@example.org>", @"reply-to",
                          nil];
  page = [self _pageWithSubject: @"test 6186"
                    mailHeaders: headers
                         isHTML: YES];
  testEquals (@"Brwa Baban &lt;brwa.baban@bearingpoint.com&gt;",
              [page performSelector: @selector(from)]);
  testEquals (@"admin3 &lt;sogo-tests1@example.org&gt;",
              [page performSelector: @selector(to)]);
  testEquals (@"a &lt;a@example.org&gt;, b &lt;b@example.org&gt;<br/>",
              [page performSelector: @selector(cc)]);
  testEquals (@"list &lt;list@example.org&gt;<br/>",
              [page performSelector: @selector(replyTo)]);
}

- (void) test_textCompositionKeepsAddresses
{
  id page;
  NSDictionary *headers;

  headers = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"Brwa Baban <brwa.baban@bearingpoint.com>", @"from",
                          [NSArray arrayWithObject: @"admin3 <sogo-tests1@example.org>"], @"cc",
                          nil];
  page = [self _pageWithSubject: @"test 6186"
                    mailHeaders: headers
                         isHTML: NO];
  testEquals (@"Brwa Baban <brwa.baban@bearingpoint.com>",
              [page performSelector: @selector(from)]);
  testEquals (@"admin3 <sogo-tests1@example.org>\n",
              [page performSelector: @selector(cc)]);
}

@end
