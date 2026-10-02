/* TestNSString+MD5SHA1.m - this file is part of SOGo
 *
 * Copyright (C) 2011, 2012 Jeroen Dekkers
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

#import "SOGo/NSData+Crypto.h"

#import <Foundation/NSFileManager.h>
#import <errno.h>
#import <stdint.h>
#import <string.h>

#import "SOGoTest.h"

extern int _crypt_output_magic(const char *setting, char *output, int size);
extern char *_crypt_blowfish_rn(const char *key, const char *setting,
	char *output, int size);
extern char *_crypt_gensalt_blowfish_rn(const char *prefix, unsigned long count,
	const char *input, int size, char *output, int output_size);
extern int pkcs5_pbkdf2(const char *pass, size_t pass_len, const uint8_t *salt,
	size_t salt_len, uint8_t *key, size_t key_len, unsigned int rounds);

@interface NSString (SOGoAES256GCMTests)
- (NSDictionary *)encryptAES256GCM:(NSString *)passwordScheme exception:(NSException **)ex;
- (NSString *)decryptAES256GCM:(NSString *)passwordScheme iv:(NSString *)ivString tag:(NSString *)tagString exception:(NSException **)ex;
@end

@interface TestNSString_plus_Crypto : SOGoTest
@end

@implementation TestNSString_plus_Crypto

- (void) test_stringCrypto
{
  const char *inStrings[] = { "SOGoSOGoSOGoSOGo", "éléphant", "2š", NULL };
  const char **inString;
  NSString *MD5Strings[] = { @"d3e8072c49511f099d254cc740c7e12a", @"bc6a1535589d6c3cf7999ac37018c11e", @"886ae9b58817fb8a63902feefcd18812" };
  NSString *CramMD5Strings[] = { @"807cf6d4995482060b2e9b1bc3fe1507a42c51dc97d86302b460f7878f0551e2", @"72a6cb4f15711350c3e3d83a9cb631eb0dcc06e56776bed15766e65e0fdb7694",
				@"14bef22dd8c749f6ff3ebbfa51261291e3c1dc42e3dc13ae3771d01de8e53ccd" };
  NSString *SHA1Strings[] = { @"b7d891e0f3b42898fa66627b5cfa3d80501bae46", @"99a02f8802f8ea7e3ad91c4cc4d3ef5a7257c88f", @"32b89f3a9e6078db554cdd39f8571c09de7e8b21" };
  NSString *SHA256Strings[] = { @"3d5c087342ad6208e7f4bc353c5e739dcd14137f6e4159779347fea2e7f562bf", @"c941ae685f62cbe7bb47d0791af7154788fd9e873e5c57fd2449d1454ed5b16f",
				@"f89a911feceaf3d9c28f4e431edff50c265933102476b1814f83704a7bc46890" };
  NSString *SHA512Strings[] = { @"e003b24f05d1b007e5f5a87f726668cb47301d1366cd8d8632646483b1e570335feae34e1e88213a53bab78a876eb805317f290fbf71a1ac79d1275d4a24dee7",
				@"c6f2bb64ee795ad613b4521cd65618d2a036ae6423513a22eddc1bb8a88e5486add61fc1f3a0fc592ce9c24598a23b4ec854f96ccdf73808f701dced2a9b0d64",
				@"49d72f3626d6a56483b3cb4a6da336c423825dbe92d5e225ea2fd69fca1b28d8bceb1544b85847c4fac5c5e0c378b4384f2ac7c230c73dd389061d1b0198c14c" };
  NSString **MD5String;
  NSString **CramMD5String;
  NSString **SHA1String;
  NSString **SHA256String;
  NSString **SHA512String;
  NSData *result;
  NSString *error;

  inString = inStrings;
  CramMD5String = CramMD5Strings;
  MD5String = MD5Strings;
  SHA1String = SHA1Strings;
  SHA256String = SHA256Strings;
  SHA512String = SHA512Strings;
  while (*inString)
    {
      result = [[[NSString stringWithUTF8String: *inString] dataUsingEncoding: NSUTF8StringEncoding] asMD5];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong MD5: '%@' (expected '%@')",
                        *inString, result, *MD5String];
      testWithMessage([[NSData encodeDataAsHexString: result] isEqualToString: *MD5String], error);

      result = [[[NSString stringWithUTF8String: *inString] dataUsingEncoding: NSUTF8StringEncoding] asCramMD5];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong CramMD5: '%@' (expected '%@')",
                        *inString, result, *CramMD5String];
      testWithMessage([[NSData encodeDataAsHexString: result] isEqualToString: *CramMD5String], error);

      result = [[[NSString stringWithUTF8String: *inString] dataUsingEncoding: NSUTF8StringEncoding] asSHA1];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong SHA1: '%@' (expected '%@')",
                        *inString, result, *SHA1String];
      testWithMessage([[NSData encodeDataAsHexString: result] isEqualToString: *SHA1String], error);

      result = [[[NSString stringWithUTF8String: *inString] dataUsingEncoding: NSUTF8StringEncoding] asSHA256];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong SHA256: '%@' (expected '%@')",
                        *inString, result, *SHA256String];
      testWithMessage([[NSData encodeDataAsHexString: result] isEqualToString: *SHA256String], error);

      result = [[[NSString stringWithUTF8String: *inString] dataUsingEncoding: NSUTF8StringEncoding] asSHA512];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong SHA512: '%@' (expected '%@')",
                        *inString, result, *SHA512String];
      testWithMessage([[NSData encodeDataAsHexString: result] isEqualToString: *SHA512String], error);
      inString++;
      MD5String++;
      CramMD5String++;
      SHA1String++;
      SHA256String++;
      SHA512String++;
    }
}

- (void) test_decodeDataFromHexString
{
  NSData *result;

  result = [NSData decodeDataFromHexString: @"00ff10"];
  test([result length] == 3);
  testEquals([NSData encodeDataAsHexString: result], @"00ff10");

  result = [NSData decodeDataFromHexString: @"00FFaB"];
  test([result length] == 3);
  testEquals([NSData encodeDataAsHexString: result], @"00ffab");

  result = [NSData decodeDataFromHexString: @"zz"];
  test(result == nil);

  result = [NSData decodeDataFromHexString: @"0g"];
  test(result == nil);

  result = [NSData decodeDataFromHexString: @"0"];
  test([result length] == 0);
}

- (void) test_generateSaltForLength
{
  NSData *salt;
  NSString *printable;
  const char *allowed = "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
  unsigned int i;

  salt = [NSData generateSaltForLength: 16];
  test([salt length] == 16);

  salt = [NSData generateSaltForLength: 8 withPrintable: YES];
  test([salt length] == 8);
  printable = [[[NSString alloc] initWithData: salt encoding: NSASCIIStringEncoding] autorelease];
  test([printable length] == 8);
  for (i = 0; i < 8; i++)
    test(strchr(allowed, [printable characterAtIndex: i]) != NULL);
}

- (void) test_plainSchemes
{
  NSData *pass = [@"secret" dataUsingEncoding: NSUTF8StringEncoding];

  test([[pass asCryptedPassUsingScheme: @"none" withSalt: [NSData data] keyPath: nil] isEqual: pass]);
  test([[pass asCryptedPassUsingScheme: @"plain" withSalt: [NSData data] keyPath: nil] isEqual: pass]);
  test([[pass asCryptedPassUsingScheme: @"cleartext" withSalt: [NSData data] keyPath: nil] isEqual: pass]);
}

- (void) test_digestSchemes
{
  NSData *pass = [@"secret" dataUsingEncoding: NSUTF8StringEncoding];
  NSData *result;

  result = [pass asCryptedPassUsingScheme: @"md4" withSalt: [NSData data] keyPath: nil];
  testEquals([NSData encodeDataAsHexString: result], @"67d3dafef63ff00603aeef3769cfbf0d");

  result = [pass asCryptedPassUsingScheme: @"md5" withSalt: [NSData data] keyPath: nil];
  testEquals([NSData encodeDataAsHexString: result], @"5ebe2294ecd0e0f08eab7690d2a6ee69");

  result = [pass asCryptedPassUsingScheme: @"plain-md5" withSalt: [NSData data] keyPath: nil];
  testEquals([NSData encodeDataAsHexString: result], @"5ebe2294ecd0e0f08eab7690d2a6ee69");

  result = [pass asCryptedPassUsingScheme: @"ldap-md5" withSalt: [NSData data] keyPath: nil];
  testEquals([NSData encodeDataAsHexString: result], @"5ebe2294ecd0e0f08eab7690d2a6ee69");

  result = [pass asCryptedPassUsingScheme: @"sha" withSalt: [NSData data] keyPath: nil];
  testEquals([NSData encodeDataAsHexString: result], @"e5e9fa1ba31ecd1ae84f75caaa474f3a663f05f4");

  result = [pass asCryptedPassUsingScheme: @"sha256" withSalt: [NSData data] keyPath: nil];
  testEquals([NSData encodeDataAsHexString: result], @"2bb80d537b1da3e38bd30361aa855686bde0eacd7162fef6a25fe97bf527a25b");

  result = [pass asCryptedPassUsingScheme: @"sha512" withSalt: [NSData data] keyPath: nil];
  testEquals([NSData encodeDataAsHexString: result], @"bd2b1aaf7ef4f09be9f52ce2d8d599674d81aa9d6a4421696dc4d93dd0619d682ce56b4d64a9ef097761ced99e0f67265b5f76085e5b0ee7ca4696b2ad6fe2b2");

  result = [pass asCryptedPassUsingScheme: @"cram-md5" withSalt: [NSData data] keyPath: nil];
  testEquals([NSData encodeDataAsHexString: result], @"cd3ba7deaad6e5ca23448ba42e379747a9e0f7f1fbc00c8a81bbaac395731b56");

  result = [[@"1234567890123456789012345678901234567890123456789012345678901234567890123456"
             dataUsingEncoding: NSUTF8StringEncoding] asCramMD5];
  testEquals([NSData encodeDataAsHexString: result], @"b3995a5c4e7743d510d4ac68365fb19baf3b4ecddf824f5676a48c95e68527fb");
}

- (void) test_saltedSchemes
{
  NSData *pass = [@"secret" dataUsingEncoding: NSUTF8StringEncoding];
  NSData *salt = [@"saltsalt" dataUsingEncoding: NSUTF8StringEncoding];
  NSData *result;

  result = [pass asSSHAUsingSalt: [NSData data]];
  test([result length] == 28);
  test([result verifyUsingScheme: @"ssha" withPassword: pass keyPath: nil]);

  result = [pass asSSHAUsingSalt: salt];
  test([result length] == 28);

  result = [pass asSSHA256UsingSalt: [NSData data]];
  test([result length] == 40);
  test([result verifyUsingScheme: @"ssha256" withPassword: pass keyPath: nil]);

  result = [pass asSSHA256UsingSalt: salt];
  test([result length] == 40);

  result = [pass asSSHA512UsingSalt: [NSData data]];
  test([result length] == 72);
  test([result verifyUsingScheme: @"ssha512" withPassword: pass keyPath: nil]);

  result = [pass asSSHA512UsingSalt: salt];
  test([result length] == 72);

  result = [pass asSMD5UsingSalt: [NSData data]];
  test([result length] == 24);
  test([result verifyUsingScheme: @"smd5" withPassword: pass keyPath: nil]);

  result = [pass asSMD5UsingSalt: salt];
  test([result length] == 24);
}

- (void) test_cryptSchemes
{
  NSData *pass = [@"secret" dataUsingEncoding: NSUTF8StringEncoding];
  NSData *salt = [@"saltsalt" dataUsingEncoding: NSUTF8StringEncoding];
  NSData *result;
  NSString *hashed;

  result = [pass asCryptUsingSalt: salt];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed length] == 13);

  result = [pass asCryptUsingSalt: [NSData data]];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed length] == 13);

  result = [pass asCryptUsingSalt: [@"$8$ab" dataUsingEncoding: NSUTF8StringEncoding]];
  test(result == nil);

  result = [pass asCryptedPassUsingScheme: @"crypt" withSalt: salt keyPath: nil];
  test([result length] == 13);

  result = [pass asMD5CryptUsingSalt: salt];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed hasPrefix: @"$1$saltsalt$"]);

  result = [pass asMD5CryptUsingSalt: [NSData data]];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed hasPrefix: @"$1$"]);

  result = [pass asSHA256CryptUsingSalt: salt];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed hasPrefix: @"$5$saltsalt$"]);

  result = [pass asSHA512CryptUsingSalt: salt];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed hasPrefix: @"$6$saltsalt$"]);

  result = [pass asCryptedPassUsingScheme: @"md5-crypt" withSalt: salt keyPath: nil];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed hasPrefix: @"$1$saltsalt$"]);

  result = [pass asCryptedPassUsingScheme: @"sha256-crypt" withSalt: salt keyPath: nil];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed hasPrefix: @"$5$saltsalt$"]);

  result = [pass asCryptedPassUsingScheme: @"sha512-crypt" withSalt: salt keyPath: nil];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed hasPrefix: @"$6$saltsalt$"]);
}

- (void) test_blowfishSalt
{
  NSData *pass = [@"secret" dataUsingEncoding: NSUTF8StringEncoding];
  NSData *result;
  NSString *hashed;

  result = [pass asBlowfishCryptUsingSalt: [@"$2a$05$tLVuFQTgdwrZmixu.QMxoe$"
                                            dataUsingEncoding: NSUTF8StringEncoding]];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  testEquals(hashed, @"$2a$05$tLVuFQTgdwrZmixu.QMxoeR1m.Dy4cPk4VUfE2u2ibBPz/ZDj0.zK");

  result = [pass asCryptedPassUsingScheme: @"blf-crypt"
                                 withSalt: [@"$2a$05$tLVuFQTgdwrZmixu.QMxoe$"
                                            dataUsingEncoding: NSUTF8StringEncoding]
                                  keyPath: nil];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  testEquals(hashed, @"$2a$05$tLVuFQTgdwrZmixu.QMxoeR1m.Dy4cPk4VUfE2u2ibBPz/ZDj0.zK");

  result = [pass asBlowfishCryptUsingSalt: [@"$2a$05$tLVuFQTgdwrZmixu.QMxoe"
                                            dataUsingEncoding: NSUTF8StringEncoding]];
  test(result == nil);

  result = [pass asBlowfishCryptUsingSalt: [@"zzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
                                            dataUsingEncoding: NSUTF8StringEncoding]];
  test(result == nil);

  result = [pass asBlowfishCryptUsingSalt: [@"$2a$05$!!!!!!!!!!!!!!!!!!!!!!"
                                            dataUsingEncoding: NSUTF8StringEncoding]];
  test(result == nil);

  result = [pass asBlowfishCryptUsingSalt: [@"$2a$05$!!!!!!!!!!!!!!!!!!!!!!$"
                                            dataUsingEncoding: NSUTF8StringEncoding]];
  test(result == nil);
}

- (void) test_pbkdf2Salt
{
  NSData *pass = [@"secret" dataUsingEncoding: NSUTF8StringEncoding];
  NSData *result;
  NSString *hashed;

  result = [pass asPBKDF2SHA1UsingSalt: [@"xbhnwhLxltdS9L5M$1" dataUsingEncoding: NSUTF8StringEncoding]];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  testEquals(hashed, @"$1$xbhnwhLxltdS9L5M$1$e4e50a84d8824c8372eca6b09857edcb2f4feab8");

  result = [pass asPBKDF2SHA1UsingSalt: [@"noseparator" dataUsingEncoding: NSUTF8StringEncoding]];
  test(result == nil);

  result = [pass asPBKDF2SHA1UsingSalt: [@"xbhnwhLxltdS9L5M$a$b" dataUsingEncoding: NSUTF8StringEncoding]];
  test(result == nil);

  result = [pass asPBKDF2SHA1UsingSalt: [NSData data]];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed hasPrefix: @"$1$"]);
  test([[[hashed componentsSeparatedByString: @"$"] objectAtIndex: 3] isEqualToString: @"5000"]);

  result = [[@"12345678901234567890123456789012345678901234567890123456789012345678901234567890"
             dataUsingEncoding: NSUTF8StringEncoding]
             asPBKDF2SHA1UsingSalt: [@"xbhnwhLxltdS9L5M$1" dataUsingEncoding: NSUTF8StringEncoding]];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed hasPrefix: @"$1$xbhnwhLxltdS9L5M$1$087798a65132ea4ccc15fbbc91369a019eba63ba"]);
}

#ifdef HAVE_SODIUM
- (void) test_argon2Variants
{
  NSData *pass = [@"secret" dataUsingEncoding: NSUTF8StringEncoding];
  NSData *result;
  NSString *hashed;

  result = [pass asCryptedPassUsingScheme: @"argon2i" withSalt: nil keyPath: nil];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed hasPrefix: @"$argon2i$"]);
  test([result verifyUsingScheme: @"argon2i" withPassword: pass keyPath: nil]);

  result = [pass asCryptedPassUsingScheme: @"argon2" withSalt: nil keyPath: nil];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed hasPrefix: @"$argon2i$"]);

  result = [pass asCryptedPassUsingScheme: @"argon2id" withSalt: nil keyPath: nil];
  hashed = [[[NSString alloc] initWithData: result encoding: NSUTF8StringEncoding] autorelease];
  test([hashed hasPrefix: @"$argon2id$"]);
}
#endif /* HAVE_SODIUM */

- (void) test_symAES128CBC
{
  NSData *pass = [@"secret" dataUsingEncoding: NSUTF8StringEncoding];
  NSString *keyPath = [NSString stringWithFormat: @"%@/cov1-crypto-aes-key", NSTemporaryDirectory()];
  NSData *result;
  NSData *salted;

  [[@"0123456789abcdef" dataUsingEncoding: NSUTF8StringEncoding] writeToFile: keyPath atomically: YES];

  result = [pass asCryptedPassUsingScheme: @"sym-aes-128-cbc"
                                 withSalt: [NSData data] keyPath: keyPath];
  test([result length] > 16);

  salted = [pass asCryptedPassUsingScheme: @"sym-aes-128-cbc"
                                  withSalt: result keyPath: keyPath];
  test([salted isEqual: result]);

  test([result verifyUsingScheme: @"sym-aes-128-cbc" withPassword: pass keyPath: keyPath]);

  [[NSFileManager defaultManager] removeFileAtPath: keyPath handler: nil];
}

- (void) test_verifyUnknownScheme
{
  NSData *pass = [@"secret" dataUsingEncoding: NSUTF8StringEncoding];

  test([pass asCryptedPassUsingScheme: @"nosuchscheme" withSalt: [NSData data] keyPath: nil] == nil);
  test(![pass verifyUsingScheme: @"nosuchscheme" withPassword: pass keyPath: nil]);
}

- (void) test_extractSalt
{
  NSData *result;

  result = [[NSString stringWithFormat: @"$1$"] dataUsingEncoding: NSUTF8StringEncoding];
  test([[result extractSalt: @"md5-crypt"] length] == 0);

  result = [[NSString stringWithFormat: @"$1$%@$", @"salt"] dataUsingEncoding: NSUTF8StringEncoding];
  testEquals([[[NSString alloc] initWithData: [result extractSalt: @"md5-crypt"]
                                   encoding: NSUTF8StringEncoding] autorelease], @"salt");

  result = [[NSString stringWithFormat: @"$1$%@$%@", @"salt", @"hash"] dataUsingEncoding: NSUTF8StringEncoding];
  testEquals([[[NSString alloc] initWithData: [result extractSalt: @"md5-crypt"]
                                   encoding: NSUTF8StringEncoding] autorelease], @"salt");

  result = [@"$6$salt$rounds$hash" dataUsingEncoding: NSUTF8StringEncoding];
  testEquals([[[NSString alloc] initWithData: [result extractSalt: @"sha512-crypt"]
                                   encoding: NSUTF8StringEncoding] autorelease], @"salt$rounds");

  result = [[NSString stringWithFormat: @"$2$%@$%@", @"salt", @"hash"] dataUsingEncoding: NSUTF8StringEncoding];
  test([[result extractSalt: @"md5-crypt"] length] == 0);

  result = [[NSString stringWithFormat: @"$2y$05$%@$%@", @"salt22charsal22chars", @"hash"]
             dataUsingEncoding: NSUTF8StringEncoding];
  testEquals([[[NSString alloc] initWithData: [result extractSalt: @"blf-crypt"]
                                   encoding: NSUTF8StringEncoding] autorelease],
              @"$2y$05$salt22charsal22chars$hash");

  result = [[NSString stringWithFormat: @"$2y$05$%@$%@", @"salt22charsal22chars", @"hash"]
             dataUsingEncoding: NSUTF8StringEncoding];
  testEquals([[[NSString alloc] initWithData: [result extractSalt: @"crypt"]
                                   encoding: NSUTF8StringEncoding] autorelease],
              @"$2y$05$salt22charsal22chars$hash");

  result = [NSMutableData dataWithLength: 28];
  test([[result extractSalt: @"ssha"] length] == 8);

  result = [NSMutableData dataWithLength: 72];
  test([[result extractSalt: @"ssha"] length] == 52);
  test([[result extractSalt: @"ssha256"] length] == 40);
  test([[result extractSalt: @"ssha512"] length] == 8);
  test([[result extractSalt: @"smd5"] length] == 56);
  test([[result extractSalt: @"sym-aes-128-cbc"] length] == 72);
  test([[result extractSalt: @"nosuchscheme"] length] == 0);

  result = [NSMutableData dataWithLength: 0];
  test([[result extractSalt: @"ssha"] length] == 0);
}

- (void) test_cryptOutputMagic
{
  char output[128];
  int rv;

  rv = _crypt_output_magic("$2a$", output, 2);
  test(rv == -1);

  rv = _crypt_output_magic("$2a$", output, sizeof(output));
  test(rv == 0);
  test(strcmp(output, "*0") == 0);

  rv = _crypt_output_magic("*0", output, sizeof(output));
  test(rv == 0);
  test(strcmp(output, "*1") == 0);
}

- (void) test_cryptBlowfishRn
{
  char output[128];
  char *rv;

  rv = _crypt_blowfish_rn("secret", "$2a$05$tLVuFQTgdwrZmixu.QMxoe$", output, sizeof(output));
  test(rv != NULL);
  test(strcmp(rv, "$2a$05$tLVuFQTgdwrZmixu.QMxoeR1m.Dy4cPk4VUfE2u2ibBPz/ZDj0.zK") == 0);

  rv = _crypt_blowfish_rn("secret", "badsetting", output, sizeof(output));
  test(rv == NULL);
  test(errno == EINVAL);
  test(strcmp(output, "*0") == 0);

  rv = _crypt_blowfish_rn("secret", "$2a$05$tLVuFQTgdwrZmixu.QMxoe$", output, 16);
  test(rv == NULL);
  test(errno == ERANGE);

  rv = _crypt_blowfish_rn("secret", "$2a$03$tLVuFQTgdwrZmixu.QMxoe$", output, sizeof(output));
  test(rv == NULL);
  test(errno == EINVAL);

  rv = _crypt_blowfish_rn("secret", "$2a$05$!!!!!!!!!!!!!!!!!!!!!!", output, sizeof(output));
  test(rv == NULL);
  test(errno == EINVAL);

  rv = _crypt_blowfish_rn("secret", "$2c$05$tLVuFQTgdwrZmixu.QMxoe$", output, sizeof(output));
  test(rv == NULL);
  test(errno == EINVAL);

  rv = _crypt_blowfish_rn("secret", "$2a$32$tLVuFQTgdwrZmixu.QMxoe$", output, sizeof(output));
  test(rv == NULL);
  test(errno == EINVAL);
}

- (void) test_cryptGensaltBlowfishRn
{
  char output[128];
  char *rv;

  rv = _crypt_gensalt_blowfish_rn("$2y$", 6, "0123456789abcdef", 16, output, sizeof(output));
  test(rv != NULL);
  test(strcmp(rv, "$2y$06$KBCwKxOzLha2MUDgW0PjXe") == 0);

  rv = _crypt_gensalt_blowfish_rn("$3y$", 5, "0123456789abcdef", 16, output, sizeof(output));
  test(rv == NULL);
  test(errno == EINVAL);

  rv = _crypt_gensalt_blowfish_rn("$2y$", 3, "0123456789abcdef", 16, output, sizeof(output));
  test(rv == NULL);
  test(errno == EINVAL);

  rv = _crypt_gensalt_blowfish_rn("$2y$", 32, "0123456789abcdef", 16, output, sizeof(output));
  test(rv == NULL);
  test(errno == EINVAL);

  rv = _crypt_gensalt_blowfish_rn("$2y$", 5, "0123456789abcdef", 8, output, sizeof(output));
  test(rv == NULL);
  test(errno == EINVAL);

  rv = _crypt_gensalt_blowfish_rn("$2y$", 5, "0123456789abcdef", 16, output, 8);
  test(rv == NULL);
  test(errno == ERANGE);
}

- (void) test_pkcs5Pbkdf2
{
  uint8_t key[40];
  int rv;

  rv = pkcs5_pbkdf2("secret", 6, (const uint8_t *) "salt", 4, key, 20, 0);
  test(rv == -1);

  rv = pkcs5_pbkdf2("secret", 6, (const uint8_t *) "salt", 0, key, 20, 1);
  test(rv == -1);

  rv = pkcs5_pbkdf2("secret", 6, (const uint8_t *) "salt", 4, key, 0, 1);
  test(rv == -1);

  rv = pkcs5_pbkdf2("secret", 6, (const uint8_t *) "salt", 4, key, 20, 1);
  test(rv == 0);
  testEquals([NSData encodeDataAsHexString: [NSData dataWithBytes: key length: 20]],
             @"7f1e61a5c9a702d9e2d320be9353819ca2fcee87");

  rv = pkcs5_pbkdf2("secret", 6, (const uint8_t *) "salt", 4, key, 40, 1);
  test(rv == 0);
  testEquals([NSData encodeDataAsHexString: [NSData dataWithBytes: key length: 40]],
             @"7f1e61a5c9a702d9e2d320be9353819ca2fcee87c1ec39aa1ce90dd1ccba07e5c4f67fb8de40758f");

  rv = pkcs5_pbkdf2("secret", 6, (const uint8_t *) "salt", 4, key, 20, 2);
  test(rv == 0);
  test(![[NSData encodeDataAsHexString: [NSData dataWithBytes: key length: 20]]
           isEqualToString: @"7f1e61a5c9a702d9e2d320be9353819ca2fcee87"]);
}


@end
