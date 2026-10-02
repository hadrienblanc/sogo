/* TestNSString+ActiveSync.m - this file is part of SOGo
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
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#import "NSString+ActiveSync.h"
#import "SOGoTest.h"

@interface TestNSString_plus_ActiveSync : SOGoTest
@end

@implementation TestNSString_plus_ActiveSync

- (void) test_cacheCleanupLogMessageKeepsPrefixAndStatesAutomaticHandling
{
  NSString *message;

  message = [NSString activeSyncCacheCleanupLogMessageForDevice: @"XXX"
                                                           user: @"YYY"
                                                        syncKey: @"195860-155278"
                                                 cachedSyncKey: @"195900-155278"];

  testEquals(message,
    @"Cache cleanup needed for device XXX - user: YYY syncKey: 195860-155278 cache: 195900-155278"
    @" - SOGo initiates the cache cleanup automatically, no administrator action is required");
}

- (void) test_cacheCleanupLogMessageInterpolatesArgumentsInOrder
{
  NSString *message;

  message = [NSString activeSyncCacheCleanupLogMessageForDevice: @"ApplA1B2C3D4E5F6"
                                                           user: @"modir"
                                                        syncKey: @"12-34"
                                                 cachedSyncKey: @"56-78"];

  testEquals(message,
    @"Cache cleanup needed for device ApplA1B2C3D4E5F6 - user: modir syncKey: 12-34 cache: 56-78"
    @" - SOGo initiates the cache cleanup automatically, no administrator action is required");
}

@end
