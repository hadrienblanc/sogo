/* TestSOGoDraftsFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2026 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2, or (at your option) any later
 * version.
 *
 * This file is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; see the file COPYING.  If not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 */

#import <sys/wait.h>
#import <unistd.h>

#import <string.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSString.h>
#import <Foundation/NSThread.h>

#import <Mailer/SOGoDraftsFolder.h>

#import "SOGoTest.h"

#define DRAFTS_CLASS_NAME @"SOGoDraftsFolder"

#define T6239_THREADS 4
#define T6239_NAMES_PER_THREAD 25

@interface Test6239Collector : NSObject
{
  @private
  NSMutableArray *names;
  NSLock *lock;
}

- (id) init;
- (void) addName: (NSString *) name;
- (NSArray *) allNames;
- (unsigned) count;

@end

@implementation Test6239Collector

- (id) init
{
  if ((self = [super init]))
    {
      names = [[NSMutableArray alloc] init];
      lock = [[NSLock alloc] init];
    }

  return self;
}

- (void) dealloc
{
  [names release];
  [lock release];
  [super dealloc];
}

- (void) addName: (NSString *) name
{
  [lock lock];
  [names addObject: name];
  [lock unlock];
}

- (NSArray *) allNames
{
  NSArray *copy;

  [lock lock];
  copy = [NSArray arrayWithArray: names];
  [lock unlock];

  return copy;
}

- (unsigned) count
{
  unsigned count;

  [lock lock];
  count = [names count];
  [lock unlock];

  return count;
}

@end

@interface Test6239Generator : NSObject
{
  @private
  id folder;
  Test6239Collector *collector;
  unsigned count;
}

- (id) initWithFolder: (id) aFolder
	     collector: (Test6239Collector *) aCollector
		  count: (unsigned) aCount;
- (void) run;

@end

@implementation Test6239Generator

- (id) initWithFolder: (id) aFolder
	     collector: (Test6239Collector *) aCollector
		  count: (unsigned) aCount
{
  if ((self = [super init]))
    {
      folder = [aFolder retain];
      collector = [aCollector retain];
      count = aCount;
    }

  return self;
}

- (void) dealloc
{
  [folder release];
  [collector release];
  [super dealloc];
}

- (void) run
{
  NSAutoreleasePool *pool;
  unsigned i;

  pool = [NSAutoreleasePool new];
  for (i = 0; i < count; i++)
    [collector addName: [folder generateNameForNewDraft]];
  [pool release];
}

@end

@interface TestSOGoDraftsFolder : SOGoTest
{
  id folder;
}

@end

@implementation TestSOGoDraftsFolder

static Class
LoadDraftsClass ()
{
  static Class draftsClass = Nil;

  if (!draftsClass)
    {
      if (![SOGoTest loadSOGoBundle: @"Contacts"
                          markerClass: DRAFTS_CLASS_NAME])
        [SOGoTest loadSOGoBundle: @"Mailer"
                      markerClass: DRAFTS_CLASS_NAME];
      draftsClass = NSClassFromString (DRAFTS_CLASS_NAME);
    }

  return draftsClass;
}

- (void) setUp
{
  Class draftsClass;

  draftsClass = LoadDraftsClass ();
  testWithMessage (draftsClass != Nil,
                   @"SOGoDraftsFolder class unavailable (Mailer.SOGo bundle missing)");
  if (!draftsClass)
    return;

  folder = [[draftsClass alloc] init];
}

- (void) tearDown
{
  [folder release];
  [super tearDown];
}

- (NSArray *) _componentsOfName: (NSString *) name
{
  return [[name substringFromIndex: [@"newDraft" length]]
                   componentsSeparatedByString: @"-"];
}

- (BOOL) _namesShareEpoch: (NSString *) first
		    second: (NSString *) second
{
  return [[[self _componentsOfName: first] objectAtIndex: 0]
            isEqualToString:
              [[self _componentsOfName: second] objectAtIndex: 0]];
}

- (void) test_generateNameForNewDraftFormat
{
  NSString *first, *second;
  NSArray *firstComponents, *secondComponents;
  int attempt;

  for (attempt = 0; attempt < 50; attempt++)
    {
      first = [folder generateNameForNewDraft];
      second = [folder generateNameForNewDraft];
      if ([self _namesShareEpoch: first second: second])
        break;
    }

  testWithMessage ([first hasPrefix: @"newDraft"],
                   @"a new draft name must start with 'newDraft'");
  firstComponents = [self _componentsOfName: first];
  secondComponents = [self _componentsOfName: second];
  test ([firstComponents count] == 3);
  test ([secondComponents count] == 3);

  testWithMessage ([[firstComponents objectAtIndex: 1] intValue]
                     == (int) getpid (),
                   @"the draft name must embed the pid of its sogod worker");
  test ([[firstComponents objectAtIndex: 0] intValue] > 0);
  test ([[firstComponents objectAtIndex: 2] intValue] > 0);

  testWithMessage (![first isEqualToString: second],
                   @"two drafts composed within the same second must not"
                   @" share their name");
  testWithMessage ([self _namesShareEpoch: first second: second],
                   @"the two names must have been generated within the same"
                   @" second");
  test ([[secondComponents objectAtIndex: 2] intValue]
          == ([[firstComponents objectAtIndex: 2] intValue] + 1));
}

- (void) test_generateNameForNewDraftResetsCounterOnNewSecond
{
  NSString *first, *second;
  NSArray *firstComponents, *secondComponents;
  int attempt;

  [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.1]];

  for (attempt = 0; attempt < 50; attempt++)
    {
      first = [folder generateNameForNewDraft];
      second = [folder generateNameForNewDraft];
      if ([self _namesShareEpoch: first second: second])
        break;
    }

  firstComponents = [self _componentsOfName: first];
  secondComponents = [self _componentsOfName: second];

  testWithMessage ([self _namesShareEpoch: first second: second],
                   @"the two names must have been generated within the same"
                   @" second");
  test ([[firstComponents objectAtIndex: 2] intValue] == 1);
  test ([[secondComponents objectAtIndex: 2] intValue] == 2);
}

- (void) test_generateNameForNewDraftIsThreadSafe
{
  Test6239Collector *collector;
  NSArray *allNames;
  NSMutableArray *distinctNames;
  unsigned i;

  collector = [[Test6239Collector alloc] init];
  for (i = 0; i < T6239_THREADS; i++)
    {
      Test6239Generator *generator;

      generator = [[[Test6239Generator alloc] initWithFolder: folder
						    collector: collector
							 count: T6239_NAMES_PER_THREAD]
                    autorelease];
      [NSThread detachNewThreadSelector: @selector (run)
			     toTarget: generator
			       withObject: nil];
    }

  while ([collector count] < (T6239_THREADS * T6239_NAMES_PER_THREAD))
    [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]];

  allNames = [collector allNames];
  distinctNames = [NSMutableArray arrayWithCapacity: [allNames count]];
  for (i = 0; i < [allNames count]; i++)
    if ([distinctNames indexOfObject: [allNames objectAtIndex: i]]
        == NSNotFound)
      [distinctNames addObject: [allNames objectAtIndex: i]];

  testWithMessage ([distinctNames count] == [allNames count],
                   @"concurrent draft creations within one sogod worker"
                   @" must not share names");

  [collector release];
}

- (NSString *) _nameFromForkedChild
{
  NSString *name;
  int fds[2];
  pid_t pid;
  char buffer[512];
  ssize_t count, total;

  name = nil;
  total = 0;

  if (pipe (fds) == 0)
    {
      pid = fork ();
      if (pid == 0)
        {
          NSAutoreleasePool *pool;
          NSString *childName;
          const char *bytes;

          close (fds[0]);
          pool = [NSAutoreleasePool new];
          childName = [folder generateNameForNewDraft];
          bytes = [childName UTF8String];
          if (write (fds[1], bytes, strlen (bytes)) < 0)
            _exit (1);
          if (write (fds[1], "\n", 1) < 0)
            _exit (1);
          [pool release];
          close (fds[1]);
          _exit (0);
        }
      else if (pid > 0)
        {
          int status;

          close (fds[1]);
          while (total < (sizeof (buffer) - 1)
                 && ((count = read (fds[0], buffer + total,
                                    sizeof (buffer) - 1 - total)) > 0))
            total += count;
          close (fds[0]);
          waitpid (pid, &status, 0);
          if (total > 0)
            {
              while (total > 0
                     && (buffer[total - 1] == '\n'
                         || buffer[total - 1] == '\r'))
                total--;
              buffer[total] = '\0';
              name = [NSString stringWithUTF8String: buffer];
            }
        }
    }

  return name;
}

- (void) test_generateNameForNewDraftIsUniqueAcrossProcesses
{
  NSString *first, *second;
  int attempt;

  first = second = nil;
  for (attempt = 0; attempt < 50; attempt++)
    {
      first = [self _nameFromForkedChild];
      second = [self _nameFromForkedChild];
      if ([first length] > 0 && [second length] > 0
          && [[[self _componentsOfName: first] objectAtIndex: 0]
                isEqualToString:
                  [[self _componentsOfName: second] objectAtIndex: 0]])
        break;
    }

  testWithMessage ([first length] > 0 && [second length] > 0,
                   @"the forked workers must report their generated names");
  testWithMessage ([[[self _componentsOfName: first] objectAtIndex: 0]
                     isEqualToString:
                       [[self _componentsOfName: second] objectAtIndex: 0]],
                   @"the two workers must have composed within the same"
                   @" second for the collision check to be meaningful");
  testWithMessage (![first isEqualToString: second],
                   @"two sogod workers composing within the same second"
                   @" must not share a draft name (bug 6239)");
}

@end
