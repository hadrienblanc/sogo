#import <Foundation/Foundation.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSValue.h>

#import <sys/stat.h>
#import <unistd.h>
#import <string.h>
#import <stdio.h>

#import <NGMime/NGMimeBodyPart.h>
#import <NGMime/NGMimeMultipartBody.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSNull+Utilities.h>
#import <SOGo/NSNumber+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/SOGoUser.h>

#import "SOGoTest.h"

@interface StubDOMNode : NSObject <DOMNode>
{
  DOMNodeType nodeTypeValue;
  StubDOMNode *next;
  StubDOMNode *child;
}
+ (StubDOMNode *) nodeWithType: (DOMNodeType) type
		    nextSibling: (StubDOMNode *) nextSibling;
@end

@implementation StubDOMNode

+ (StubDOMNode *) nodeWithType: (DOMNodeType) type
		    nextSibling: (StubDOMNode *) nextSibling
{
  StubDOMNode *node;

  node = [[StubDOMNode new] autorelease];
  node->nodeTypeValue = type;
  node->next = [nextSibling retain];

  return node;
}

- (void) dealloc
{
  [next release];
  [child release];
  [super dealloc];
}

- (void) setChild: (StubDOMNode *) newChild
{
  ASSIGN (child, newChild);
}

- (DOMNodeType) nodeType
{
  return nodeTypeValue;
}

- (NSString *) nodeName
{
  return @"stub";
}

- (NSString *) nodeValue
{
  return nil;
}

- (NSString *) localName
{
  return @"stub";
}

- (NSString *) namespaceURI
{
  return nil;
}

- (void) setPrefix: (NSString *) prefix
{
}

- (NSString *) prefix
{
  return nil;
}

- (id<NSObject, DOMNamedNodeMap>) attributes
{
  return nil;
}

- (id<NSObject, DOMNode>) parentNode
{
  return nil;
}

- (id<NSObject, DOMNode>) previousSibling
{
  return nil;
}

- (id<NSObject, DOMNode>) nextSibling
{
  return next;
}

- (id<NSObject, DOMNodeList>) childNodes
{
  return nil;
}

- (BOOL) hasChildNodes
{
  return (child != nil);
}

- (id<NSObject, DOMNode>) firstChild
{
  return child;
}

- (id<NSObject, DOMNode>) lastChild
{
  return child;
}

- (id<NSObject, DOMNode>) appendChild: (id<NSObject, DOMNode>) node
{
  return nil;
}

- (id<NSObject, DOMNode>) removeChild: (id<NSObject, DOMNode>) node
{
  return nil;
}

- (IDOMDocument) ownerDocument
{
  return nil;
}

@end

@interface StubRequest : NSObject
{
  NSArray *browserLanguagesValue;
}
+ (StubRequest *) requestWithLanguages: (NSArray *) languages;
@end

@implementation StubRequest

+ (StubRequest *) requestWithLanguages: (NSArray *) languages
{
  StubRequest *request;

  request = [[StubRequest new] autorelease];
  request->browserLanguagesValue = [languages retain];

  return request;
}

- (void) dealloc
{
  [browserLanguagesValue release];
  [super dealloc];
}

- (NSArray *) browserLanguages
{
  return browserLanguagesValue;
}

@end

@interface StubContext : NSObject
{
  id activeUserValue;
  StubRequest *requestValue;
}
+ (StubContext *) contextWithUser: (id) user
			  request: (StubRequest *) request;
@end

@implementation StubContext

+ (StubContext *) contextWithUser: (id) user
			  request: (StubRequest *) request
{
  StubContext *context;

  context = [[StubContext new] autorelease];
  context->activeUserValue = [user retain];
  context->requestValue = [request retain];

  return context;
}

- (void) dealloc
{
  [activeUserValue release];
  [requestValue release];
  [super dealloc];
}

- (id) activeUser
{
  return activeUserValue;
}

- (id) request
{
  return requestValue;
}

@end

@interface StubUserPreferences : NSObject
- (NSString *) language;
@end

@implementation StubUserPreferences

- (NSString *) language
{
  return @"English";
}

@end

@interface StubSOGoUser : SOGoUser
- (id) init;
- (SOGoUserDefaults *) userDefaults;
@end

@implementation StubSOGoUser

- (id) init
{
  self = [super initWithLogin: @"anonymous" roles: nil trust: YES];

  return self;
}

- (SOGoUserDefaults *) userDefaults
{
  return (SOGoUserDefaults *) [[StubUserPreferences new] autorelease];
}

@end

__attribute__((constructor))
static void EnsureLabelResources (void)
{
  static const char *roots[] = { "Resources/sogo-tests", "obj/Resources/sogo-tests", NULL };
  static const char *content = "greeting = HelloLabel;\nworld = WorldLabel;\n";
  char path[4096];
  char cwd[2048];
  FILE *file;
  int i;

  if (getcwd (cwd, sizeof (cwd)) == NULL)
    return;
  for (i = 0; roots[i] != NULL; i++)
    {
      snprintf (path, sizeof (path), "%s/%s", cwd, roots[i]);
      mkdir ("Resources", 0755);
      mkdir ("obj", 0755);
      mkdir ("obj/Resources", 0755);
      mkdir (path, 0755);
      strcat (path, "/English.lproj");
      mkdir (path, 0755);
      strcat (path, "/Localizable.strings");
      file = fopen (path, "w");
      if (file)
        {
          fputs (content, file);
          fclose (file);
        }
    }
}

@interface TestContainerUtilities : SOGoTest
@end

@implementation TestContainerUtilities

- (void) test_arrayWithObjectRepeatCount
{
  NSArray *array;

  array = [NSArray arrayWithObject: @"x" repeatCount: 3];
  failIf([array count] != 3);
  testEquals([array objectAtIndex: 0], @"x");
  testEquals([array objectAtIndex: 2], @"x");

  array = [NSArray arrayWithObject: @"x" repeatCount: 0];
  failIf([array count] != 0);
}

- (void) test_asPointersOfObjects
{
  NSArray *array;
  id *pointers;

  array = [NSArray arrayWithObjects: @"a", @"b", nil];
  pointers = [array asPointersOfObjects];
  testEquals(pointers[0], @"a");
  testEquals(pointers[1], @"b");
  test(pointers[2] == nil);
  NSZoneFree (NULL, pointers);
}

- (void) test_stringsWithFormat
{
  NSArray *array;
  NSArray *result;

  array = [NSArray arrayWithObjects: @"a", [NSNull null], @"b", nil];
  result = [array stringsWithFormat: @"<%@>"];
  failIf([result count] != 3);
  testEquals([result objectAtIndex: 0], @"<a>");
  testEquals([result objectAtIndex: 1], @"");
  testEquals([result objectAtIndex: 2], @"<b>");

  result = [[NSArray array] stringsWithFormat: @"%@"];
  failIf([result count] != 0);
}

- (void) test_arrayKeysWithFormat
{
  NSArray *array;
  NSArray *result;

  array = [NSArray arrayWithObjects:
                    [NSDictionary dictionaryWithObject: @"A" forKey: @"k"],
                    [NSDictionary dictionaryWithObject: @"B" forKey: @"k"],
                    nil];
  result = [array keysWithFormat: @"[%{k}]"];
  failIf([result count] != 2);
  testEquals([result objectAtIndex: 0], @"[A]");
  testEquals([result objectAtIndex: 1], @"[B]");
}

- (void) test_objectsForKeyNotFoundMarker
{
  NSArray *array;
  NSArray *result;

  array = [NSArray arrayWithObjects:
                    [NSDictionary dictionaryWithObject: @"v1" forKey: @"k"],
                    [NSDictionary dictionary],
                    [NSDictionary dictionaryWithObject: @"v2" forKey: @"k"],
                    nil];

  result = [array objectsForKey: @"k" notFoundMarker: nil];
  failIf([result count] != 2);
  testEquals([result objectAtIndex: 0], @"v1");
  testEquals([result objectAtIndex: 1], @"v2");

  result = [array objectsForKey: @"k" notFoundMarker: @"marker"];
  failIf([result count] != 3);
  testEquals([result objectAtIndex: 0], @"v1");
  testEquals([result objectAtIndex: 1], @"marker");
  testEquals([result objectAtIndex: 2], @"v2");
}

- (void) test_flattenedArray
{
  NSArray *array;
  NSArray *result;

  array = [NSArray arrayWithObjects:
                    [NSArray arrayWithObjects: @"a", @"b", nil],
                    @"c",
                    [NSArray arrayWithObject: [NSArray arrayWithObject: @"d"]],
                    nil];
  result = [array flattenedArray];
  failIf([result count] != 4);
  testEquals([result objectAtIndex: 0], @"a");
  testEquals([result objectAtIndex: 1], @"b");
  testEquals([result objectAtIndex: 2], @"c");
  testEquals([result objectAtIndex: 3], @"d");

  result = [[NSArray array] flattenedArray];
  failIf([result count] != 0);
}

- (void) test_flattenedDictionaries
{
  NSArray *array;
  NSDictionary *result;

  array = [NSArray arrayWithObjects:
                    [NSDictionary dictionaryWithObject: @"1" forKey: @"a"],
                    [NSDictionary dictionaryWithObject: @"2" forKey: @"b"],
                    nil];
  result = [array flattenedDictionaries];
  failIf([result count] != 2);
  testEquals([result objectForKey: @"a"], @"1");
  testEquals([result objectForKey: @"b"], @"2");
}

- (void) test_uniqueObjects
{
  NSArray *array;
  NSArray *result;

  array = [NSArray arrayWithObjects: @"a", @"b", @"a", @"c", @"b", nil];
  result = [array uniqueObjects];
  failIf([result count] != 3);
  failIf(![result containsObject: @"a"]);
  failIf(![result containsObject: @"b"]);
  failIf(![result containsObject: @"c"]);
}

- (void) test_trimmedComponents
{
  NSArray *array;
  NSArray *result;

  array = [NSArray arrayWithObjects: @"  a  ", @"b\t", nil];
  result = [array trimmedComponents];
  failIf([result count] != 2);
  testEquals([result objectAtIndex: 0], @"a");
  testEquals([result objectAtIndex: 1], @"b");
}

- (void) test_makeObjectsPerformWithObjectWithObject
{
  NSMutableArray *array;
  NSMutableDictionary *dict1;
  NSMutableDictionary *dict2;

  dict1 = [NSMutableDictionary dictionary];
  dict2 = [NSMutableDictionary dictionary];
  array = [NSMutableArray arrayWithObjects: dict1, dict2, nil];
  [array makeObjectsPerform: @selector (setObject:forKey:)
                 withObject: @"V"
                 withObject: @"k"];
  testEquals([dict1 objectForKey: @"k"], @"V");
  testEquals([dict2 objectForKey: @"k"], @"V");
}

- (void) test_resultsOfSelector
{
  NSArray *array;
  NSArray *result;

  array = [NSArray arrayWithObjects: @"abc", @"dEf", nil];
  result = [array resultsOfSelector: @selector (uppercaseString)];
  failIf([result count] != 2);
  testEquals([result objectAtIndex: 0], @"ABC");
  testEquals([result objectAtIndex: 1], @"DEF");
}

- (void) test_mergedArrayWithArray
{
  NSArray *array;
  NSArray *result;

  array = [NSArray arrayWithObjects: @"a", @"b", nil];
  result = [array mergedArrayWithArray: [NSArray arrayWithObjects: @"b", @"c", nil]];
  failIf([result count] != 3);
  testEquals([result objectAtIndex: 0], @"a");
  testEquals([result objectAtIndex: 1], @"b");
  testEquals([result objectAtIndex: 2], @"c");

  result = [array mergedArrayWithArray: [NSArray array]];
  failIf([result count] != 2);
  testEquals([result objectAtIndex: 0], @"a");
}

- (void) test_arrayJsonRepresentation
{
  NSArray *array;
  NSArray *nested;

  array = [NSArray arrayWithObjects: @"a", [NSNumber numberWithInt: 1],
                    [NSNull null], nil];
  testEquals([array jsonRepresentation], @"[\"a\", 1, null]");

  testEquals([[NSArray array] jsonRepresentation], @"[]");

  nested = [NSArray arrayWithObject: [NSArray arrayWithObject: @"x"]];
  testEquals([nested jsonRepresentation], @"[[\"x\"]]");
}

- (void) test_containsCaseInsensitiveString
{
  NSArray *array;

  array = [NSArray arrayWithObjects: @"Foo", @"BAR", nil];
  failIf(![array containsCaseInsensitiveString: @"bar"]);
  failIf(![array containsCaseInsensitiveString: @"FOO"]);
  failIf([array containsCaseInsensitiveString: @"nope"]);
}

- (void) test_addNonNSObjectWithSizeCopy
{
  typedef struct
  {
    int x;
    double y;
  } TestStruct;
  TestStruct value;
  TestStruct *heapValue;
  TestStruct *copied;
  NSMutableArray *array;

  value.x = 42;
  value.y = 1.5;
  heapValue = NSZoneMalloc (NULL, sizeof (TestStruct));
  *heapValue = value;

  array = [NSMutableArray array];
  [array addNonNSObject: &value withSize: sizeof (TestStruct) copy: YES];
  [array addNonNSObject: heapValue withSize: sizeof (TestStruct) copy: NO];

  copied = [[array objectAtIndex: 0] pointerValue];
  test(copied != &value);
  failIf(copied->x != value.x);
  failIf(copied->y != value.y);
  test([[array objectAtIndex: 1] pointerValue] == heapValue);

  [array freeNonNSObjects];
}

- (void) test_addObjectUniquely
{
  NSMutableArray *array;

  array = [NSMutableArray array];
  [array addObjectUniquely: @"a"];
  [array addObjectUniquely: @"a"];
  [array addObjectUniquely: @"b"];
  failIf([array count] != 2);
  testEquals([array objectAtIndex: 0], @"a");
  testEquals([array objectAtIndex: 1], @"b");
}

- (void) test_hasRangeIntersection
{
  NSRange *inside;
  NSRange *outside;
  NSRange *spanning;
  NSArray *array;

  inside = NSZoneMalloc (NULL, sizeof (NSRange));
  *inside = NSMakeRange (0, 5);
  array = [NSMutableArray arrayWithObject: [NSValue valueWithPointer: inside]];
  failIf(![array hasRangeIntersection: NSMakeRange (3, 1)]);
  failIf([array hasRangeIntersection: NSMakeRange (8, 2)]);
  NSZoneFree (NULL, inside);

  outside = NSZoneMalloc (NULL, sizeof (NSRange));
  *outside = NSMakeRange (10, 5);
  array = [NSMutableArray arrayWithObject: [NSValue valueWithPointer: outside]];
  failIf(![array hasRangeIntersection: NSMakeRange (8, 10)]);
  NSZoneFree (NULL, outside);

  spanning = NSZoneMalloc (NULL, sizeof (NSRange));
  *spanning = NSMakeRange (0, 100);
  array = [NSMutableArray arrayWithObject: [NSValue valueWithPointer: spanning]];
  failIf(![array hasRangeIntersection: NSMakeRange (10, 5)]);
  failIf([array hasRangeIntersection: NSMakeRange (200, 5)]);
  NSZoneFree (NULL, spanning);
}

- (void) test_removeDoubles
{
  NSMutableArray *array;

  array = [NSMutableArray arrayWithObjects: @"a", @"b", @"a", @"c", @"b", nil];
  [array removeDoubles];
  failIf([array count] != 3);
  failIf(![array containsObject: @"a"]);
  failIf(![array containsObject: @"b"]);
  failIf(![array containsObject: @"c"]);
}

- (void) test_dictionaryFromStringsFile
{
  NSString *path;
  NSDictionary *dict;

  path = @"obj/TestContainerUtilities.strings";
  [[NSString stringWithCString: "greeting = HelloLabel;\nworld = WorldLabel;\n"
		       encoding: NSUTF8StringEncoding]
    writeToFile: path atomically: YES];
  dict = [NSDictionary dictionaryFromStringsFile: path];
  failIf(dict == nil);
  testEquals([dict objectForKey: @"greeting"], @"HelloLabel");
  testEquals([dict objectForKey: @"world"], @"WorldLabel");
}

- (void) test_dictionaryJsonRepresentation
{
  NSDictionary *dict;

  dict = [NSDictionary dictionaryWithObject: @"v" forKey: @"k"];
  testEquals([dict jsonRepresentation], @"{\"k\":\"v\"}");

  dict = [NSDictionary dictionaryWithObject: [NSNull null] forKey: @"k"];
  testEquals([dict jsonRepresentation], @"{\"k\":null}");

  dict = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: 1] forKey: @"k"];
  testEquals([dict jsonRepresentation], @"{\"k\":1}");

  dict = [NSDictionary dictionaryWithObject: [NSNumber numberWithBool: YES] forKey: @"k"];
  testEquals([dict jsonRepresentation], @"{\"k\":true}");

  dict = [NSDictionary dictionaryWithObject: [NSArray arrayWithObjects: @"a", nil]
                                     forKey: @"k"];
  testEquals([dict jsonRepresentation], @"{\"k\":[\"a\"]}");

  dict = [NSDictionary dictionaryWithObject: [NSDictionary dictionaryWithObject: @"x" forKey: @"y"]
                                     forKey: @"k"];
  testEquals([dict jsonRepresentation], @"{\"k\":{\"y\":\"x\"}}");

  testEquals([[NSDictionary dictionary] jsonRepresentation], @"{}");
}

- (void) test_dictionaryKeysWithFormat
{
  NSDictionary *dict;

  dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"v1", @"k1",
                          [NSNull null], @"k2",
                          [NSNumber numberWithInt: 7], @"k3",
                          nil];
  testEquals([dict keysWithFormat: @"K1=%{k1} K2=%{k2} K3=%{k3}"],
             @"K1=v1 K2= K3=7");
  testEquals([dict keysWithFormat: @"no placeholder"],
             @"no placeholder");
}

- (void) test_caseInsensitiveDisplayNameCompare
{
  NSDictionary *dict1;
  NSDictionary *dict2;

  dict1 = [NSDictionary dictionaryWithObject: @"alice" forKey: @"cn"];
  dict2 = [NSDictionary dictionaryWithObject: @"Bob" forKey: @"cn"];
  failIf([dict1 caseInsensitiveDisplayNameCompare: dict2] != NSOrderedAscending);
  failIf([dict2 caseInsensitiveDisplayNameCompare: dict1] != NSOrderedDescending);
  failIf([dict1 caseInsensitiveDisplayNameCompare: dict1] != NSOrderedSame);
}

- (void) test_setObjectForKeys
{
  NSMutableDictionary *dict;

  dict = [NSMutableDictionary dictionary];
  [dict setObject: @"V" forKeys: [NSArray arrayWithObjects: @"k1", @"k2", nil]];
  failIf([dict count] != 2);
  testEquals([dict objectForKey: @"k1"], @"V");
  testEquals([dict objectForKey: @"k2"], @"V");

  [dict setObject: @"V" forKeys: [NSArray array]];
  failIf([dict count] != 2);
}

- (void) test_setObjectsForKeys
{
  NSMutableDictionary *dict;

  dict = [NSMutableDictionary dictionary];
  [dict setObjects: [NSArray arrayWithObjects: @"v1", @"v2", nil]
            forKeys: [NSArray arrayWithObjects: @"k1", @"k2", nil]];
  failIf([dict count] != 2);
  testEquals([dict objectForKey: @"k1"], @"v1");
  testEquals([dict objectForKey: @"k2"], @"v2");

  [dict setObjects: [NSArray array] forKeys: [NSArray array]];
  failIf([dict count] != 2);
}

- (void) test_setObjectsForKeysRaises
{
  BOOL raised;
  NSMutableDictionary *dict;

  dict = [NSMutableDictionary dictionary];
  raised = NO;
  NS_DURING
    {
      [dict setObjects: [NSArray arrayWithObjects: @"v1", @"v2", nil]
	       forKeys: [NSArray arrayWithObjects: @"k1", nil]];
    }
  NS_HANDLER
    {
      raised = YES;
      testEquals([localException name], NSInvalidArgumentException);
    }
  NS_ENDHANDLER;
  failIf(!raised);
  failIf([dict count] != 0);
}

- (void) test_nullJsonRepresentation
{
  testEquals([[NSNull null] jsonRepresentation], @"null");
}

- (void) test_numberJsonRepresentation
{
  testEquals([[NSNumber numberWithInt: 42] jsonRepresentation], @"42");
  testEquals([[NSNumber numberWithDouble: 1.5] jsonRepresentation], @"1.5");
  testEquals([[NSNumber numberWithBool: YES] jsonRepresentation], @"true");
  testEquals([[NSNumber numberWithBool: NO] jsonRepresentation], @"false");
}

- (void) test_objectJsonRepresentationRaises
{
  BOOL raised;
  id object;

  object = [NSObject new];
  raised = NO;
  NS_DURING
    {
      [object jsonRepresentation];
    }
  NS_HANDLER
    {
      raised = YES;
      testEquals([localException name], NSInvalidArgumentException);
    }
  NS_ENDHANDLER;
  failIf(!raised);
  [object release];
}

- (void) test_domNodeGetChildNodesByType
{
  StubDOMNode *third;
  StubDOMNode *second;
  StubDOMNode *first;
  StubDOMNode *parent;
  NSArray *nodes;

  third = [StubDOMNode nodeWithType: DOM_TEXT_NODE nextSibling: nil];
  second = [StubDOMNode nodeWithType: DOM_ELEMENT_NODE nextSibling: third];
  first = [StubDOMNode nodeWithType: DOM_TEXT_NODE nextSibling: second];
  parent = [StubDOMNode nodeWithType: DOM_ELEMENT_NODE nextSibling: nil];
  [parent setChild: first];

  nodes = [self domNode: parent getChildNodesByType: DOM_TEXT_NODE];
  failIf([nodes count] != 2);
  testEquals([nodes objectAtIndex: 0], first);
  testEquals([nodes objectAtIndex: 1], third);

  nodes = [self domNode: parent getChildNodesByType: DOM_COMMENT_NODE];
  failIf([nodes count] != 0);

  nodes = [self domNode: [StubDOMNode nodeWithType: DOM_ELEMENT_NODE nextSibling: nil]
      getChildNodesByType: DOM_TEXT_NODE];
  failIf([nodes count] != 0);
}

- (void) test_labelForKeyWithSOGoUser
{
  StubContext *context;
  StubSOGoUser *user;

  user = [[StubSOGoUser new] autorelease];
  context = [StubContext contextWithUser: user request: nil];
  testEquals([self labelForKey: @"greeting"
		     inContext: (WOContext *) (void *) context],
             @"HelloLabel");
  testEquals([self labelForKey: @"greeting"
		     inContext: (WOContext *) (void *) context],
             @"HelloLabel");
  testEquals([self labelForKey: @"absent"
		     inContext: (WOContext *) (void *) context],
             @"absent");
}

- (void) test_labelForKeyWithBrowserLanguages
{
  StubContext *context;
  StubRequest *request;

  request = [StubRequest requestWithLanguages: [NSArray arrayWithObject: @"Klingon"]];
  context = [StubContext contextWithUser: nil request: request];
  testEquals([self labelForKey: @"greeting"
		     inContext: (WOContext *) (void *) context],
             @"greeting");

  context = [StubContext contextWithUser: [NSString string] request: request];
  testEquals([self labelForKey: @"greeting"
		     inContext: (WOContext *) (void *) context],
             @"greeting");
}

- (void) test_memoryStatistics
{
  [NSObject memoryStatistics];
  test(YES);
}

- (void) test_parts
{
  NGMimeMultipartBody *multipartBody;
  NGMimeBodyPart *bodyPart;
  NGMimeBodyPart *plainBodyPart;

  bodyPart = [NGMimeBodyPart new];
  multipartBody = [NGMimeMultipartBody new];
  [bodyPart setBody: multipartBody];
  failIf([[bodyPart parts] count] != 0);

  plainBodyPart = [NGMimeBodyPart new];
  [plainBodyPart setBody: @"some text"];
  failIf([[plainBodyPart parts] count] != 0);

  failIf([[@"not a mime part" parts] count] != 0);

  [bodyPart release];
  [multipartBody release];
  [plainBodyPart release];
}

@end
