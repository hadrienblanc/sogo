/* TestMailerSortListLocalization.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any
 * later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import "SOGoTest.h"

@interface TestMailerSortListLocalization : SOGoTest
@end

@implementation TestMailerSortListLocalization

- (NSString *) contentOfFile: (NSString *) relativePath
{
  NSString *path, *content, *message;

  path = [@"../../" stringByAppendingString: relativePath];
  message = [NSString stringWithFormat: @"%@ must be readable as UTF-8", path];
  content = [NSString stringWithContentsOfFile: path
                                      encoding: NSUTF8StringEncoding
                                         error: NULL];
  testWithMessage(content != nil, message);

  return content;
}

- (NSString *) localizedValueOfKey: (NSString *) key
                         inLanguage: (NSString *) language
{
  NSString *content, *needle, *message, *value;
  NSRange keyRange, valueRange;
  NSUInteger start, max, i;

  content = [self contentOfFile: [NSString stringWithFormat: @"UI/MailerUI/%@.lproj/Localizable.strings", language]];
  needle = [NSString stringWithFormat: @"\"%@\"", key];
  keyRange = [content rangeOfString: needle];
  message = [NSString stringWithFormat: @"%@ must define \"%@\"", language, key];
  testWithMessage(keyRange.location != NSNotFound, message);

  start = NSMaxRange(keyRange);
  max = [content length];
  while (start < max
         && ([content characterAtIndex: start] == ' '
             || [content characterAtIndex: start] == '\t'))
    start++;
  message = [NSString stringWithFormat: @"%@ must assign a value to \"%@\"", language, key];
  testWithMessage(start < max && [content characterAtIndex: start] == '=', message);
  start++;
  while (start < max
         && ([content characterAtIndex: start] == ' '
             || [content characterAtIndex: start] == '\t'))
    start++;
  message = [NSString stringWithFormat: @"%@ must quote the value of \"%@\"", language, key];
  testWithMessage(start < max && [content characterAtIndex: start] == '"', message);
  start++;

  valueRange = [content rangeOfString: @"\""
                              options: 0
                                range: NSMakeRange(start, max - start)];
  message = [NSString stringWithFormat: @"%@ must close the value of \"%@\"", language, key];
  testWithMessage(valueRange.location != NSNotFound, message);

  value = [content substringWithRange: NSMakeRange(start, valueRange.location - start)];

  return value;
}

- (NSArray *) sortMenuFields
{
  NSString *template, *field, *message;
  NSMutableArray *fields;
  NSRange searchRange, callRange, closingRange;

  template = [self contentOfFile: @"UI/Templates/MailerUI/UIxMailFolderTemplate.wox"];
  fields = [NSMutableArray array];
  searchRange = NSMakeRange(0, [template length]);
  callRange = [template rangeOfString: @"mailbox.sort('" options: 0 range: searchRange];
  while (callRange.location != NSNotFound)
    {
      closingRange = [template rangeOfString: @"')"
                                     options: 0
                                       range: NSMakeRange(NSMaxRange(callRange), [template length] - NSMaxRange(callRange))];
      message = @"every mailbox.sort('...') call must be closed in the template";
      testWithMessage(closingRange.location != NSNotFound, message);
      field = [template substringWithRange: NSMakeRange(NSMaxRange(callRange), closingRange.location - NSMaxRange(callRange))];
      if (![fields containsObject: field])
        [fields addObject: field];
      searchRange = NSMakeRange(NSMaxRange(closingRange), [template length] - NSMaxRange(closingRange));
      callRange = [template rangeOfString: @"mailbox.sort('" options: 0 range: searchRange];
    }
  message = @"the sort menu must still offer its criteria";
  testWithMessage([fields count] >= 5, message);

  return fields;
}

- (void) test_sortLabelsCoverEverySortMenuField
{
  NSString *source, *entry, *message;
  NSEnumerator *e;
  NSString *field;

  source = [self contentOfFile: @"UI/WebServerResources/js/Mailer/MailboxController.js"];
  e = [[self sortMenuFields] objectEnumerator];
  while ((field = [e nextObject]))
    {
      entry = [NSString stringWithFormat: @"%@: '", field];
      message = [NSString stringWithFormat: @"sortLabels must map '%@' or the active-sort chip stays empty", field];
      testWithMessage([source rangeOfString: entry].location != NSNotFound, message);
    }
}

- (void) test_sortLabelsBundleShipsTheToEntry
{
  NSString *bundle;

  bundle = [self contentOfFile: @"UI/WebServerResources/js/Mailer.services.js"];
  testWithMessage([bundle rangeOfString: @"to:\"To\""].location != NSNotFound,
                  @"the shipped bundle must carry the 'to' entry of sortLabels (bug 6044)");
}

- (void) test_orderReceivedTranslations
{
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"German"], @"Empfangsreihenfolge");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"French"], @"Ordre de réception");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"SpanishSpain"], @"Orden de recepción");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"SpanishArgentina"], @"Orden de recepción");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Catalan"], @"Ordre de recepció");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Galician"], @"Orde de recepción");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Italian"], @"Ordine di ricezione");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Portuguese"], @"Ordem de receção");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"BrazilianPortuguese"], @"Ordem de recebimento");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Dutch"], @"Volgorde van ontvangst");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Danish"], @"Modtagelsesrækkefølge");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Swedish"], @"Mottagningsordning");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"NorwegianBokmal"], @"Mottaksrekkefølge");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Finnish"], @"Vastaanottojärjestys");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Polish"], @"Kolejność odbioru");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Hungarian"], @"Beérkezés sorrendje");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Bulgarian"], @"Ред на получаване");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Ukrainian"], @"Порядок отримання");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Serbian"], @"Редослед пријема");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"SerbianLatin"], @"Redoslijed prijema");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Montenegrin"], @"Redoslijed prijema");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Bosnian"], @"Redoslijed primitka");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Slovenian"], @"Vrstni red prejema");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Lithuanian"], @"Gavimo tvarka");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Latvian"], @"Saņemšanas secība");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"ChineseChina"], @"接收顺序");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Indonesian"], @"Urutan penerimaan");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Thai"], @"เรียงตามลำดับที่ได้รับ");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"TurkishTurkey"], @"Alınma sırası");
  testEquals([self localizedValueOfKey: @"Order Received" inLanguage: @"Kazakh"], @"Қабылдау реті");
}

- (void) test_descendingOrderTranslations
{
  testEquals([self localizedValueOfKey: @"Descending Order" inLanguage: @"SpanishArgentina"], @"Orden descendente");
  testEquals([self localizedValueOfKey: @"Descending Order" inLanguage: @"Indonesian"], @"Urutan menurun");
  testEquals([self localizedValueOfKey: @"Descending Order" inLanguage: @"Bulgarian"], @"Низходящ ред");
}

- (void) test_orderReceivedStaysADistinctCriterion
{
  NSString *frenchOrder, *frenchDate, *message;

  frenchOrder = [self localizedValueOfKey: @"Order Received" inLanguage: @"French"];
  frenchDate = [self localizedValueOfKey: @"Date" inLanguage: @"French"];
  message = @"French 'Order Received' must not collide with the 'Date' criterion";
  testWithMessage(![frenchOrder isEqualToString: frenchDate], message);
}

@end
