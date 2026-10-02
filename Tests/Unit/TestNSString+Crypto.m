/* TestNSString+Crypto.m - this file is part of SOGo
 *
 * Copyright (C) 2011, 2012 Jeroen Dekkers
 * Copyright (C) 2020 Nicolas Höft
 *
 * Author: Jeroen Dekkers <jeroen@dekkers.ch>
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

#import "SOGo/NSString+Crypto.h"

#import "SOGoTest.h"

@interface NSString (SOGoAES256GCMTests)
- (NSString *)extractCryptScheme;
- (NSDictionary *)encryptAES256GCM:(NSString *)passwordScheme exception:(NSException **)ex;
- (NSString *)decryptAES256GCM:(NSString *)passwordScheme iv:(NSString *)ivString tag:(NSString *)tagString exception:(NSException **)ex;
@end

@interface TestNSData_plus_Crypto : SOGoTest
@end

@implementation TestNSData_plus_Crypto

- (void) test_dataCrypto
{
  const char *inStrings[] = { "SOGoSOGoSOGoSOGo", "éléphant", "2š", NULL };
  const char **inString;
  NSString *MD5Strings[] = { @"d3e8072c49511f099d254cc740c7e12a", @"bc6a1535589d6c3cf7999ac37018c11e", @"886ae9b58817fb8a63902feefcd18812" };
  NSString *SHA1Strings[] = { @"b7d891e0f3b42898fa66627b5cfa3d80501bae46", @"99a02f8802f8ea7e3ad91c4cc4d3ef5a7257c88f", @"32b89f3a9e6078db554cdd39f8571c09de7e8b21" };
  NSString **MD5String;
  NSString **SHA1String;
  NSString *result, *error;

  inString = inStrings;
  MD5String = MD5Strings;
  SHA1String = SHA1Strings;
  while (*inString)
    {
      result = [[NSString stringWithUTF8String: *inString] asMD5String];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong MD5: '%@' (expected '%@')",
                        *inString, result, *MD5String];
      testWithMessage([result isEqualToString: *MD5String], error);
      result = [[NSString stringWithUTF8String: *inString] asSHA1String];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong SHA1: '%@' (expected '%@')",
                        *inString, result, *SHA1String];
      testWithMessage([result isEqualToString: *SHA1String], error);
      inString++;
      MD5String++;
      SHA1String++;
    }
}

- (void) test_blowfish
{
  NSString *error;
  // well-known comparison
  NSString *blf_key = @"123456";
  NSString *blf_hash = @"{BLF-CRYPT}$2a$05$tLVuFQTgdwrZmixu.QMxoedUAUEeIFIBv89Ur5mQ6F1vBL8Vw1mXO";
  error = [NSString stringWithFormat:
                          @"string '%@' wrong BLF-CRYPT: '%@'",
                        blf_key, blf_hash];
  testWithMessage([blf_key isEqualToCrypted:blf_hash withDefaultScheme: @"CRYPT" keyPath: nil], error);

  // generate a new blowfish-crypt key
  NSString *blf_prefix = @"$2y$05$";

  NSString *blf_result = [blf_key asCryptedPassUsingScheme: @"blf-crypt" keyPath: nil];

  error = [NSString stringWithFormat:
                          @"returned hash '%@' has incorrect BLF-CRYPT prefix: '%@'",
                        blf_result, blf_prefix];

  testWithMessage([blf_result hasPrefix: blf_prefix], error);

  test([blf_key isEqualToCrypted:blf_result withDefaultScheme: @"BLF-CRYPT" keyPath: nil]);
}

- (void) test_pbkdf2
{
  NSString *error;
  // well-known comparison
  NSString *pbkdf2_key = @"123456";
  NSString *pbkdf2_hash = @"{PBKDF2}$1$xbhnwhLxltdS9L5M$5001$f1699047a6132383490817d6e58a5284f13339f0";
  NSString *pkbf2_prefix;
  NSString *pkbf2_result;

  error = [NSString stringWithFormat:
                          @"string '%@' wrong PBKDF2: '%@'",
                        pbkdf2_key, pbkdf2_hash];
  testWithMessage([pbkdf2_key isEqualToCrypted:pbkdf2_hash withDefaultScheme: @"CRYPT" keyPath: nil], error);

  // generate a new pbkdf2-crypt key
  pkbf2_prefix = @"$1$";
  pkbf2_result = [pbkdf2_key asCryptedPassUsingScheme: @"PBKDF2" keyPath: nil];

  error = [NSString stringWithFormat:
                          @"returned hash '%@' has incorrect PBKDF2 prefix: '%@'",
                        pkbf2_result, pkbf2_prefix];

  testWithMessage([pkbf2_result hasPrefix: pkbf2_prefix], error);
  test([pbkdf2_key isEqualToCrypted:pkbf2_result withDefaultScheme: @"PBKDF2" keyPath: nil]);
}

#ifdef HAVE_SODIUM
- (void) test_argon2
{
  NSString *error;
  // well-known comparison
  NSString *cleartext = @"123456";
  NSString *hash = @"{ARGON2I}$argon2i$v=19$m=32768,t=4,p=1$HWg68rEbwmY6yrdByJ7U1g$z1c06BysT+51u1RXGtYIknTpA9jAHUfw1dAqPgTiQJ8";
  NSString *prefix;
  NSString *crypted_hash;

  error = [NSString stringWithFormat:
                          @"string '%@' wrong ARGON2ID: '%@'",
                        cleartext, hash];
  testWithMessage([cleartext isEqualToCrypted:hash withDefaultScheme: @"CRYPT" keyPath: nil], error);

  // generate a new argon2id key
  prefix = @"$argon2id$";
  crypted_hash = [cleartext asCryptedPassUsingScheme: @"ARGON2ID" keyPath: nil];
  fprintf(stdout, "hash = %s\n", [crypted_hash UTF8String]);

  error = [NSString stringWithFormat:
                          @"returned hash '%@' has incorrect ARGON2ID prefix: '%@'",
                        crypted_hash, prefix];

  testWithMessage([crypted_hash hasPrefix: prefix], error);
  test([cleartext isEqualToCrypted:crypted_hash withDefaultScheme: @"ARGON2ID" keyPath: nil]);
}
#endif /* HAVE_SODUM */

- (void) test_extractCryptScheme
{
  testEquals([@"" extractCryptScheme], @"");
  testEquals([@"noscheme" extractCryptScheme], @"");
  testEquals([@"{nolimit" extractCryptScheme], @"");
  testEquals([@"{SSHA}abc" extractCryptScheme], @"ssha");
  testEquals([@"{BlF-CrYpT}abc" extractCryptScheme], @"blf-crypt");
}

- (void) test_splitPasswordWithDefaultScheme
{
  NSArray *parts;

  parts = [@"{SSHA}abc" splitPasswordWithDefaultScheme: @"crypt"];
  test([parts count] == 3);
  testEquals([parts objectAtIndex: 0], @"ssha");
  testEquals([parts objectAtIndex: 1], @"abc");
  testEquals([parts objectAtIndex: 2], [NSNumber numberWithInt: encBase64]);

  parts = [@"abc123" splitPasswordWithDefaultScheme: @"crypt"];
  test([parts count] == 3);
  testEquals([parts objectAtIndex: 0], @"crypt");
  testEquals([parts objectAtIndex: 1], @"abc123");
  testEquals([parts objectAtIndex: 2], [NSNumber numberWithInt: encPlain]);
}

- (void) test_getDefaultEncodingForScheme
{
  NSArray *result;

  result = [NSString getDefaultEncodingForScheme: @"md4"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encHex]);
  testEquals([result objectAtIndex: 1], @"md4");

  result = [NSString getDefaultEncodingForScheme: @"MD5"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encHex]);
  testEquals([result objectAtIndex: 1], @"MD5");

  result = [NSString getDefaultEncodingForScheme: @"plain-md5"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encHex]);
  testEquals([result objectAtIndex: 1], @"plain-md5");

  result = [NSString getDefaultEncodingForScheme: @"sha"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encHex]);
  testEquals([result objectAtIndex: 1], @"sha");

  result = [NSString getDefaultEncodingForScheme: @"cram-md5"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encHex]);
  testEquals([result objectAtIndex: 1], @"cram-md5");

  result = [NSString getDefaultEncodingForScheme: @"smd5"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encBase64]);
  testEquals([result objectAtIndex: 1], @"smd5");

  result = [NSString getDefaultEncodingForScheme: @"ldap-md5"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encBase64]);
  testEquals([result objectAtIndex: 1], @"ldap-md5");

  result = [NSString getDefaultEncodingForScheme: @"SSHA"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encBase64]);
  testEquals([result objectAtIndex: 1], @"SSHA");

  result = [NSString getDefaultEncodingForScheme: @"sha256"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encBase64]);
  testEquals([result objectAtIndex: 1], @"sha256");

  result = [NSString getDefaultEncodingForScheme: @"ssha256"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encBase64]);
  testEquals([result objectAtIndex: 1], @"ssha256");

  result = [NSString getDefaultEncodingForScheme: @"sha512"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encBase64]);
  testEquals([result objectAtIndex: 1], @"sha512");

  result = [NSString getDefaultEncodingForScheme: @"ssha512"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encBase64]);
  testEquals([result objectAtIndex: 1], @"ssha512");

  result = [NSString getDefaultEncodingForScheme: @"plain"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encPlain]);
  testEquals([result objectAtIndex: 1], @"plain");

  result = [NSString getDefaultEncodingForScheme: @"ssha.hex"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encHex]);
  testEquals([result objectAtIndex: 1], @"ssha");

  result = [NSString getDefaultEncodingForScheme: @"SSHA.B64"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encBase64]);
  testEquals([result objectAtIndex: 1], @"SSHA");

  result = [NSString getDefaultEncodingForScheme: @"ssha.BASE64"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encBase64]);
  testEquals([result objectAtIndex: 1], @"ssha");

  result = [NSString getDefaultEncodingForScheme: @"ssha.what"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encPlain]);
  testEquals([result objectAtIndex: 1], @"ssha");

  result = [NSString getDefaultEncodingForScheme: @"a.b.c"];
  testEquals([result objectAtIndex: 0], [NSNumber numberWithInt: encPlain]);
  testEquals([result objectAtIndex: 1], @"a.b.c");
}

- (void) test_isEqualToCryptedWithEncodings
{
  test([@"secret" isEqualToCrypted: @"{MD5}5ebe2294ecd0e0f08eab7690d2a6ee69"
                 withDefaultScheme: @"MD5" keyPath: nil]);
  test(![@"secret" isEqualToCrypted: @"{MD5}5ebe2294ecd0e0f08eab7690d2a6ee68"
                  withDefaultScheme: @"MD5" keyPath: nil]);
  test(![@"secret" isEqualToCrypted: @"{SHA}zzzz"
                  withDefaultScheme: @"SHA" keyPath: nil]);
  test(![@"secret" isEqualToCrypted: @"{SSHA}!!!!"
                  withDefaultScheme: @"SSHA" keyPath: nil]);
  test([@"secret" isEqualToCrypted: @"{PLAIN}secret"
                 withDefaultScheme: @"PLAIN" keyPath: nil]);
  test(![@"secret" isEqualToCrypted: @"{PLAIN}other"
                  withDefaultScheme: @"PLAIN" keyPath: nil]);
}

- (void) test_asCryptedPassWithExplicitEncoding
{
  NSString *result;

  result = [@"secret" asCryptedPassUsingScheme: @"md5"
                                     withSalt: [NSData data]
                                  andEncoding: encHex
                                      keyPath: nil];
  testEquals(result, @"5ebe2294ecd0e0f08eab7690d2a6ee69");

  result = [@"secret" asCryptedPassUsingScheme: @"plain"
                                     withSalt: [NSData data]
                                  andEncoding: encPlain
                                      keyPath: nil];
  testEquals(result, @"secret");

  result = [@"secret" asCryptedPassUsingScheme: @"md5"
                                     withSalt: [NSData data]
                                  andEncoding: encBase64
                                      keyPath: nil];
  testEquals(result, @"Xr4ilOzQ4PCOq3aQ0qbuaQ==");

  result = [@"secret" asCryptedPassUsingScheme: @"md5" keyPath: nil];
  testEquals(result, @"5ebe2294ecd0e0f08eab7690d2a6ee69");

  result = [@"secret" asCryptedPassUsingScheme: @"ssha" keyPath: nil];
  test([result length] == 40);

  result = [@"secret" asCryptedPassUsingScheme: @"nosuchscheme" keyPath: nil];
  test(result == nil);

  result = [@"secret" asCryptedPassUsingScheme: @"nosuchscheme"
                                     withSalt: [NSData data]
                                  andEncoding: encHex
                                      keyPath: nil];
  test(result == nil);
}

- (void) test_asNTHash
{
  testEquals([@"SOGo" asNTHash], @"6888E6EB2DE017221D138496A1A503E9");
  testEquals([@"123456" asNTHash], @"32ED87BDB5FDC5E9CBA88547376818D4");
}

- (void) test_asLMHash
{
  testEquals([@"SOGo" asLMHash], @"3449A6BB6FCDAA83AAD3B435B51404EE");
}

- (void) test_encodeAES128ECBBase64
{
  NSException *ex;
  NSString *result;

  ex = nil;
  result = [@"secret stuff" encodeAES128ECBBase64: @"0123456789abcdef"
                                      encodedURL: NO exception: &ex];
  testEquals(result, @"r6FEFTwVlIrauKuoq/nOkQ==");
  test(ex == nil);

  ex = nil;
  result = [@"secret stuff" encodeAES128ECBBase64: @"0123456789abcdef"
                                      encodedURL: YES exception: &ex];
  testEquals(result, @"r6FEFTwVlIrauKuoq_nOkQ--");
  test(ex == nil);

  ex = nil;
  result = [@"secret stuff" encodeAES128ECBBase64: @"01234567"
                                      encodedURL: NO exception: &ex];
  test(result == nil);
  testEquals([ex name], @"kAES128ECError");
  testEquals([ex reason], @"Key must be 128 bits, but key has 64 bits");
}

- (void) test_decodeAES128ECBBase64
{
  NSException *ex;
  NSString *result;

  ex = nil;
  result = [@"r6FEFTwVlIrauKuoq/nOkQ==" decodeAES128ECBBase64: @"0123456789abcdef"
                                      encodedURL: NO exception: &ex];
  testEquals(result, @"secret stuff");
  test(ex == nil);

  ex = nil;
  result = [@"r6FEFTwVlIrauKuoq_nOkQ--" decodeAES128ECBBase64: @"0123456789abcdef"
                                      encodedURL: YES exception: &ex];
  testEquals(result, @"secret stuff");
  test(ex == nil);

  ex = nil;
  result = [@"r6FEFTwVlIrauKuoq/nOkQ==" decodeAES128ECBBase64: @"01234567"
                                      encodedURL: NO exception: &ex];
  test(result == nil);
  testEquals([ex name], @"kAES128ECError");
  testEquals([ex reason], @"Key must be 128 bits, but key has 64 bits");

  ex = nil;
  result = [@"AAAAAAAAAAAAAAAAAAAAAA==" decodeAES128ECBBase64: @"0123456789abcdef"
                                      encodedURL: NO exception: &ex];
  test(result == nil);
  testEquals([ex reason], @"Could not decrypt");
}

- (void) test_AES128ECBRoundTrip
{
  NSString *encoded;
  NSString *decoded;

  encoded = [@"round trip payload" encodeAES128ECBBase64: @"0123456789abcdef"
                                             encodedURL: NO exception: NULL];
  decoded = [encoded decodeAES128ECBBase64: @"0123456789abcdef"
                                encodedURL: NO exception: NULL];
  testEquals(decoded, @"round trip payload");

  encoded = [@"round trip payload" encodeAES128ECBBase64: @"0123456789abcdef"
                                             encodedURL: YES exception: NULL];
  decoded = [encoded decodeAES128ECBBase64: @"0123456789abcdef"
                                encodedURL: YES exception: NULL];
  testEquals(decoded, @"round trip payload");

  decoded = [encoded decodeAES128ECBBase64: @"fedcba9876543210"
                                encodedURL: YES exception: NULL];
  test(![decoded isEqualToString: @"round trip payload"]);
}

- (void) test_encryptAES256GCM
{
  NSException *ex;
  NSDictionary *result;
  NSString *key = @"0123456789abcdef0123456789abcdef";

  ex = nil;
  result = [@"secret" encryptAES256GCM: key exception: &ex];
  test(result != nil);
  test(ex == nil);
  test([[result objectForKey: @"cypher"] length] > 0);
  test([[result objectForKey: @"iv"] length] == 16);
  test([[[result objectForKey: @"iv"] dataByDecodingBase64] length] == 12);
  test([[[result objectForKey: @"tag"] dataByDecodingBase64] length] == 16);

  ex = nil;
  result = [@"secret" encryptAES256GCM: @"shortkey" exception: &ex];
  test(result == nil);
  testEquals([ex name], @"kAES256GCMError");
  testEquals([ex reason], @"Key must be 256 bits");
}

- (void) test_decryptAES256GCM
{
  NSException *ex;
  NSDictionary *encrypted;
  NSString *result;
  NSString *key = @"0123456789abcdef0123456789abcdef";

  encrypted = [@"secret" encryptAES256GCM: key exception: NULL];

  ex = nil;
  result = [[encrypted objectForKey: @"cypher"] decryptAES256GCM: key
                                                              iv: [encrypted objectForKey: @"iv"]
                                                             tag: [encrypted objectForKey: @"tag"]
                                                       exception: &ex];
  testEquals(result, @"secret");
  test(ex == nil);

  ex = nil;
  result = [@"garbage" decryptAES256GCM: key
                                     iv: [encrypted objectForKey: @"iv"]
                                    tag: [encrypted objectForKey: @"tag"]
                              exception: &ex];
  test(result == nil);
  testEquals([ex reason], @"Could decrypt but value is null");

  ex = nil;
  result = [[encrypted objectForKey: @"cypher"] decryptAES256GCM: @"shortkey"
                                                              iv: [encrypted objectForKey: @"iv"]
                                                             tag: [encrypted objectForKey: @"tag"]
                                                       exception: &ex];
  test(result == nil);
  testEquals([ex reason], @"Key must be 256 bits");

  ex = nil;
  result = [[encrypted objectForKey: @"cypher"] decryptAES256GCM: key
                                                              iv: @"AAAA"
                                                             tag: [encrypted objectForKey: @"tag"]
                                                       exception: &ex];
  test(result == nil);
  testEquals([ex reason], @"Key must be 96 bits");

  ex = nil;
  result = [[encrypted objectForKey: @"cypher"] decryptAES256GCM: key
                                                              iv: [encrypted objectForKey: @"iv"]
                                                             tag: @"AAAA"
                                                       exception: &ex];
  test(result == nil);
  testEquals([ex reason], @"Tag must be 128 bits");
}

- (void) test_AES256GCMEmptyRoundTrip
{
  NSException *ex;
  NSDictionary *encrypted;
  NSString *result;
  NSString *key = @"0123456789abcdef0123456789abcdef";

  ex = nil;
  encrypted = [@"" encryptAES256GCM: key exception: &ex];
  test(encrypted != nil);
  test(ex == nil);

  ex = nil;
  result = [[encrypted objectForKey: @"cypher"] decryptAES256GCM: key
                                                              iv: [encrypted objectForKey: @"iv"]
                                                             tag: [encrypted objectForKey: @"tag"]
                                                       exception: &ex];
  test(result == nil);
  testEquals([ex reason], @"Could decrypt but value is null");
}

- (void) test_AES256GCMNullRoundTrip
{
  NSException *ex;
  NSDictionary *encrypted;
  NSString *result;
  NSString *nulString;
  unichar nul = 0;

  nulString = [NSString stringWithCharacters: &nul length: 1];
  test([[nulString dataUsingEncoding: NSUTF8StringEncoding] length] == 1);

  ex = nil;
  encrypted = [nulString encryptAES256GCM: @"0123456789abcdef0123456789abcdef" exception: &ex];
  test(encrypted != nil);
  test(ex == nil);

  ex = nil;
  result = [[encrypted objectForKey: @"cypher"] decryptAES256GCM: @"0123456789abcdef0123456789abcdef"
                                                               iv: [encrypted objectForKey: @"iv"]
                                                              tag: [encrypted objectForKey: @"tag"]
                                                        exception: &ex];
  test([result length] == 0);
  test(ex == nil);
}

@end
