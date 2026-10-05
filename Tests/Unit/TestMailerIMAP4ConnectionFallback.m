#import <Foundation/Foundation.h>

#import <Mailer/SOGoMailBaseObject.h>

#import "SOGoTest.h"

@interface SOGoMailBaseObject (Test99999FallbackSupport)
- (id) _connectionFromManager: (id) manager
                          url: (NSURL *) url
                     password: (NSString *) password
         preLoginIDParameters: (NSString *) idParameters;
@end

@interface Test99999ConnectionManagerFake : NSObject
{
  NSString *lastSelector;
  NSURL *lastURL;
  NSString *lastPassword;
  NSString *lastIDParameters;
  id connection;
}

- (id) initWithConnection: (id) aConnection;
- (NSString *) lastSelector;
- (NSURL *) lastURL;
- (NSString *) lastPassword;
- (NSString *) lastIDParameters;
- (id) connectionForURL: (NSURL *) url password: (NSString *) password;

@end

@implementation Test99999ConnectionManagerFake

- (id) initWithConnection: (id) aConnection
{
  if ((self = [super init]))
    connection = [aConnection retain];

  return self;
}

- (void) dealloc
{
  [lastSelector release];
  [lastURL release];
  [lastPassword release];
  [lastIDParameters release];
  [connection release];
  [super dealloc];
}

- (NSString *) lastSelector
{
  return lastSelector;
}

- (NSURL *) lastURL
{
  return lastURL;
}

- (NSString *) lastPassword
{
  return lastPassword;
}

- (NSString *) lastIDParameters
{
  return lastIDParameters;
}

- (id) connectionForURL: (NSURL *) url password: (NSString *) password
{
  ASSIGN (lastSelector, @"connectionForURL:password:");
  ASSIGN (lastURL, url);
  ASSIGN (lastPassword, password);
  ASSIGN (lastIDParameters, nil);

  return connection;
}

@end

@interface Test99999PreLoginManagerFake : Test99999ConnectionManagerFake
- (id) connectionForURL: (NSURL *) url
               password: (NSString *) password
   preLoginIDParameters: (NSString *) idParameters;
@end

@implementation Test99999PreLoginManagerFake

- (id) connectionForURL: (NSURL *) url
               password: (NSString *) password
   preLoginIDParameters: (NSString *) idParameters
{
  ASSIGN (lastSelector, @"connectionForURL:password:preLoginIDParameters:");
  ASSIGN (lastURL, url);
  ASSIGN (lastPassword, password);
  ASSIGN (lastIDParameters, idParameters);

  return connection;
}

@end

@interface TestMailerIMAP4ConnectionFallback : SOGoTest
{
  id baseObject;
}

@end

@implementation TestMailerIMAP4ConnectionFallback

- (void) setUp
{
  Class baseObjectClass;

  baseObject = nil;
  baseObjectClass = ([SOGoTest loadSOGoBundle: @"Mailer"
                                  markerClass: @"SOGoMailBaseObject"]
                     ? NSClassFromString (@"SOGoMailBaseObject")
                     : Nil);
  testWithMessage (baseObjectClass != Nil,
                   @"SOGoMailBaseObject class unavailable (Mailer.SOGo bundle missing)");
  if (baseObjectClass)
    baseObject = [[baseObjectClass alloc] init];
}

- (void) tearDown
{
  [baseObject release];
  [super tearDown];
}

- (void) test_stockManagerFallsBackToPlainConnection
{
  Test99999ConnectionManagerFake *manager;
  id result;

  manager = [[Test99999ConnectionManagerFake alloc] initWithConnection: baseObject];

  result = [baseObject _connectionFromManager: manager
                                          url: [NSURL URLWithString: @"imap://127.0.0.1/"]
                                     password: @"secret"
                         preLoginIDParameters: @"(\"x-originating-ip\" \"127.0.0.1\")"];

  testEquals (result, baseObject);
  testEquals ([manager lastSelector], @"connectionForURL:password:");
  testEquals ([[manager lastURL] absoluteString], @"imap://127.0.0.1/");
  testEquals ([manager lastPassword], @"secret");
  testEquals ([manager lastIDParameters], nil);

  [manager release];
}

- (void) test_patchedManagerUsesPreLoginIDParameters
{
  Test99999PreLoginManagerFake *manager;
  id result;

  manager = [[Test99999PreLoginManagerFake alloc] initWithConnection: baseObject];

  result = [baseObject _connectionFromManager: manager
                                          url: [NSURL URLWithString: @"imap://127.0.0.1/"]
                                     password: @"secret"
                         preLoginIDParameters: @"(\"x-originating-ip\" \"127.0.0.1\")"];

  testEquals (result, baseObject);
  testEquals ([manager lastSelector], @"connectionForURL:password:preLoginIDParameters:");
  testEquals ([[manager lastURL] absoluteString], @"imap://127.0.0.1/");
  testEquals ([manager lastPassword], @"secret");
  testEquals ([manager lastIDParameters], @"(\"x-originating-ip\" \"127.0.0.1\")");

  [manager release];
}

- (void) test_stockManagerWithoutOriginatingIP
{
  Test99999ConnectionManagerFake *manager;
  id result;

  manager = [[Test99999ConnectionManagerFake alloc] initWithConnection: baseObject];

  result = [baseObject _connectionFromManager: manager
                                          url: [NSURL URLWithString: @"imap://127.0.0.1/"]
                                     password: @"secret"
                         preLoginIDParameters: nil];

  testEquals (result, baseObject);
  testEquals ([manager lastSelector], @"connectionForURL:password:");

  [manager release];
}

@end
