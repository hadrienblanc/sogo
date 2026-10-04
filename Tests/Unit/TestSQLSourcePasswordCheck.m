/* TestSQLSourcePasswordCheck.m - this file is part of SOGo
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
 * Free Software Foundation, Inc., 51 Franklin Street,
 * Boston, MA 02110-1301, USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

#import <SOGo/SQLSource.h>

#import "SOGoTest.h"

@interface SQLSource (TestPasswordComparison)
+ (id) sourceFromUDSource: (NSDictionary *) udSource
                  inDomain: (NSString *) domain;
- (BOOL) _isPassword: (NSString *) plainPassword
             equalTo: (NSString *) encryptedPassword;
- (NSString *) _dummyCryptedPassword;
@end

@interface TestSQLSourcePasswordCheck : SOGoTest
{
  SQLSource *blfSource;
  SQLSource *plainSource;
}
@end

@implementation TestSQLSourcePasswordCheck

- (id) init
{
  NSDictionary *udSource;

  if ((self = [super init]))
    {
      udSource = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"test-6040-auth", @"id",
                             @"blf-crypt", @"userPasswordAlgorithm",
                             @"mysql://127.0.0.1/sogo/test_6040_auth", @"viewURL",
                             nil];
      blfSource = [[SQLSource sourceFromUDSource: udSource  inDomain: nil] retain];

      udSource = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"test-6040-plain", @"id",
                             @"plain", @"userPasswordAlgorithm",
                             @"mysql://127.0.0.1/sogo/test_6040_plain", @"viewURL",
                             nil];
      plainSource = [[SQLSource sourceFromUDSource: udSource  inDomain: nil] retain];
    }

  return self;
}

- (void) dealloc
{
  [blfSource release];
  [plainSource release];

  [super dealloc];
}

- (void) test_isPasswordWithMissingHashAnswersNO
{
  test(![blfSource _isPassword: @"wrongsecret" equalTo: nil]);
  test(![blfSource _isPassword: @"SOGoDummyPassword6040" equalTo: nil]);
  test(![blfSource _isPassword: @"" equalTo: nil]);
  test(![plainSource _isPassword: @"SOGoDummyPassword6040" equalTo: nil]);
}

- (void) test_isPasswordWithStoredHashVerifiesPassword
{
  NSString *hash;

  hash = @"{BLF-CRYPT}$2a$05$tLVuFQTgdwrZmixu.QMxoedUAUEeIFIBv89Ur5mQ6F1vBL8Vw1mXO";
  test([blfSource _isPassword: @"123456" equalTo: hash]);
  test(![blfSource _isPassword: @"1234567" equalTo: hash]);
}

- (void) test_dummyCryptedPasswordUsesSourceAlgorithm
{
  test([[blfSource _dummyCryptedPassword] hasPrefix: @"$2y$05$"]);
  testEquals([plainSource _dummyCryptedPassword], @"SOGoDummyPassword6040");
}

- (void) test_missingHashBurnsComparableCryptoWork
{
  NSString *hash, *message;
  NSTimeInterval missingTime, storedTime;
  NSDate *date;
  int i;

  hash = @"{BLF-CRYPT}$2a$05$tLVuFQTgdwrZmixu.QMxoedUAUEeIFIBv89Ur5mQ6F1vBL8Vw1mXO";

  [blfSource _isPassword: @"warmup" equalTo: nil];
  [blfSource _isPassword: @"warmup" equalTo: hash];

  date = [NSDate date];
  for (i = 0; i < 5; i++)
    [blfSource _isPassword: @"wrongsecret" equalTo: nil];
  missingTime = -[date timeIntervalSinceNow];

  date = [NSDate date];
  for (i = 0; i < 5; i++)
    [blfSource _isPassword: @"wrongsecret" equalTo: hash];
  storedTime = -[date timeIntervalSinceNow];

  message = [NSString stringWithFormat:
                       @"missing-hash check (%f s) must burn crypto work "
                       @"comparable to a stored-hash check (%f s)",
                     missingTime, storedTime];
  testWithMessage(missingTime * 4 >= storedTime, message);
}

@end
