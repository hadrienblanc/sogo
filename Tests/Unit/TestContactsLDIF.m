#import "SOGoTest.h"

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSTimeZone.h>

#import <NGCards/CardElement.h>
#import <NGCards/NGVCard.h>

#import <NGExtensions/NGBase64Coding.h>

#import <SOGo/SOGoDateFormatter.h>

#import "NGVCard+SOGo.h"
#import "NSDictionary+LDIF.h"
#import "NSString+LDIF.h"

@interface TestContactsLDIF : SOGoTest
@end

@implementation TestContactsLDIF

- (NGVCard *) _cardFromString: (NSString *) vcardString
{
  NGVCard *card;

  card = [NGVCard parseSingleFromSource: vcardString];
  test(card != nil);

  return card;
}

- (void) test_must_encode_ldif_value_edges
{
  test(![@"" mustEncodeLDIFValue]);
  test(![@"plain" mustEncodeLDIFValue]);
  test(![@"col:on" mustEncodeLDIFValue]);
  test(![@"a b" mustEncodeLDIFValue]);
  test(![@"trail " mustEncodeLDIFValue]);
  test([@" lead" mustEncodeLDIFValue]);
  test([@"<lt" mustEncodeLDIFValue]);
  test([@"\n" mustEncodeLDIFValue]);
  test([@"a\nb" mustEncodeLDIFValue]);
  test([[NSString stringWithUTF8String: "é"] mustEncodeLDIFValue]);
}

- (void) test_ldif_record_as_string
{
  NSDictionary *record;
  NSString *ldif, *expected;
  NSArray *lines;

  record = [NSDictionary dictionaryWithObjectsAndKeys:
                         @"cn=jdoe", @"dn",
                         [NSArray arrayWithObjects: @"top", @"person", nil],
                         @"objectClass",
                         @"extra", @"objectClassExtra",
                         @"John Doe", @"cn",
                         [NSArray arrayWithObjects: @"a@x.y", @"b@x.y", nil],
                         @"mail",
                         [NSNumber numberWithInt: 3], @"counter",
                         @"", @"empty",
                         [NSString stringWithUTF8String: "é\n"], @"note",
                         nil];
  ldif = [record ldifRecordAsString];
  lines = [ldif componentsSeparatedByString: @"\n"];

  testEquals([lines objectAtIndex: 0], @"dn: cn=jdoe");
  testEquals([lines objectAtIndex: 1], @"objectClass: top");
  testEquals([lines objectAtIndex: 2], @"objectClass: person");
  test([ldif rangeOfString: @"objectClassExtra"].location == NSNotFound);
  test([ldif rangeOfString: @"counter"].location == NSNotFound);
  test([ldif rangeOfString: @"empty"].location == NSNotFound);
  test([ldif rangeOfString: @"mail: a@x.y\n"].location != NSNotFound);
  test([ldif rangeOfString: @"mail: b@x.y\n"].location != NSNotFound);
  test([ldif rangeOfString: @"cn: John Doe\n"].location != NSNotFound);
  expected = [[NSString stringWithUTF8String: "é\n"] stringByEncodingBase64];
  test(([ldif rangeOfString: [NSString stringWithFormat: @"note:: %@\n", expected]].location != NSNotFound));

  record = [NSDictionary dictionaryWithObjectsAndKeys:
                         @"cn=jdoe", @"dn",
                         @"person", @"objectClass",
                         nil];
  testEquals([record ldifRecordAsString], @"dn: cn=jdoe\nobjectClass: person\n");

  testEquals([[NSDictionary dictionary] ldifRecordAsString], @"");
}

- (void) test_as_ldif_record_rich_card
{
  NGVCard *card;
  NSDictionary *record;
  NSString *given, *displayName;

  given = [NSString stringWithUTF8String: "Prénom"];
  displayName = [NSString stringWithUTF8String: "Prénom Nom"];
  card = [self _cardFromString:
                   @"BEGIN:VCARD\n"
                   @"VERSION:3.0\n"
                   @"N:Nom;Prénom;;;\n"
                   @"FN:Prénom Nom\n"
                   @"NICKNAME:Surnom\n"
                   @"TEL;TYPE=WORK:+111\nTEL;TYPE=HOME:+222\n"
                   @"TEL;TYPE=CELL:+333\nTEL;TYPE=FAX:+444\nTEL;TYPE=PAGER:+555\n"
                   @"EMAIL;TYPE=WORK:a@x.com\nEMAIL;TYPE=HOME:b@x.com\n"
                   @"ADR;TYPE=HOME:;;hs;hl;hst;hpc;hco\n"
                   @"ADR;TYPE=WORK:;;ws;wl;wst;wpc;wco\n"
                   @"URL;TYPE=WORK:uw\nURL;TYPE=HOME:uh\n"
                   @"ORG:o1;os1;os2\nTITLE:t1\n"
                   @"CATEGORIES:cat1,cat2\nBDAY:1946-12-04\nNOTE:note1\n"
                   @"X-AIM:aimid\nEND:VCARD\n"];
  record = [card asLDIFRecord];

  testEquals([record objectForKey: @"objectClass"],
             ([NSArray arrayWithObjects: @"top", @"inetOrgPerson",
                          @"mozillaAbPersonAlpha", nil]));
  testEquals([record objectForKey: @"sn"], @"Nom");
  testEquals([record objectForKey: @"givenname"], given);
  testEquals([record objectForKey: @"displayname"], displayName);
  testEquals([record objectForKey: @"mozillanickname"], @"Surnom");
  testEquals([record objectForKey: @"telephonenumber"], @"+111");
  testEquals([record objectForKey: @"homephone"], @"+222");
  testEquals([record objectForKey: @"mobile"], @"+333");
  testEquals([record objectForKey: @"facsimiletelephonenumber"], @"+444");
  testEquals([record objectForKey: @"pager"], @"+555");
  testEquals([record objectForKey: @"mail"], @"a@x.com");
  testEquals([record objectForKey: @"mozillasecondemail"], @"b@x.com");
  testEquals([record objectForKey: @"nsaimid"], @"aimid");
  testEquals([record objectForKey: @"mozillahomestreet"], @"hs");
  testEquals([record objectForKey: @"mozillahomelocalityname"], @"hl");
  testEquals([record objectForKey: @"mozillahomestate"], @"hst");
  testEquals([record objectForKey: @"mozillahomepostalcode"], @"hpc");
  testEquals([record objectForKey: @"mozillahomecountryname"], @"hco");
  testEquals([record objectForKey: @"street"], @"ws");
  testEquals([record objectForKey: @"l"], @"wl");
  testEquals([record objectForKey: @"st"], @"wst");
  testEquals([record objectForKey: @"postalcode"], @"wpc");
  testEquals([record objectForKey: @"c"], @"wco");
  testEquals([record objectForKey: @"mozillaworkurl"], @"uw");
  testEquals([record objectForKey: @"mozillahomeurl"], @"uh");
  testEquals([record objectForKey: @"title"], @"t1");
  testEquals([record objectForKey: @"o"], @"o1");
  testEquals([record objectForKey: @"ou"], @"os1, os2");
  testEquals([record objectForKey: @"vcardcategories"],
             ([NSArray arrayWithObjects: @"cat1", @"cat2", nil]));
  testEquals([record objectForKey: @"birthyear"], @"1946");
  testEquals([record objectForKey: @"birthmonth"], @"12");
  testEquals([record objectForKey: @"birthday"], @"04");
  testEquals([record objectForKey: @"description"], @"note1");
  testEquals([record objectForKey: @"dn"],
             [NSString stringWithUTF8String: "cn=Prénom Nom,mail=a@x.com"]);
  testEquals([record objectForKey: @"mozillausehtmlmail"], @"");
}

- (void) test_as_ldif_record_ldif_string
{
  NGVCard *card;
  NSString *ldif, *dn, *given, *prefix;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\n"
                   @"VERSION:3.0\n"
                   @"N:Nom;Prénom;;;\nFN:Prénom Nom\n"
                   @"EMAIL;TYPE=WORK:a@x.com\n"
                   @"CATEGORIES:cat1,cat2\nEND:VCARD\n"];
  ldif = [[card asLDIFRecord] ldifRecordAsString];
  dn = [[NSString stringWithUTF8String: "cn=Prénom Nom,mail=a@x.com"] stringByEncodingBase64];
  given = [[NSString stringWithUTF8String: "Prénom"] stringByEncodingBase64];
  prefix = [NSString stringWithFormat: @"dn:: %@\n", dn];

  test([ldif hasPrefix: prefix]);
  test([ldif hasPrefix: [prefix stringByAppendingString:
                              @"objectClass: top\n"
                              @"objectClass: inetOrgPerson\n"
                              @"objectClass: mozillaAbPersonAlpha\n"]]);
  test(([ldif rangeOfString: [NSString stringWithFormat: @"givenname:: %@\n", given]].location != NSNotFound));
  test([ldif rangeOfString: @"vcardcategories: cat1\n"].location != NSNotFound);
  test([ldif rangeOfString: @"vcardcategories: cat2\n"].location != NSNotFound);
  test([ldif rangeOfString: @"mail: a@x.com\n"].location != NSNotFound);
}

- (void) test_as_ldif_record_phone_combinations
{
  NGVCard *card;
  NSDictionary *record;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\n"
                   @"VERSION:3.0\n"
                   @"TEL;TYPE=WORK,FAX:+111\nTEL;TYPE=WORK:+222\n"
                   @"TEL;TYPE=HOME,FAX:+333\nTEL;TYPE=HOME:+444\n"
                   @"TEL;TYPE=FAX:+555\nTEL;TYPE=CELL:+666\nTEL;TYPE=PAGER:+777\n"
                   @"END:VCARD\n"];
  record = [card asLDIFRecord];

  testEquals([record objectForKey: @"telephonenumber"], @"+222");
  testEquals([record objectForKey: @"homephone"], @"+444");
  testEquals([record objectForKey: @"facsimiletelephonenumber"], @"+111");
  testEquals([record objectForKey: @"mobile"], @"+666");
  testEquals([record objectForKey: @"pager"], @"+777");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\n"
                   @"VERSION:3.0\n"
                   @"TEL;TYPE=WORK,FAX:+111\n"
                   @"END:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"telephonenumber"], @"");
  testEquals([record objectForKey: @"facsimiletelephonenumber"], @"+111");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\n"
                   @"VERSION:3.0\n"
                   @"TEL;TYPE=CELL:+41 79 111 22 33\nTEL;TYPE=CELL:+41 79 444 55 66\n"
                   @"END:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"mobile"], @"+41 79 111 22 33");
  test([[record objectForKey: @"mobile"] isKindOfClass: [NSString class]]);
}

- (void) test_as_ldif_record_voice_fallback
{
  NGVCard *card;
  NSDictionary *record;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\n"
                   @"VERSION:2.1\n"
                   @"N:name;surname;;;;\n"
                   @"TEL;VOICE;HOME:\nTEL;VOICE;WORK:\nTEL;PAGER:\nTEL;FAX;WORK:\n"
                   @"TEL;CELL:514 123 1234\nTEL;VOICE:450 456 6789\n"
                   @"END:VCARD\n"];
  record = [card asLDIFRecord];

  testEquals([record objectForKey: @"telephonenumber"], @"450 456 6789");
  testEquals([record objectForKey: @"mobile"], @"514 123 1234");
  testEquals([record objectForKey: @"homephone"], @"");
  testEquals([record objectForKey: @"pager"], @"");
}

- (void) test_as_ldif_record_email_fields
{
  NGVCard *card;
  NSDictionary *record;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nEMAIL:x1@y.z\nEMAIL:x2@y.z\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"mail"], @"x1@y.z");
  testEquals([record objectForKey: @"mozillasecondemail"], @"x2@y.z");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nEMAIL;TYPE=HOME:h@y.z\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"mail"], @"h@y.z");
  testEquals([record objectForKey: @"mozillasecondemail"], @"");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nEMAIL:x1@y.z\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"mail"], @"x1@y.z");
  testEquals([record objectForKey: @"mozillasecondemail"], @"");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  test([record objectForKey: @"mail"] == nil);
  test([record objectForKey: @"mozillasecondemail"] == nil);
  testEquals([record objectForKey: @"mozillausehtmlmail"], @"");
}

- (void) test_as_ldif_record_url_fields
{
  NGVCard *card;
  NSDictionary *record;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nURL:plain\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"mozillaworkurl"], @"");
  testEquals([record objectForKey: @"mozillahomeurl"], @"plain");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nURL:u-one\nURL;TYPE=WORK:u-work\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"mozillaworkurl"], @"u-work");
  testEquals([record objectForKey: @"mozillahomeurl"], @"u-one");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nURL;TYPE=WORK:U-WORK\nURL:u-two\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"mozillaworkurl"], @"U-WORK");
  testEquals([record objectForKey: @"mozillahomeurl"], @"u-two");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nURL;TYPE=HOME:uh\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"mozillaworkurl"], @"");
  testEquals([record objectForKey: @"mozillahomeurl"], @"uh");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"mozillaworkurl"], @"");
  testEquals([record objectForKey: @"mozillahomeurl"], @"");
}

- (void) test_as_ldif_record_addresses
{
  NGVCard *card;
  NSDictionary *record;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nADR:;;ps;pl;;;\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  test([record objectForKey: @"mozillahomestreet"] == nil);
  testEquals([record objectForKey: @"street"], @"ps");
  testEquals([record objectForKey: @"l"], @"pl");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nADR;TYPE=HOME:;;hs;hl;;;\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"mozillahomestreet"], @"hs");
  testEquals([record objectForKey: @"mozillahomelocalityname"], @"hl");
  testEquals([record objectForKey: @"street"], @"hs");
  testEquals([record objectForKey: @"l"], @"hl");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  test([record objectForKey: @"mozillahomestreet"] == nil);
  test([record objectForKey: @"street"] == nil);
}

- (void) test_as_ldif_record_dn_construction
{
  NGVCard *card;
  NSDictionary *record;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nFN:John\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"dn"], @"cn=John");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nEMAIL:only@x.y\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"dn"], @"mail=only@x.y");

  card = [NGVCard cardWithUid: @"empty"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"dn"], @"");
}

- (void) test_as_ldif_record_org_fields
{
  NGVCard *card;
  NSDictionary *record;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nORG:acme;;unit2\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"o"], @"acme");
  testEquals([record objectForKey: @"ou"], @"unit2");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nORG:acme\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"o"], @"acme");
  test([record objectForKey: @"ou"] == nil);

  card = [NGVCard cardWithUid: @"noorg"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"o"], @"");
}

- (void) test_as_ldif_record_birthday_and_html
{
  NGVCard *card;
  NSDictionary *record;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nBDAY:1980-01-05\nX-MOZILLA-HTML:TRUE\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"birthyear"], @"1980");
  testEquals([record objectForKey: @"birthmonth"], @"01");
  testEquals([record objectForKey: @"birthday"], @"05");
  testEquals([record objectForKey: @"mozillausehtmlmail"], @"TRUE");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nEND:VCARD\n"];
  record = [card asLDIFRecord];
  test([record objectForKey: @"birthyear"] == nil);
  testEquals([record objectForKey: @"mozillausehtmlmail"], @"");
}

- (void) test_update_from_ldif_record_full_round_trip
{
  NGVCard *card;
  NSDictionary *record;
  NSArray *tels, *emails, *adrs;
  CardElement *adr;

  card = [NGVCard cardWithUid: @"rt"];
  [card updateFromLDIFRecord:
            [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Nom", @"sn",
                           @"Given", @"givenname",
                           @"Surnom", @"mozillanickname",
                           [NSArray arrayWithObjects: @"t1", @"t2", nil], @"title",
                           @"display x", @"displayname",
                           [NSArray arrayWithObjects: @"w@x.y", @"h@x.y", nil], @"c_emails",
                           @"mail1@x.y", @"mail",
                           [NSArray arrayWithObjects: @"s1@x.y", @"", nil], @"mozillasecondemail",
                           [NSArray arrayWithObjects: @"+111", @"+222", nil], @"telephonenumber",
                           @"+333", @"homephone",
                           @"+444", @"mobile",
                           @"+555", @"facsimiletelephonenumber",
                           @"+666", @"pager",
                           @"hs2", @"mozillahomestreet2",
                           @"hs", @"mozillahomestreet",
                           @"hl", @"mozillahomelocalityname",
                           @"hst", @"mozillahomestate",
                           @"hpc", @"mozillahomepostalcode",
                           @"hco", @"mozillahomecountryname",
                           @"ws2", @"mozillaworkstreet2",
                           @"ws", @"street",
                           @"wl", @"l",
                           @"wst", @"st",
                           @"wpc", @"postalcode",
                           @"wco", @"c",
                           [NSArray arrayWithObjects: @"o1", @"o2", nil], @"o",
                           [NSArray arrayWithObjects: @"ou1", @"ou2", nil], @"ou",
                           @"uh", @"mozillahomeurl",
                           @"uw", @"mozillaworkurl",
                           @"aimid", @"nsaimid",
                           @"1946", @"birthyear",
                           @"12", @"birthmonth",
                           @"04", @"birthday",
                           @"info", @"c_info",
                           [NSArray arrayWithObjects: @"note1", @"note2", nil], @"description",
                           [NSArray arrayWithObjects: @"ca1", @"ca2", nil], @"vcardcategories",
                           [NSData dataWithBytes: "abc" length: 3], @"photo",
                           @"TRUE", @"mozillausehtmlmail",
                           nil]];

  testEquals([card nickname], @"Surnom");
  testEquals([card fn], @"display x");
  testEquals([card title], @"t1");
  testEquals([card titles], ([NSArray arrayWithObjects: @"t1", @"t2", nil]));
  testEquals([card bday], @"1946-12-04");
  testEquals([card note], @"note1");
  testEquals([card notes], ([NSArray arrayWithObjects: @"note1", @"note2", nil]));
  testEquals([card categories], ([NSArray arrayWithObjects: @"ca1", @"ca2", nil]));
  testEquals([card photo], @"YWJj");
  testEquals([card organizations],
             ([NSArray arrayWithObjects: @"o1", @"o2", @"ou1", @"ou2", nil]));

  tels = [card childrenWithTag: @"tel"];
  test([tels count] == 6);
  testEquals([[tels objectAtIndex: 0] flattenedValuesForKey: @""], @"+111");
  testEquals([[tels objectAtIndex: 0] tag], @"tel");
  test([[[tels objectAtIndex: 0] attributes] count] > 0);

  emails = [card emails];
  test([emails count] == 4);
  test([emails containsObject: @"w@x.y"]);
  test([emails containsObject: @"h@x.y"]);
  test([emails containsObject: @"mail1@x.y"]);
  test([emails containsObject: @"s1@x.y"]);

  adrs = [card childrenWithTag: @"adr"];
  test([adrs count] == 2);
  adr = [adrs objectAtIndex: 0];
  testEquals([adr flattenedValueAtIndex: 1 forKey: @""], @"hs2");
  testEquals([adr flattenedValueAtIndex: 2 forKey: @""], @"hs");
  testEquals([adr flattenedValueAtIndex: 3 forKey: @""], @"hl");
  testEquals([adr flattenedValueAtIndex: 4 forKey: @""], @"hst");
  testEquals([adr flattenedValueAtIndex: 5 forKey: @""], @"hpc");
  testEquals([adr flattenedValueAtIndex: 6 forKey: @""], @"hco");
  adr = [adrs objectAtIndex: 1];
  testEquals([adr flattenedValueAtIndex: 1 forKey: @""], @"ws2");
  testEquals([adr flattenedValueAtIndex: 2 forKey: @""], @"ws");
  testEquals([adr flattenedValueAtIndex: 3 forKey: @""], @"wl");
  testEquals([adr flattenedValueAtIndex: 4 forKey: @""], @"wst");
  testEquals([adr flattenedValueAtIndex: 5 forKey: @""], @"wpc");
  testEquals([adr flattenedValueAtIndex: 6 forKey: @""], @"wco");

  record = [card asLDIFRecord];
  testEquals([record objectForKey: @"sn"], @"Nom");
  testEquals([record objectForKey: @"givenname"], @"Given");
  testEquals([record objectForKey: @"displayname"], @"display x");
  testEquals([record objectForKey: @"telephonenumber"], @"+111");
  testEquals([record objectForKey: @"homephone"], @"+333");
  testEquals([record objectForKey: @"mobile"], @"+444");
  testEquals([record objectForKey: @"facsimiletelephonenumber"], @"+555");
  testEquals([record objectForKey: @"pager"], @"+666");
  testEquals([record objectForKey: @"mail"], @"w@x.y");
  testEquals([record objectForKey: @"mozillasecondemail"], @"s1@x.y");
  testEquals([record objectForKey: @"mozillahomestreet"], @"hs");
  testEquals([record objectForKey: @"mozillahomestreet2"], @"hs2");
  testEquals([record objectForKey: @"street"], @"ws");
  testEquals([record objectForKey: @"mozillaworkstreet2"], @"ws2");
  testEquals([record objectForKey: @"mozillahomeurl"], @"uh");
  testEquals([record objectForKey: @"mozillaworkurl"], @"uw");
  testEquals([record objectForKey: @"nsaimid"], @"aimid");
  testEquals([record objectForKey: @"title"], @"t1");
  testEquals([record objectForKey: @"o"], @"o1");
  testEquals([record objectForKey: @"ou"], @"o2, ou1, ou2");
  testEquals([record objectForKey: @"birthyear"], @"1946");
  testEquals([record objectForKey: @"birthmonth"], @"12");
  testEquals([record objectForKey: @"birthday"], @"04");
  testEquals([record objectForKey: @"description"], @"note1");
  testEquals([record objectForKey: @"mozillausehtmlmail"], @"TRUE");
  testEquals([record objectForKey: @"vcardcategories"],
             ([NSArray arrayWithObjects: @"ca1", @"ca2", nil]));
  testEquals([record objectForKey: @"dn"], @"cn=display x,mail=w@x.y");

  [card updateFromLDIFRecord: [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"Nom", @"sn",
                                    @"newhs", @"mozillahomestreet",
                                    nil]];
  testEquals([[card asLDIFRecord] objectForKey: @"mozillahomestreet"], @"newhs");
}

- (NSString *) _bdayForYear: (int) twoDigitYear
{
  int yearOfToday, expectedYear;

  yearOfToday = [[NSCalendarDate date] yearOfCommonEra];
  if (yearOfToday < (twoDigitYear + 2000))
    expectedYear = twoDigitYear + 1900;
  else
    expectedYear = twoDigitYear + 2000;

  return [NSString stringWithFormat: @"%.4d-12-04", expectedYear];
}

- (void) test_update_from_ldif_record_birth_years
{
  NGVCard *card;

  card = [NGVCard cardWithUid: @"y0"];
  [card updateFromLDIFRecord: [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"Nom", @"sn",
                                       @"0", @"birthyear",
                                       @"12", @"birthmonth",
                                       @"04", @"birthday",
                                       nil]];
  testEquals([card bday], ([NSString stringWithFormat: @"%.4d-12-04",
                           (int)[[NSCalendarDate date] yearOfCommonEra]]));

  card = [NGVCard cardWithUid: @"y26"];
  [card updateFromLDIFRecord: [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"Nom", @"sn",
                                       @"26", @"birthyear",
                                       @"12", @"birthmonth",
                                       @"04", @"birthday",
                                       nil]];
  testEquals([card bday], [self _bdayForYear: 26]);

  card = [NGVCard cardWithUid: @"y27"];
  [card updateFromLDIFRecord: [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"Nom", @"sn",
                                       @"27", @"birthyear",
                                       @"12", @"birthmonth",
                                       @"04", @"birthday",
                                       nil]];
  testEquals([card bday], [self _bdayForYear: 27]);

  card = [NGVCard cardWithUid: @"y99"];
  [card updateFromLDIFRecord: [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"Nom", @"sn",
                                       @"99", @"birthyear",
                                       @"12", @"birthmonth",
                                       @"04", @"birthday",
                                       nil]];
  testEquals([card bday], [self _bdayForYear: 99]);

  card = [NGVCard cardWithUid: @"y1946"];
  [card updateFromLDIFRecord: [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"Nom", @"sn",
                                       @"1946", @"birthyear",
                                       @"12", @"birthmonth",
                                       @"04", @"birthday",
                                       nil]];
  testEquals([card bday], @"1946-12-04");

  card = [NGVCard cardWithUid: @"ypartial"];
  [card updateFromLDIFRecord: [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"Nom", @"sn",
                                       @"1946", @"birthyear",
                                       nil]];
  testEquals([card bday], @"");
}

- (void) test_update_from_ldif_record_null_handling
{
  NGVCard *card;

  card = [NGVCard cardWithUid: @"nulls"];
  [card updateFromLDIFRecord:
            [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Nom", @"sn",
                           @"note str", @"description",
                           [NSNull null], @"photo",
                           [NSNull null], @"vcardcategories",
                           @"info", @"c_info",
                           @"o1", @"o",
                           @"ou1", @"ou",
                           @"second@x.y", @"mozillasecondemail",
                           nil]];
  testEquals([card note], @"note str");
  test([[card categories] count] == 0);
  test([[card photo] length] == 0);
  test([[card childrenWithTag: @"x-sogo-contactinfo"] count] == 1);
  testEquals([[card uniqueChildWithTag: @"x-sogo-contactinfo"] flattenedValuesForKey: @""], @"info");
  testEquals([card organizations], ([NSArray arrayWithObjects: @"o1", @"ou1", nil]));
  test([card emails] != nil);

  card = [NGVCard cardWithUid: @"nulls2"];
  [card updateFromLDIFRecord:
            [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNull null], @"description",
                           [NSNull null], @"photo",
                           @"cat1,cat2", @"vcardcategories",
                           nil]];
  test([[card childrenWithTag: @"x-sogo-contactinfo"] count] == 0);
  test([[card note] length] == 0);
  testEquals([card categories], ([NSArray arrayWithObjects: @"cat1", @"cat2", nil]));
  test([[card photo] length] == 0);
}

- (void) test_update_from_ldif_record_email_dedupe
{
  NGVCard *card;
  NSArray *emails;

  card = [NGVCard cardWithUid: @"dup1"];
  [card updateFromLDIFRecord:
            [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Nom", @"sn",
                           [NSArray arrayWithObjects: @"w@x.y", nil], @"c_emails",
                           @"w@x.y", @"mail",
                           nil]];
  testEquals([card emails], [NSArray arrayWithObject: @"w@x.y"]);

  card = [NGVCard cardWithUid: @"dup2"];
  [card updateFromLDIFRecord:
            [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Nom", @"sn",
                           [NSArray arrayWithObjects: @"w@x.y", nil], @"c_emails",
                           [NSArray arrayWithObjects: @"w@x.y", @"z@x.y", nil], @"mail",
                           nil]];
  emails = [card emails];
  test([emails count] == 2);
  test([emails containsObject: @"w@x.y"]);
  test([emails containsObject: @"z@x.y"]);

  card = [NGVCard cardWithUid: @"dup3"];
  [card updateFromLDIFRecord:
            [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Nom", @"sn",
                           [NSArray arrayWithObjects: @"w@x.y", nil], @"c_emails",
                           @"m@x.y", @"mail",
                           [NSArray arrayWithObjects: @"w@x.y", @"s@x.y", nil], @"mozillasecondemail",
                           nil]];
  emails = [card emails];
  test([emails count] == 3);
  test([emails containsObject: @"w@x.y"]);
  test([emails containsObject: @"m@x.y"]);
  test([emails containsObject: @"s@x.y"]);

  card = [NGVCard cardWithUid: @"dup4"];
  [card updateFromLDIFRecord:
            [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Nom", @"sn",
                           [NSArray arrayWithObjects: @"", @"m@x.y", nil], @"mail",
                           nil]];
  emails = [card emails];
  test([emails count] == 1);
  test([emails containsObject: @"m@x.y"]);

  card = [NGVCard cardWithUid: @"dup5"];
  [card updateFromLDIFRecord:
            [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Nom", @"sn",
                           [NSArray arrayWithObjects: @"m@x.y", @"m@x.y", nil], @"mail",
                           nil]];
  emails = [card emails];
  test([emails count] == 1);
  test([emails containsObject: @"m@x.y"]);

  card = [NGVCard cardWithUid: @"dup6"];
  [card updateFromLDIFRecord:
            [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Nom", @"sn",
                           @"", @"mail",
                           @"s@x.y", @"mozillasecondemail",
                           nil]];
  emails = [card emails];
  test([emails count] == 1);
  test([emails containsObject: @"s@x.y"]);

  card = [NGVCard cardWithUid: @"dup7"];
  [card updateFromLDIFRecord:
            [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Nom", @"sn",
                           @"m@x.y", @"mail",
                           [NSArray arrayWithObjects: @"m@x.y", @"s@x.y", nil], @"mozillasecondemail",
                           nil]];
  emails = [card emails];
  test([emails count] == 2);
  test([emails containsObject: @"m@x.y"]);
  test([emails containsObject: @"s@x.y"]);

  card = [NGVCard cardWithUid: @"dup8"];
  [card updateFromLDIFRecord:
            [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Nom", @"sn",
                           [NSArray arrayWithObjects: @"s1@x.y", @"s2@x.y", nil], @"mozillasecondemail",
                           nil]];
  emails = [card emails];
  test([emails count] == 2);
  test([emails containsObject: @"s1@x.y"]);
  test([emails containsObject: @"s2@x.y"]);

  card = [NGVCard cardWithUid: @"dup9"];
  [card updateFromLDIFRecord:
            [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Nom", @"sn",
                           [NSArray arrayWithObjects: @"s1@x.y", @"s1@x.y", nil], @"mozillasecondemail",
                           nil]];
  emails = [card emails];
  test([emails count] == 1);
  test([emails containsObject: @"s1@x.y"]);
}

- (void) test_element_with_tag_and_add_element
{
  NGVCard *card;
  CardElement *element, *element2;
  NSArray *elements;

  card = [NGVCard cardWithUid: @"elem"];
  element = [card elementWithTag: @"email" ofType: @"home"];
  test(element != nil);
  test([element hasAttribute: @"type" havingValue: @"home"]);
  [element setSingleValue: @"a@x.y" forKey: @""];
  element2 = [card elementWithTag: @"email" ofType: @"home"];
  test(element == element2);
  elements = [card childrenWithTag: @"email"];
  test([elements count] == 1);

  [card addElementWithTag: @"email" ofType: @"" withValue: @"plain@x.y"];
  [card addElementWithTag: @"email" ofType: @"work"
                 withValue: [NSArray arrayWithObjects: @"w1@x.y", @"w2@x.y", nil]];
  [card addElementWithTag: @"email" ofType: @"work" withValue: [NSNull null]];
  [card addElementWithTag: @"email" ofType: @"work" withValue: nil];
  elements = [card childrenWithTag: @"email"];
  test([elements count] == 4);
}

- (void) test_phone_accessors
{
  NGVCard *card;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\n"
                   @"VERSION:3.0\n"
                   @"N:D;J;;;\n"
                   @"TEL;TYPE=WORK,FAX:+111\nTEL;TYPE=WORK:+222\n"
                   @"TEL;TYPE=HOME,FAX:+333\nTEL;TYPE=HOME:+444\n"
                   @"TEL;TYPE=CELL:+555\nTEL;TYPE=PAGER:+666\n"
                   @"END:VCARD\n"];
  testEquals([card workPhone], @"+222");
  testEquals([card homePhone], @"+444");
  testEquals([card fax], @"+111");
  testEquals([card mobile], @"+555");
  testEquals([card pager], @"+666");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nEND:VCARD\n"];
  test([card workPhone] == nil);
  test([card homePhone] == nil);
  test([card fax] == nil);
  test([card mobile] == nil);
  test([card pager] == nil);
}

- (void) test_work_company_and_full_name
{
  NGVCard *card;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nFN:John Doe\nORG:acme\nEND:VCARD\n"];
  testEquals([card fullName], @"John Doe");
  testEquals([card workCompany], @"acme");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:Last;First;;;\nEND:VCARD\n"];
  testEquals([card fullName], @"First Last");
  test([card workCompany] == nil);

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:;First;;;\nEND:VCARD\n"];
  testEquals([card fullName], @"First");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:Last;;;;\nEND:VCARD\n"];
  testEquals([card fullName], @"Last");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:;;;;\nORG:acme\nEND:VCARD\n"];
  testEquals([card fullName], @"acme");
  testEquals([card workCompany], @"acme");

  card = [NGVCard cardWithUid: @"bare"];
  test([[card fullName] length] == 0);
  test([card workCompany] == nil);
}

- (void) test_organizations
{
  NGVCard *card;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nORG:o1\nORG:o2;u2\nEND:VCARD\n"];
  testEquals([card organizations], ([NSArray arrayWithObjects: @"o1", @"o2", @"u2", nil]));

  card = [NGVCard cardWithUid: @"setorg"];
  [card setOrganizations: [NSArray arrayWithObjects: @"acme", @"unit", nil]];
  testEquals([card organizations], ([NSArray arrayWithObjects: @"acme", @"unit", nil]));
  [card setOrganizations: [NSArray arrayWithObject: @"solo"]];
  testEquals([card organizations], [NSArray arrayWithObject: @"solo"]);
  [card setOrganizations: [NSArray arrayWithObject: @""]];
  testEquals([card organizations], [NSArray array]);
  test([card workCompany] == nil);
}

- (void) test_emails_and_secondary_emails
{
  NGVCard *card;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nEMAIL;TYPE=HOME:h@x.y\nEMAIL;TYPE=WORK,PREF:p@x.y\nEND:VCARD\n"];
  testEquals([card emails], ([NSArray arrayWithObjects: @"p@x.y", @"h@x.y", nil]));
  testEquals([card preferredEMail], @"p@x.y");
  test([[card secondaryEmails] count] == 1);
  testEquals([[[card secondaryEmails] objectAtIndex: 0] flattenedValuesForKey: @""], @"h@x.y");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nEMAIL:a@x.y\nEMAIL:b@x.y\nEND:VCARD\n"];
  testEquals([card emails], ([NSArray arrayWithObjects: @"a@x.y", @"b@x.y", nil]));
  test([[card secondaryEmails] count] == 1);
  testEquals([[[card secondaryEmails] objectAtIndex: 0] flattenedValuesForKey: @""], @"b@x.y");

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nEND:VCARD\n"];
  testEquals([card emails], [NSArray array]);
  testEquals([card secondaryEmails], [NSArray array]);
}

- (void) test_birthday_accessor
{
  NGVCard *card;
  NSCalendarDate *birthday;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nBDAY:1946-12-04\nEND:VCARD\n"];
  birthday = [card birthday];
  test(birthday != nil);
  test([birthday yearOfCommonEra] == 1946);
  test([birthday monthOfYear] == 12);
  test([birthday dayOfMonth] == 4);

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nEND:VCARD\n"];
  test([card birthday] == nil);
}

- (void) test_quick_record
{
  NGVCard *card;
  NSDictionary *quick;

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:Nom;Prénom;;;\nFN:Prénom Nom\n"
                   @"EMAIL;TYPE=WORK,PREF:p@x.y\nTEL;TYPE=WORK:+111\n"
                   @"ORG:acme;unit\nADR;TYPE=WORK:;;s;town;;;\n"
                   @"X-AIM:aimid\nCATEGORIES:c1,c2\nEND:VCARD\n"];
  quick = [card quickRecordFromContent: @"c" container: nil nameInContainer: @"n"];
  testEquals([quick objectForKey: @"c_cn"], [NSString stringWithUTF8String: "Prénom Nom"]);
  testEquals([quick objectForKey: @"c_sn"], @"Nom");
  testEquals([quick objectForKey: @"c_givenName"], [NSString stringWithUTF8String: "Prénom"]);
  testEquals([quick objectForKey: @"c_telephonenumber"], @"+111");
  testEquals([quick objectForKey: @"c_mail"], @"p@x.y");
  testEquals([quick objectForKey: @"c_o"], @"acme");
  testEquals([quick objectForKey: @"c_ou"], @"unit");
  testEquals([quick objectForKey: @"c_l"], @"town");
  testEquals([quick objectForKey: @"c_screenname"], @"aimid");
  testEquals([quick objectForKey: @"c_categories"], @"c1,c2");
  testEquals([quick objectForKey: @"c_component"], @"vcard");
  testEquals([quick objectForKey: @"c_hascertificate"], [NSNumber numberWithInt: 0]);

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nEND:VCARD\n"];
  quick = [card quickRecordFromContent: @"c" container: nil nameInContainer: @"n"];
  test([quick objectForKey: @"c_mail"] == [NSNull null]);
  test([quick objectForKey: @"c_categories"] == [NSNull null]);
  test([quick objectForKey: @"c_l"] == nil);
  test([quick objectForKey: @"c_telephonenumber"] == nil);

  card = [self _cardFromString:
                   @"BEGIN:VCARD\nVERSION:3.0\nN:D;J;;;\nADR:;;;;;\nKEY:x\nEND:VCARD\n"];
  quick = [card quickRecordFromContent: @"c" container: nil nameInContainer: @"n"];
  test([quick objectForKey: @"c_l"] == nil);
  testEquals([quick objectForKey: @"c_hascertificate"], [NSNumber numberWithInt: 1]);
}

- (void) test_date_formatter
{
  SOGoDateFormatter *formatter;
  NSDictionary *locale;
  NSCalendarDate *date;

  formatter = [[SOGoDateFormatter alloc] init];
  date = [NSCalendarDate dateWithYear: 2020 month: 1 day: 2
                                 hour: 3 minute: 4 second: 0
                             timeZone: [NSTimeZone timeZoneWithName: @"GMT"]];

  test([formatter shortFormattedDate: date] == nil);
  test([formatter formattedDate: date] == nil);
  test([formatter formattedTime: date] == nil);
  test([formatter formattedDateAndTime: date] == nil);
  test([formatter stringForObjectValue: date] == nil);
  test([formatter stringForObjectValue: @"not a date"] == nil);

  locale = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"%d/%m/%Y", NSShortDateFormatString,
                            @"%Y-%m-%d", NSDateFormatString,
                            @"%H:%M", NSTimeFormatString,
                            nil];
  [formatter setLocale: locale];
  testEquals([formatter shortFormattedDate: date], @"02/01/2020");
  testEquals([formatter formattedDate: date], @"2020-01-02");
  testEquals([formatter formattedTime: date], @"03:04");
  testEquals([formatter formattedDateAndTime: date], @"2020-01-02 03:04 GMT+0000");

  [formatter setShortDateFormat: @"%Y"];
  [formatter setLongDateFormat: @"%m-%d"];
  [formatter setTimeFormat: @"%H"];
  testEquals([formatter shortFormattedDate: date], @"2020");
  testEquals([formatter formattedDate: date], @"01-02");
  testEquals([formatter formattedTime: date], @"03");
  testEquals([formatter stringForObjectValue: date], @"01-02 03 GMT+0000");

  [formatter setLocale: [NSDictionary dictionary]];
  test([formatter shortFormattedDate: date] == nil);

  [formatter release];
}

@end
