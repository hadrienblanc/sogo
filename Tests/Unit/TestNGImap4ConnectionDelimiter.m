/* TestNGImap4ConnectionDelimiter.m - this file is part of SOGo
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

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSString.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSURL.h>

#import <NGImap4/NGImap4Client.h>
#import <NGImap4/NGImap4Connection.h>

#include <sys/select.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <string.h>
#include <unistd.h>

#import "SOGoTest.h"

static NSString *Test5912Unquote(NSString *quoted)
{
  if ([quoted length] >= 2 && [quoted hasPrefix: @"\""]
      && [quoted hasSuffix: @"\""])
    return [quoted substringWithRange: NSMakeRange(1, [quoted length] - 2)];

  return quoted;
}

@interface Test5912IMAPServer : NSObject
{
  NSLock *lock;
  NSThread *thread;
  NSMutableArray *recordedSelects;
  NSString *dropAfterCommand;
  BOOL connectionDropped;
  BOOL running;
  int listenerFd;
  int connectionFd;
  unsigned short port;
}

- (void) start;
- (void) stop;
- (unsigned short) port;
- (NSArray *) recordedSelects;
- (void) setDropAfterCommand: (NSString *) command;

@end

@implementation Test5912IMAPServer

- (id) init
{
  if ((self = [super init]))
    {
      lock = [[NSLock alloc] init];
      recordedSelects = [[NSMutableArray alloc] init];
      dropAfterCommand = nil;
      connectionDropped = NO;
      running = NO;
      listenerFd = -1;
      connectionFd = -1;
      port = 0;
    }

  return self;
}

- (void) dealloc
{
  [lock release];
  [recordedSelects release];
  [dropAfterCommand release];
  [thread release];
  [super dealloc];
}

- (unsigned short) port
{
  return port;
}

- (NSArray *) recordedSelects
{
  NSArray *selects;

  [lock lock];
  selects = [NSArray arrayWithArray: recordedSelects];
  [lock unlock];

  return selects;
}

- (void) setDropAfterCommand: (NSString *) command
{
  [lock lock];
  if (command != dropAfterCommand)
    {
      [dropAfterCommand release];
      dropAfterCommand = [command retain];
    }
  [lock unlock];
}

- (void) _recordSelect: (NSString *) arguments
{
  [lock lock];
  [recordedSelects addObject: Test5912Unquote (arguments)];
  [lock unlock];
}

- (BOOL) _shouldDropAfterCommand: (NSString *) command
{
  BOOL drop;

  drop = NO;
  [lock lock];
  if (dropAfterCommand && !connectionDropped
      && [command isEqualToString: dropAfterCommand])
    {
      connectionDropped = YES;
      drop = YES;
    }
  [lock unlock];

  return drop;
}

- (void) _writeTo: (int) fd string: (NSString *) string
{
  const char *bytes;
  NSUInteger length, offset;
  ssize_t count;

  bytes = [string UTF8String];
  length = strlen (bytes);
  offset = 0;
  while (offset < length)
    {
      count = send (fd, bytes + offset, length - offset, 0);
      if (count <= 0)
        return;
      offset += count;
    }
}

- (NSString *) _readLineFrom: (int) fd buffer: (NSMutableData *) buffer
{
  while (YES)
    {
      const char *bytes;
      NSUInteger length, index;

      bytes = [buffer bytes];
      length = [buffer length];
      for (index = 0; index < length; index++)
        if (bytes[index] == '\n')
          {
            NSString *line;
            NSUInteger lineLength;

            lineLength = (index > 0 && bytes[index - 1] == '\r')
              ? index - 1
              : index;
            line = [[[NSString alloc] initWithBytes: bytes
                                             length: lineLength
                                           encoding: NSUTF8StringEncoding]
                      autorelease];
            [buffer replaceBytesInRange: NSMakeRange (0, index + 1)
                              withBytes: ""
                                 length: 0];
            return line;
          }

      {
        char chunk[4096];
        ssize_t count;

        count = recv (fd, chunk, sizeof (chunk), 0);
        if (count <= 0)
          return nil;
        [buffer appendBytes: chunk length: count];
      }
    }
}

- (void) _handleConnection: (int) fd
{
  NSMutableData *buffer;
  NSString *line;

  [lock lock];
  connectionFd = fd;
  [lock unlock];

  buffer = [[NSMutableData alloc] init];
  [self _writeTo: fd string: @"* OK TestNGImap4ConnectionDelimiter ready\r\n"];

  while ((line = [self _readLineFrom: fd buffer: buffer]))
    {
      NSArray *parts;
      NSString *tag, *command, *arguments;

      parts = [line componentsSeparatedByString: @" "];
      tag = [parts objectAtIndex: 0];
      command = ([parts count] > 1)
        ? [[parts objectAtIndex: 1] uppercaseString]
        : @"";
      arguments = ([parts count] > 2)
        ? [[parts subarrayWithRange: NSMakeRange (2, [parts count] - 2)]
            componentsJoinedByString: @" "]
        : @"";

      if ([command isEqualToString: @"SELECT"]
          || [command isEqualToString: @"EXAMINE"])
        {
          [self _recordSelect: arguments];
          [self _writeTo: fd string:
                           @"* 42 EXISTS\r\n"
                           @"* OK [UIDVALIDITY 1] UIDs valid\r\n"
                           @"* OK [UIDNEXT 43] next uid\r\n"
                           @"* FLAGS (\\Answered \\Flagged \\Seen)\r\n"];
          [self _writeTo: fd string:
                     [NSString stringWithFormat: @"%@ OK [READ-WRITE] SELECT completed\r\n", tag]];
        }
      else if ([command isEqualToString: @"LIST"]
               || [command isEqualToString: @"LSUB"])
        {
          if ([arguments isEqualToString: @"\"\" \"\""])
            [self _writeTo: fd string: @"* LIST (\\Noselect) \".\" \"\"\r\n"];
          else
            [self _writeTo: fd string: @"* LIST (\\HasNoChildren) \".\" \"INBOX\"\r\n"];
          [self _writeTo: fd string:
                     [NSString stringWithFormat: @"%@ OK LIST completed\r\n", tag]];
        }
      else if ([command isEqualToString: @"LOGIN"]
               || [command isEqualToString: @"AUTHENTICATE"])
        [self _writeTo: fd string:
                   [NSString stringWithFormat: @"%@ OK LOGIN completed\r\n", tag]];
      else if ([command isEqualToString: @"CAPABILITY"])
        {
          [self _writeTo: fd string: @"* CAPABILITY IMAP4rev1 LITERAL+\r\n"];
          [self _writeTo: fd string:
                     [NSString stringWithFormat: @"%@ OK CAPABILITY completed\r\n", tag]];
        }
      else if ([command isEqualToString: @"LOGOUT"])
        {
          [self _writeTo: fd string: @"* BYE TestNGImap4ConnectionDelimiter out\r\n"];
          [self _writeTo: fd string:
                     [NSString stringWithFormat: @"%@ OK LOGOUT completed\r\n", tag]];
          break;
        }
      else
        [self _writeTo: fd string:
                   [NSString stringWithFormat: @"%@ OK %@ completed\r\n", tag, command]];

      if ([self _shouldDropAfterCommand: command])
        break;
    }

  [lock lock];
  connectionFd = -1;
  [lock unlock];

  close (fd);
  [buffer release];
}

- (void) _serve
{
  while (running)
    {
      fd_set readFds;
      struct timeval timeout;
      int fd;

      FD_ZERO (&readFds);
      FD_SET (listenerFd, &readFds);
      timeout.tv_sec = 0;
      timeout.tv_usec = 200000;
      if (select (listenerFd + 1, &readFds, NULL, NULL, &timeout) <= 0)
        continue;

      fd = accept (listenerFd, NULL, NULL);
      if (fd >= 0)
        {
          NSAutoreleasePool *pool;

          pool = [[NSAutoreleasePool alloc] init];
          [self _handleConnection: fd];
          [pool release];
        }
    }
}

- (void) start
{
  struct sockaddr_in address;
  socklen_t addressLength;

  listenerFd = socket (AF_INET, SOCK_STREAM, 0);
  if (listenerFd < 0)
    [NSException raise: @"TestNGImap4ConnectionDelimiter"
                format: @"could not create listening socket"];

  memset (&address, 0, sizeof (address));
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl (INADDR_LOOPBACK);
  address.sin_port = 0;

  if (bind (listenerFd, (struct sockaddr *) &address, sizeof (address)) < 0)
    [NSException raise: @"TestNGImap4ConnectionDelimiter"
                format: @"could not bind listening socket"];
  if (listen (listenerFd, 8) < 0)
    [NSException raise: @"TestNGImap4ConnectionDelimiter"
                format: @"could not listen on socket"];

  addressLength = sizeof (address);
  if (getsockname (listenerFd, (struct sockaddr *) &address,
                   &addressLength) < 0)
    [NSException raise: @"TestNGImap4ConnectionDelimiter"
                format: @"could not resolve listening port"];
  port = ntohs (address.sin_port);

  running = YES;
  thread = [[NSThread alloc] initWithTarget: self
                                   selector: @selector (_serve)
                                       object: nil];
  [thread start];
}

- (void) stop
{
  NSDate *deadline;
  int fd;

  if (!running)
    return;

  running = NO;

  [lock lock];
  fd = connectionFd;
  [lock unlock];
  if (fd >= 0)
    shutdown (fd, SHUT_RDWR);

  shutdown (listenerFd, SHUT_RDWR);
  close (listenerFd);
  listenerFd = -1;

  deadline = [NSDate dateWithTimeIntervalSinceNow: 10.0];
  while (![thread isFinished]
         && ([deadline timeIntervalSinceNow] > 0))
    [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
}

@end

@interface TestNGImap4ConnectionDelimiter : SOGoTest
{
  Test5912IMAPServer *server;
}

@end

@implementation TestNGImap4ConnectionDelimiter

- (void) setUp
{
  server = [[Test5912IMAPServer alloc] init];
  [server start];
}

- (void) tearDown
{
  [server stop];
  [server release];
}

- (NGImap4Connection *) _connection
{
  NGImap4Client *client;
  NSDictionary *login;

  client = [NGImap4Client clientWithURL:
                      [NSURL URLWithString:
                                [NSString stringWithFormat: @"imap://user@127.0.0.1:%u/?tls=NO",
                                          [server port]]]];
  login = [client login: @"user" password: @"pass"];
  failIf (![[login objectForKey: @"result"] boolValue]);

  return [[[NGImap4Connection alloc] initWithClient: client
                                           password: @"pass"] autorelease];
}

- (NSURL *) _folderURLForPath: (NSString *) path
{
  return [NSURL URLWithString:
            [NSString stringWithFormat: @"imap://user@127.0.0.1:%u/%@?tls=NO",
                                           [server port], path]];
}

- (void) _assertEverySelectIs: (NSString *) wireName
{
  NSEnumerator *enumerator;
  NSString *recorded;
  NSArray *selects;

  selects = [server recordedSelects];
  test ([selects count] > 0);
  enumerator = [selects objectEnumerator];
  while ((recorded = [enumerator nextObject]))
    testEquals (recorded, wireName);
}

- (void) test_selectFolderConvertsURLPathToServerDelimiter
{
  NGImap4Connection *connection;

  connection = [self _connection];
  failIf (![connection selectFolder: [self _folderURLForPath: @"INBOX/Tevi/"]]);

  [self _assertEverySelectIs: @"INBOX.Tevi"];
}

- (void) test_selectFolderKeepsDelimiterAfterServerDrop
{
  NGImap4Connection *connection;

  [server setDropAfterCommand: @"LIST"];

  connection = [self _connection];
  failIf (![connection selectFolder: [self _folderURLForPath: @"INBOX/Tevi/"]]);

  [self _assertEverySelectIs: @"INBOX.Tevi"];
}

- (void) test_selectFolderPreservesModifiedUTF7MailboxNames
{
  NGImap4Connection *connection;

  connection = [self _connection];
  failIf (![connection selectFolder:
                     [self _folderURLForPath: @"Travail/ValueIT/Sant%26AOk-/"]]);

  [self _assertEverySelectIs: @"Travail.ValueIT.Sant&AOk-"];
}

@end
