#import <NGCards/CardGroup.h>
#import <NGCards/iCalCalendar.h>

#import "SOGoTest.h"

@interface TestNGCardsGeo : SOGoTest
@end

@implementation TestNGCardsGeo

- (void) test_geoSemicolonIsNotEscapedInVEvent
{
  iCalCalendar *calendar;
  CardElement *geo;

  calendar = [iCalCalendar parseSingleFromSource:
                          @"BEGIN:VCALENDAR\r\n"
                          @"VERSION:2.0\r\n"
                          @"BEGIN:VEVENT\r\n"
                          @"UID:976b018163d80262041d461dc6907e3a\r\n"
                          @"SUMMARY:ALEF Security TALK 2018\r\n"
                          @"GEO:49.21442;16.5614485\r\n"
                          @"END:VEVENT\r\n"
                          @"END:VCALENDAR\r\n"];
  geo = [[[calendar events] objectAtIndex: 0] firstChildWithTag: @"geo"];
  testEquals([geo versitString], @"GEO:49.21442;16.5614485");
  testEquals([geo flattenedValueAtIndex: 0 forKey: @""], @"49.21442");
  testEquals([geo flattenedValueAtIndex: 1 forKey: @""], @"16.5614485");
}

- (void) test_geoSemicolonIsNotEscapedInVCard
{
  CardGroup *card;
  CardElement *geo;
  NSString *versit;

  versit = @"BEGIN:VCARD\r\n"
           @"VERSION:3.0\r\n"
           @"N:Doe;John\r\n"
           @"ADR:;;Street 1;City;;12345;Country\r\n"
           @"GEO:37.386013;-122.082932\r\n"
           @"END:VCARD";
  card = [CardGroup parseSingleFromSource: versit];
  testEquals([card versitString], versit);
  geo = [card firstChildWithTag: @"geo"];
  testEquals([geo versitString], @"GEO:37.386013;-122.082932");
  testEquals([geo flattenedValueAtIndex: 0 forKey: @""], @"37.386013");
  testEquals([geo flattenedValueAtIndex: 1 forKey: @""], @"-122.082932");
}

- (void) test_semicolonSeparatorsArePreservedInMultiValuedFields
{
  CardGroup *card;
  CardElement *element;
  NSString *versit;

  versit = @"BEGIN:VCARD\r\n"
           @"N:Last;First;Middle;Prefix;Suffix\r\n"
           @"ADR:PO Box;Ext;Street;City;State;Zip;Country\r\n"
           @"END:VCARD";
  card = [CardGroup parseSingleFromSource: versit];
  testEquals([card versitString], versit);
  element = [card firstChildWithTag: @"n"];
  testEquals([element versitString], @"N:Last;First;Middle;Prefix;Suffix");
  element = [card firstChildWithTag: @"adr"];
  testEquals([element versitString], @"ADR:PO Box;Ext;Street;City;State;Zip;Country");
}

- (void) test_escapedSemicolonIsPreservedInSingleValuedField
{
  CardGroup *card;
  CardElement *element;
  NSString *versit;

  versit = @"BEGIN:VCARD\r\n"
           @"NOTE:remarks\\; with a literal semicolon\r\n"
           @"END:VCARD";
  card = [CardGroup parseSingleFromSource: versit];
  testEquals([card versitString], versit);
  element = [card firstChildWithTag: @"note"];
  testEquals([element flattenedValueAtIndex: 0 forKey: @""],
             @"remarks; with a literal semicolon");
}

@end
