/* NSString+Mail.m - this file is part of SOGo
 *
 * Copyright (C) 2008-2018 Inverse inc.
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

#import <Foundation/NSException.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSValue.h>

#import <SaxObjC/SaxLexicalHandler.h>
#import <SaxObjC/SaxXMLReaderFactory.h>
#import <NGExtensions/NGHashMap.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeFileData.h>

#include <libxml/encoding.h>

#import "NSString+Mail.h"
#import "NSData+Mail.h"
#import "../SOGo/SOGoObject.h"

#define paddingBuffer 8192

#define punycodeBase 36
#define punycodeTMin 1
#define punycodeTMax 26
#define punycodeSkew 38
#define punycodeDamp 700
#define punycodeInitialBias 72
#define punycodeInitialN 128

static NSUInteger
PunycodeAdaptDelta (NSUInteger delta, NSUInteger numpoints, BOOL firsttime)
{
  NSUInteger k;

  delta = firsttime ? (delta / punycodeDamp) : (delta / 2);
  delta += delta / numpoints;
  for (k = 0; delta > ((punycodeBase - punycodeTMin) * punycodeTMax) / 2;
       k += punycodeBase)
    delta /= (punycodeBase - punycodeTMin);

  return k + (((punycodeBase - punycodeTMin + 1) * delta)
              / (delta + punycodeSkew));
}

static NSUInteger
PunycodeDecodeDigit (unichar c)
{
  if (c >= 'A' && c <= 'Z')
    return (c - 'A');
  if (c >= 'a' && c <= 'z')
    return (c - 'a');
  if (c >= '0' && c <= '9')
    return ((c - '0') + 26);

  return NSUIntegerMax;
}

static NSString *
DecodePunycodeLabel (NSString *aceLabel)
{
  NSMutableArray *codePoints;
  NSMutableString *decoded;
  unichar *input;
  NSUInteger inputLength, b, inPos, i, n, bias, k, w, digit, t, oldi, outLength;
  NSUInteger cp, j, count;

  inputLength = [aceLabel length];
  if (inputLength == 0 || inputLength > 63)
    return nil;

  input = NSZoneMalloc (NULL, inputLength * sizeof (unichar));
  [aceLabel getCharacters: input];

  codePoints = [NSMutableArray arrayWithCapacity: inputLength];

  b = 0;
  for (j = 0; j < inputLength; j++)
    if (input[j] == '-')
      b = j;

  for (j = 0; j < b; j++)
    [codePoints addObject: [NSNumber numberWithUnsignedLong: input[j]]];

  n = punycodeInitialN;
  i = 0;
  bias = punycodeInitialBias;
  inPos = (b > 0) ? (b + 1) : 0;

  while (inPos < inputLength)
    {
      oldi = i;
      w = 1;
      for (k = punycodeBase; ; k += punycodeBase)
        {
          if (inPos >= inputLength)
            {
              NSZoneFree (NULL, input);
              return nil;
            }
          digit = PunycodeDecodeDigit (input[inPos++]);
          if (digit == NSUIntegerMax || digit >= punycodeBase)
            {
              NSZoneFree (NULL, input);
              return nil;
            }
          if (digit > (NSUIntegerMax - i) / w)
            {
              NSZoneFree (NULL, input);
              return nil;
            }
          i += digit * w;
          t = (k <= bias) ? punycodeTMin
            : ((k >= bias + punycodeTMax) ? punycodeTMax : (k - bias));
          if (digit < t)
            break;
          if (w > NSUIntegerMax / (punycodeBase - t))
            {
              NSZoneFree (NULL, input);
              return nil;
            }
          w *= (punycodeBase - t);
        }

      outLength = [codePoints count];
      bias = PunycodeAdaptDelta (i - oldi, outLength + 1, (oldi == 0));

      n += i / (outLength + 1);
      i %= (outLength + 1);

      if (n > 0x10FFFF || (n >= 0xD800 && n <= 0xDFFF) || n < 0xA0)
        {
          NSZoneFree (NULL, input);
          return nil;
        }

      [codePoints insertObject: [NSNumber numberWithUnsignedLong: n]
                        atIndex: i];
      i++;
    }

  NSZoneFree (NULL, input);

  decoded = [NSMutableString stringWithCapacity: [codePoints count] + 2];
  count = [codePoints count];
  for (j = 0; j < count; j++)
    {
      cp = [[codePoints objectAtIndex: j] unsignedLongValue];
      if (cp <= 0xFFFF)
        [decoded appendFormat: @"%C", (unichar) cp];
      else
        {
          [decoded appendFormat: @"%C",
            (unichar) (0xD800 + ((cp - 0x10000) >> 10))];
          [decoded appendFormat: @"%C",
            (unichar) (0xDC00 + ((cp - 0x10000) & 0x3FF))];
        }
    }

  return [NSString stringWithString: decoded];
}

static NSString *
DomainByDecodingIDNLabels (NSString *domain)
{
  NSMutableArray *labels;
  NSArray *aceLabels;
  NSString *label, *decodedLabel;
  NSUInteger count, i;
  BOOL changed;

  if (![domain length])
    return nil;

  aceLabels = [domain componentsSeparatedByString: @"."];
  labels = [NSMutableArray arrayWithCapacity: [aceLabels count]];
  changed = NO;

  count = [aceLabels count];
  for (i = 0; i < count; i++)
    {
      label = [aceLabels objectAtIndex: i];
      decodedLabel = nil;
      if ([label length] > 4 && [label hasPrefix: @"xn--"])
        decodedLabel = DecodePunycodeLabel ([label substringFromIndex: 4]);
      if (decodedLabel)
        {
          [labels addObject: decodedLabel];
          changed = YES;
        }
      else
        [labels addObject: label];
    }

  if (!changed)
    return nil;

  return [labels componentsJoinedByString: @"."];
}

@interface _SOGoHTMLContentHandler : NSObject <SaxContentHandler, SaxLexicalHandler>
{
  NSMutableArray *images;

  NSArray *ignoreContentTags;
  NSArray *specialTreatmentTags;
  NSArray *voidTags;

  BOOL ignoreContent;
  BOOL orderedList;
  BOOL unorderedList;
  unsigned int listCount;

  NSMutableString *result;
}

+ (id) htmlToTextContentHandler;
+ (id) sanitizerContentHandler;

- (NSString *) result;

- (void) setIgnoreContentTags: (NSArray *) theTags;
- (void) setSpecialTreatmentTags: (NSArray *) theTags;
- (void) setVoidTags: (NSArray *) theTags;
- (void) setImages: (NSMutableArray *) theImages;

@end

@implementation _SOGoHTMLContentHandler

- (id) init
{
  if ((self = [super init]))
    {
      images = nil;

      ignoreContentTags = nil;
      specialTreatmentTags = nil;
      [ignoreContentTags retain];
      [specialTreatmentTags retain];

      ignoreContent = NO;
      result = nil;

      orderedList = NO;
      unorderedList = NO;
      listCount = 0;
    }

  return self;
}

+ (id) htmlToTextContentHandler
{
  static id htmlToTextContentHandler;

  if (!htmlToTextContentHandler)
    htmlToTextContentHandler = [self new];

  [htmlToTextContentHandler setIgnoreContentTags: [NSArray arrayWithObjects: @"head", @"script",
                                                           @"style", nil]];
  [htmlToTextContentHandler setSpecialTreatmentTags: [NSArray arrayWithObjects: @"p", @"ul", @"ol",
                                                               @"li", @"table", @"tr", @"td", @"th",
                                                               @"br", @"hr", @"dt", @"dd", nil]];

  return htmlToTextContentHandler;
}

+ (id) sanitizerContentHandler
{
  static id sanitizerContentHandler;

  if (!sanitizerContentHandler)
    sanitizerContentHandler = [self new];

  [sanitizerContentHandler setVoidTags: [NSArray arrayWithObjects: @"area", @"base",
                                                 @"basefont", @"br", @"col", @"frame", @"hr",
                                                 @"img", @"input", @"isindex", @"link",
                                                 @"meta", @"param", @"", nil]];

  return sanitizerContentHandler;
}

- (xmlCharEncoding) contentEncoding
{
  return XML_CHAR_ENCODING_UTF8;
}

- (void) dealloc
{
  [ignoreContentTags release];
  [specialTreatmentTags release];
  [result release];
  [super dealloc];
}

- (NSString *) result
{
  NSString *newResult;

  newResult = [NSString stringWithString: result];
  [result release];
  result = nil;

  return newResult;
}

- (void) setIgnoreContentTags: (NSArray *) theTags
{
  ASSIGN(ignoreContentTags, theTags);
}

- (void) setSpecialTreatmentTags: (NSArray *) theTags
{
  ASSIGN(specialTreatmentTags, theTags);
}

- (void) setVoidTags: (NSArray *) theTags
{
  ASSIGN(voidTags, theTags);
}

//
// We MUST NOT retain the array here
//
- (void) setImages: (NSMutableArray *) theImages
{
  images = theImages;
}


/* SaxContentHandler */
- (void) startDocument
{
  [result release];
  result = [NSMutableString new];
  orderedList = NO;
  unorderedList = NO;
  listCount = 0;
}

- (void) endDocument
{
  ignoreContent = NO;
}

- (void) startPrefixMapping: (NSString *) prefix
                        uri: (NSString *) uri
{
}

- (void) endPrefixMapping: (NSString *) prefix
{
}

- (void) _startSpecialTreatment: (NSString *) tagName
{
  if ([tagName isEqualToString: @"br"]
      || [tagName isEqualToString: @"p"])
    [result appendString: @"\n"];
  else if ([tagName isEqualToString: @"hr"])
    [result appendString: @"______________________________________________________________________________\n"];
  else if ([tagName isEqualToString: @"ul"])
    {
      [result appendString: @"\n"];
      unorderedList = YES;
    }
  else if ([tagName isEqualToString: @"ol"])
    {
      [result appendString: @"\n"];
      orderedList = YES;
      listCount = 0;
    }
  else if ([tagName isEqualToString: @"li"])
    {
      if (orderedList)
        {
          listCount++;
          [result appendFormat: @" %d. ", listCount];
        }
      else
        [result appendString: @" * "];
    }
  else if ([tagName isEqualToString: @"dd"])
    [result appendString: @"  "];
}

- (void) _endSpecialTreatment: (NSString *) tagName
{
  if ([tagName isEqualToString: @"ul"])
    {
      [result appendString: @"\n"];
      unorderedList = NO;
    }
  else if ([tagName isEqualToString: @"ol"])
    {
      [result appendString: @"\n"];
      orderedList = NO;
    }
  else if ([tagName isEqualToString: @"dt"])
    {
      [result appendString: @":\n"];
    }
  else if ([tagName isEqualToString: @"li"]
           || [tagName isEqualToString: @"dd"])
    [result appendString: @"\n"];
}

- (void) startElement: (NSString *) element
            namespace: (NSString *) namespace
              rawName: (NSString *) rawName
           attributes: (id <SaxAttributes>) attributes
{
  NSString *tagName;
  BOOL appendElement = YES;

  tagName = [rawName lowercaseString];

  if (!ignoreContent && ignoreContentTags && specialTreatmentTags)
    {
      if ([ignoreContentTags containsObject: tagName])
        ignoreContent = YES;
      else if ([specialTreatmentTags containsObject: tagName])
        [self _startSpecialTreatment: tagName];
    }
  else
    {
      if ([tagName isEqualToString: @"img"])
        {
          NSString *value;

          value = [attributes valueForRawName: @"src"];

          //
          // Check for Data URI Scheme
          //
          // data:[<MIME-type>][;charset=<encoding>][;base64],<data>
          //
          if ([value length] > 5 && [[value substringToIndex: 5] caseInsensitiveCompare: @"data:"] == NSOrderedSame)
            {
              NSString *uniqueId, *mimeType, *encoding, *attrName;
              NGMimeBodyPart *bodyPart;
              NGMutableHashMap *map;
              NSData *data;
              id body;

              int i, j, k, len;

              i = [value indexOf: ';'];
              j = [value indexOf: ';' fromIndex: i+1];
              k = [value indexOf: ','];

              // We try to get the MIME type
              mimeType = nil;

              if (i > 5 && i < k)
                {
                  mimeType = [value substringWithRange: NSMakeRange(5, i-5)];
                }
              else
                i = 5;

              // We might get a stupid value. We discard anything that doesn't have a / in it
              if (mimeType == nil || [mimeType length] == 0
                  || [mimeType indexOf: '/'] < 0)
                mimeType = @"image/jpeg";

              // We check and skip the charset
              if (j < i)
                j = i;

              // We check the encoding and we completely ignore it
              encoding = [value substringWithRange: NSMakeRange(j+1, k-j-1)];

              if (![encoding length])
                encoding = @"base64";

              data = [[value substringFromIndex: k+1] dataUsingEncoding: NSASCIIStringEncoding];
              len = [data length];
              if ([encoding isEqualToString: @"base64"] && len > 72)
                {
                  NSMutableData *folded_data;
                  unsigned char *bytes, c;

                  folded_data = [NSMutableData data];
                  bytes = (unsigned char *)[data bytes];

                  for (i = 0; i < len; i++)
                    {
                      if (i > 0 && i % 72 == 0)
                        {
                          c = '\n';
                          [folded_data appendBytes: &c  length: 1];
                        }

                      c = *bytes; bytes++;
                      [folded_data appendBytes: &c  length: 1];
                    }

                  data = folded_data;
                }

              uniqueId = [SOGoObject globallyUniqueObjectId];

              map = [[[NGMutableHashMap alloc] initWithCapacity: 5] autorelease];
              [map setObject: encoding forKey: @"content-transfer-encoding"];
              [map setObject: [NSString stringWithFormat: @"inline; filename=\"%@\"", uniqueId]  forKey: @"content-disposition"];
              [map setObject: [NSString stringWithFormat: @"%@; name=\"%@\"", mimeType, uniqueId]  forKey: @"content-type"];
              [map setObject: [NSString stringWithFormat: @"<%@>", uniqueId]  forKey: @"content-id"];

              body = [[NGMimeFileData alloc] initWithBytes: [data bytes]  length: [data length]];

              bodyPart = [[[NGMimeBodyPart alloc] initWithHeader:map] autorelease];
              [bodyPart setBody: body];
              [body release];

              [images addObject: bodyPart];

              [result appendFormat: @"<img src=\"cid:%@\" type=\"%@\"", uniqueId, mimeType];

              // Restore img attributes
              for (i = 0; i < [attributes count]; i++)
                {
                  attrName = [[attributes rawNameAtIndex: i] lowercaseString];
                  if (![attrName isEqualToString: @"src"] && ![attrName isEqualToString: @"type"])
                    {
                      value = [attributes valueAtIndex: i];
                      [result appendFormat: @" %@=\"%@\"", attrName, value];
                    }
                }

              [result appendString: @"/>"];

              appendElement = NO;
            }
        }
      if (appendElement && voidTags)
        {
          NSMutableString *value;
          NSString *type;
          int i;

          [result appendString: @"<"];
          [result appendString: rawName];
          for (i = 0; i < [attributes count]; i++)
            {
              [result appendString: @" "];
              value = [NSMutableString stringWithString: [attributes valueAtIndex: i]];
              [value replaceString: @"\\" withString: @"\\\\"];
              [value replaceString: @"\"" withString: @"\\\""];
              [result appendString: [attributes nameAtIndex: i]];
              [result appendString: @"=\""];
              [result appendString: value];
              [result appendString: @"\""];

              type = [attributes typeAtIndex: i];
              if (![type isEqualToString: @"CDATA"])
                {
                  [result appendString: @"["];
                  [result appendString: type];
                  [result appendString: @"]"];
                }
            }
          if ([voidTags containsObject: tagName])
            [result appendString: @"/"];
          [result appendString: @">"];
        }
    }
}

- (void) endElement: (NSString *) element
          namespace: (NSString *) namespace
            rawName: (NSString *) rawName
{
  NSString *tagName;

  if (ignoreContentTags && specialTreatmentTags)
    {
      if (ignoreContent)
        {
          tagName = [rawName lowercaseString];
          if ([ignoreContentTags containsObject: tagName])
            ignoreContent = NO;
          else if ([specialTreatmentTags containsObject: tagName])
            [self _endSpecialTreatment: tagName];
        }
    }
  else if (voidTags)
    {
      tagName = [rawName lowercaseString];
      if (![voidTags containsObject: tagName])
        [result appendFormat: @"</%@>", rawName];
    }
}

- (void) characters: (unichar *) characters
             length: (NSUInteger) length
{
  if (!ignoreContent)
    {
      // Append a text node
      if (ignoreContentTags)
        // We are converting a HTML message to plain text (htmlToTextContentHandler):
        // include the HTML tags in the text
        [result appendString: [NSString stringWithCharacters: characters  length: length]];
      else
        // We are sanitizing an HTML message (sanitizerContentHandler):
        // escape the HTML entitites so they are visible
        [result appendString: [[NSString stringWithCharacters: characters  length: length] stringByEscapingHTMLString]];
    }
}

- (void) ignorableWhitespace: (unichar *) whitespaces
                      length: (NSUInteger) length
{
}

- (void) processingInstruction: (NSString *) pi
                          data: (NSString *) data
{
}

- (void) setDocumentLocator: (id <NSObject, SaxLocator>) locator
{
}

- (void) skippedEntity: (NSString *) entity
{
}

/* SaxLexicalHandler */
- (void) comment: (unichar *) chars
          length: (int) len
{
}

- (void) startDTD: (NSString *) name
         publicId: (NSString *) pub
         systemId: (NSString *) sys
{
}

- (void) endDTD
{
}

- (void) startEntity: (NSString *) entity
{
}

- (void) endEntity: (NSString *) entity
{
}

- (void) startCDATA
{
}

- (void) endCDATA
{
}

@end

@implementation NSString (SOGoExtension)

+ (NSString *) generateMessageID: (NSString *) mailOrDomain
{
  NSMutableString *messageID;
  NSString *_domain;
  NSRange r, cutRange;

  messageID = [NSMutableString string];
  [messageID appendFormat: @"<%@", [SOGoObject mailUniqueMessageId]];
  if(mailOrDomain)
  {
    r = [mailOrDomain rangeOfString: @"@" options: NSBackwardsSearch];
    if (r.location != NSNotFound)
    {
      //Its the full email not a domain
      _domain = [mailOrDomain substringFromIndex: (r.location + r.length)];
    }
    else
      _domain = mailOrDomain;
    _domain = [[_domain componentsSeparatedByString: @">"] objectAtIndex: 0];
    cutRange = [_domain rangeOfCharacterFromSet:
                  [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cutRange.location != NSNotFound)
      _domain = [_domain substringToIndex: cutRange.location];
    if ([_domain length] > 0)
      [messageID appendFormat: @"@%@", _domain];
  }
  [messageID appendString: @">"];

  return [messageID lowercaseString];
}

- (NSString *) htmlToText
{
  _SOGoHTMLContentHandler *handler;
  id <NSObject, SaxXMLReader> parser;
  NSData *d;

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  handler = [_SOGoHTMLContentHandler htmlToTextContentHandler];
  [parser setContentHandler: handler];

  d = [[self dataUsingEncoding: NSUTF8StringEncoding]
                sanitizedContentUsingVoidTags: nil];
  [parser parseFromSource: d];

  return [[handler result] stringByReplacingOccurrencesOfString: @"--\u00A0\n"
                                                      withString: @"-- \n"];
}

- (BOOL) isFullHTMLDocument
{
  NSRange r;

  r = [self rangeOfString: @"<!doctype" options: NSCaseInsensitiveSearch];
  if (r.length == 0)
    r = [self rangeOfString: @"<html" options: NSCaseInsensitiveSearch];

  return (r.length > 0);
}

- (NSString *) htmlByExtractingImages: (NSMutableArray *) theImages
{
  _SOGoHTMLContentHandler *handler;
  id <NSObject, SaxXMLReader> parser;
  NSData *d;

  parser = [[SaxXMLReaderFactory standardXMLReaderFactory]
             createXMLReaderForMimeType: @"text/html"];
  handler = [_SOGoHTMLContentHandler sanitizerContentHandler];
  [handler setImages: theImages];

  [parser setContentHandler: handler];

  d = [self dataUsingEncoding: NSUTF8StringEncoding];
  [parser parseFromSource: d];

  return [handler result];
}

static inline char *
convertChars (const char *oldString, unsigned int oldLength,
              unsigned int *newLength)
{
  const char *currentChar, *upperLimit;
  char *newString, *destChar, *reallocated;
  unsigned int length, maxLength;

  maxLength = oldLength + paddingBuffer;
  newString = NSZoneMalloc (NULL, maxLength + 1);
  destChar = newString;
  currentChar = oldString;

  length = 0;

  upperLimit = oldString + oldLength;
  while (currentChar < upperLimit)
    {
      switch (*currentChar)
        {
        case '\r': break;
        case '\n':
                   length = destChar - newString;
                   if (length + paddingBuffer > maxLength - 6)
                     {
                       maxLength += paddingBuffer;
                       reallocated = NSZoneRealloc (NULL, newString,
                                                    maxLength + 1);
                       if (reallocated)
                         {
                           newString = reallocated;
                           destChar = newString + length;
                         }
                       else
                         [NSException raise: NSMallocException
                                     format: @"reallocation failed in %s",
                           __PRETTY_FUNCTION__];
                     }
                   strcpy (destChar, "<br />");
                   destChar += 6;
                   break;
        default:
                   *destChar = *currentChar;
                   destChar++;
        }
      currentChar++;
    }
  *destChar = 0;
  *newLength = destChar - newString;

  return newString;
}

- (NSString *) stringByConvertingCRLNToHTML
{
  NSString *convertedString;
  const char *utf8String;
  char *newString;
  unsigned int newLength;

  utf8String = [self UTF8String];
  newString = convertChars (utf8String, strlen (utf8String), &newLength);
  convertedString = [[NSString alloc] initWithBytes: newString
                                             length: newLength
                                           encoding: NSUTF8StringEncoding];
  [convertedString autorelease];
  NSZoneFree (NULL, newString);

  return convertedString;
}


- (int) indexOf: (unichar) _c
      fromIndex: (int) start
{
  int i, len;

  len = [self length];

  if (start < 0 || start >= len)
    start = 0;

  for (i = start; i < len; i++)
    {
      if ([self characterAtIndex: i] == _c) return i;
    }

  return -1;

}

- (int) indexOf: (unichar) _c
{
  return [self indexOf: _c fromIndex: 0];
}

- (NSString *) decodedHeader
{
  NSString *decodedHeader;

  decodedHeader = [[self dataUsingEncoding: NSASCIIStringEncoding]
                     decodedHeader];
  if (!decodedHeader)
    decodedHeader = self;

  return decodedHeader;
}

- (NSString *) emailWithDecodedIDNDomain
{
  NSString *localPart, *domain, *decodedDomain;
  NSRange atRange;

  atRange = [self rangeOfString: @"@" options: NSBackwardsSearch];
  if (atRange.location == NSNotFound || atRange.location == 0
      || NSMaxRange (atRange) >= [self length])
    return self;

  localPart = [self substringToIndex: atRange.location];
  domain = [self substringFromIndex: NSMaxRange (atRange)];

  decodedDomain = DomainByDecodingIDNLabels (domain);
  if (!decodedDomain)
    return self;

  return [NSString stringWithFormat: @"%@@%@", localPart, decodedDomain];
}

- (NSString *) asSafeFilename
{
  NSRange r;
  NSMutableString *safeName;

  r = [self rangeOfString: @"\\"
                  options: NSBackwardsSearch];
  if (r.length > 0)
    safeName = [NSMutableString stringWithString: [self substringFromIndex: r.location + 1]];
  else
    safeName = [NSMutableString stringWithString: self];
  [safeName replaceString: @"/" withString: @"_"];

  if ([safeName isEqualToString: @"."])
    return @"_";

  if ([safeName isEqualToString: @".."])
    return @"__";

  return safeName;
}

//
// We might end up here because of MUA that actually strips the
// Content-Disposition (and thus, the filename) when mails containing
// attachments have been forwarded. Thunderbird (2.x) does just that
// when forwarding mails with images attached to them (using cid:...).
//
- (NSString *) asPreferredFilenameUsingPath: (NSString *) thePath
{
  NSString *filename;

  filename = nil;
  if (!thePath)
    thePath = @"1";

  if ([self hasPrefix: @"application/"] ||
      [self hasPrefix: @"audio/"] ||
      [self hasPrefix: @"image/"] ||
      [self hasPrefix: @"video/"])
    {
      filename = [NSString stringWithFormat: @"unknown_%@", thePath];
    }
  else
    {
      if ([self isEqualToString: @"message/rfc822"])
        filename = [NSString stringWithFormat: @"email_%@.eml", thePath];
    }

  return filename;
}
@end
