#import <NGCards/NGVCard.h>
#import <NGCards/NGVCardPhoto.h>
#import <NGCards/NGVCardReference.h>
#import <NGCards/NGVList.h>
#import <NGCards/CardElement.h>
#import <NGCards/CardGroup.h>
#import <NGCards/CardVersitRenderer.h>
#import <NGCards/NGCardsSaxHandler.h>
#import <NGCards/NSString+NGCards.h>
#import <NGCards/NSArray+NGCards.h>
#import <NGCards/NSDictionary+NGCards.h>

#import "SOGoTest.h"

@interface OrderedCardGroup : CardGroup
@end

@implementation OrderedCardGroup

- (NSArray *) orderOfElements
{
  return [NSArray arrayWithObjects: @"c", @"a", nil];
}

@end

@interface TestNGCardsCore : SOGoTest
@end

@implementation TestNGCardsCore

- (void) test_card_element_creation
{
  CardElement *element;

  element = [CardElement elementWithTag: @"elem"];
  testEquals([element tag], @"elem");
  test([[element values] count] == 0);
  test([[element attributes] count] == 0);

  element = [CardElement simpleElementWithTag: @"elem" value: @"value"];
  testEquals([element tag], @"elem");
  testEquals([element flattenedValuesForKey: @""], @"value");

  element = [CardElement simpleElementWithTag: @"tel"
                                   singleType: @"home"
                                        value: @"123"];
  testEquals([element flattenedValuesForKey: @""], @"123");
  testEquals([element value: 0 ofAttribute: @"type"], @"home");
}

- (void) test_card_element_values
{
  CardElement *element;

  element = [CardElement elementWithTag: @"elem"];
  [element setValues: @"single" atIndex: 0 forKey: @""];
  testEquals([element flattenedValuesForKey: @""], @"single");

  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: nil forKey: @""];
  test([element isVoid]);
  test([[[element valuesForKey: @""] objectAtIndex: 0] count] == 0);

  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"third" atIndex: 2 forKey: @""];
  test([[element valuesForKey: @""] count] == 3);
  testEquals([element flattenedValueAtIndex: 2 forKey: @""], @"third");
  testEquals([element flattenedValueAtIndex: 0 forKey: @""], @"");
  testEquals([element flattenedValueAtIndex: 9 forKey: @""], @"");
  testEquals([element flattenedValuesForKey: @""], @";;third");

  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"mixed" forKey: @"MiXeD"];
  testEquals([element flattenedValuesForKey: @""], @"");
  testEquals([element flattenedValuesForKey: @"MiXeD"], @"mixed");
  test([[element values] objectForKey: @"mixed"] != nil);

  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"mixed" forKey: @"mixed"];
  test([[element valuesForKey: @"MIXED"] count] > 0);
  testEquals([[element valuesAtIndex: 0 forKey: @"Mixed"] objectAtIndex: 0],
             @"mixed");

  element = [CardElement elementWithTag: @"elem"];
  [element setValues: [NSArray arrayWithObjects: @"a", @"b", nil]
             atIndex: 0 forKey: @""];
  [element setValues: [NSArray arrayWithObjects: @"c", nil]
             atIndex: 1 forKey: @""];
  testEquals([element flattenedValuesForKey: @""], @"a,b;c");
  testEquals([element flattenedValueAtIndex: 0 forKey: @""], @"a,b");
}

- (void) test_card_element_encodings
{
  CardElement *element;

  element = [CardElement elementWithTag: @"note"];
  [element addAttribute: @"encoding" value: @"quoted-printable"];
  [element setSingleValue: @"Caf=C3=A9" forKey: @""];
  testEquals([element flattenedValuesForKey: @""], @"Café");

  element = [CardElement elementWithTag: @"photo"];
  [element addAttribute: @"encoding" value: @"base64"];
  [element setSingleValue: @"aGVsbG8=" forKey: @""];
  testEquals([element flattenedValuesForKey: @""], @"hello");
  testEquals([element flattenedValueAtIndex: 0 forKey: @""], @"hello");

  element = [CardElement elementWithTag: @"note"];
  [element addAttribute: @"encoding" value: @"8bit"];
  [element setSingleValue: @"plain" forKey: @""];
  testEquals([element flattenedValuesForKey: @""], @"plain");

  element = [CardElement elementWithTag: @"note"];
  [element addAttribute: @"encoding" value: @"x-uuencode"];
  [element setSingleValue: @"raw" forKey: @""];
  testEquals([element flattenedValuesForKey: @""], @"raw");
  testEquals([element flattenedValueAtIndex: 0 forKey: @""], @"raw");

  element = [CardElement elementWithTag: @"note"];
  [element addAttribute: @"encoding" value: @"QUOTED-PRINTABLE"];
  [element setSingleValue: @"one=2Ctwo" forKey: @""];
  testEquals([element flattenedValuesForKey: @""], @"one,two");

  element = [CardElement elementWithTag: @"note"];
  [element addAttribute: @"ENCODING" value: @"Quoted-Printable"];
  [element setSingleValue: @"one=2Ctwo" atIndex: 1 forKey: @""];
  testEquals([element flattenedValueAtIndex: 1 forKey: @""], @"one,two");
}

- (void) test_card_element_attributes
{
  CardElement *element;

  element = [CardElement elementWithTag: @"elem"];
  [element addAttribute: @"type" value: nil];
  testEquals([element value: 0 ofAttribute: @"type"], @"");

  element = [CardElement elementWithTag: @"elem"];
  [element addAttribute: @"TYPE" value: @"home"];
  [element addAttribute: @"type" value: @"voice"];
  testEquals([element value: 0 ofAttribute: @"type"], @"home");
  testEquals([element value: 1 ofAttribute: @"TYPE"], @"voice");
  testEquals([element value: 2 ofAttribute: @"type"], @"");

  element = [CardElement elementWithTag: @"elem"];
  [element addType: @"work"];
  [element removeValue: @"WORK" fromAttribute: @"type"];
  testEquals([element value: 0 ofAttribute: @"type"], @"");

  element = [CardElement elementWithTag: @"elem"];
  [element addType: @"work"];
  [element addType: @"work"];
  [element removeValue: @"work" fromAttribute: @"type"];
  testEquals([element value: 0 ofAttribute: @"type"], @"");
  testEquals([element value: 1 ofAttribute: @"type"], @"");
  [element removeValue: @"work" fromAttribute: @"nonexistent"];
  test([[element attributes] count] == 1);
  [element removeValue: nil fromAttribute: @"type"];
  testEquals([element value: 0 ofAttribute: @"type"], @"");

  element = [CardElement elementWithTag: @"elem"];
  [element addType: @"x"];
  [element addAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSArray arrayWithObject: @"y"], @"TYPE", nil]];
  testEquals([element value: 0 ofAttribute: @"type"], @"x");
  testEquals([element value: 1 ofAttribute: @"type"], @"y");

  element = [CardElement elementWithTag: @"elem"];
  [element addAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSArray arrayWithObject: @"z"], @"type", nil]];
  testEquals([element value: 0 ofAttribute: @"type"], @"z");

  element = [CardElement elementWithTag: @"elem"];
  [element addAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSArray arrayWithObject: @"z"], @"type", nil]];
  [element addAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSArray arrayWithObject: @"w"], @"TYPE", nil]];
  testEquals([element value: 0 ofAttribute: @"type"], @"z");
  testEquals([element value: 1 ofAttribute: @"type"], @"w");
  test([[element attributes] count] == 1);

  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"v1" forKey: @"X-Foo"];
  testEquals([element flattenedValuesForKey: @"x-foo"], @"v1");
  testEquals([element flattenedValuesForKey: @"X-FOO"], @"v1");
  testEquals([element versitString], @"ELEM:X-FOO=v1");

  element = [CardElement elementWithTag: @"elem"];
  [element addType: @"home"];
  test([element hasAttribute: @"type" havingValue: @"HOME"]);
  test(![element hasAttribute: @"type" havingValue: @"work"]);
  test(![element hasAttribute: @"nonexistent" havingValue: @"home"]);

  element = [CardElement elementWithTag: @"elem"];
  [element setValue: 2 ofAttribute: @"type" to: @"far"];
  testEquals([element value: 0 ofAttribute: @"type"], @"");
  testEquals([element value: 1 ofAttribute: @"type"], @"");
  testEquals([element value: 2 ofAttribute: @"type"], @"far");
  [element setValue: 0 ofAttribute: @"type" to: nil];
  testEquals([element value: 0 ofAttribute: @"type"], @"");
}

- (void) test_card_element_is_void
{
  CardElement *element;

  element = [CardElement elementWithTag: @"elem"];
  test([element isVoid]);

  element = [CardElement elementWithTag: @"elem"];
  [element setValues: [NSArray arrayWithObjects: @"", @"", nil]
             atIndex: 0 forKey: @""];
  test([element isVoid]);

  element = [CardElement elementWithTag: @"elem"];
  [element setSingleValue: @"" forKey: @""];
  [element setSingleValue: @"x" forKey: @"other"];
  test(![element isVoid]);
}

- (void) test_card_element_order_and_versit
{
  CardElement *element;

  element = [CardElement elementWithTag: @"elem"];
  test([element orderOfAttributeKeys] == nil);
  test([element orderOfValueKeys] == nil);

  element = [CardElement simpleElementWithTag: @"elem" value: @"value"];
  testEquals([element versitString], @"ELEM:value");

  element = [CardElement simpleElementWithTag: @"X-Foo" value: @"value"];
  [element setGroup: @"Item1"];
  testEquals([element versitString], @"Item1.X-FOO:value");

  element = [CardElement elementWithTag: @"elem"];
  testEquals([element versitString], @"");
}

- (void) test_card_element_parent_group
{
  CardElement *element;

  element = [CardElement elementWithTag: @"elem"];
  test([element parent] == nil);
  [element setParent: nil];
  test([element parent] == nil);
  test([element group] == nil);
  [element setGroup: @"item1"];
  testEquals([element group], @"item1");
}

- (void) test_card_element_description
{
  CardElement *element;

  element = [CardElement simpleElementWithTag: @"elem" value: @"value"];
  test([[element description] hasSuffix: @":elem\nELEM:value"]);

  element = [CardElement simpleElementWithTag: @"elem" value: @"value"];
  [element setGroup: @"item1"];
  test([[element description] hasSuffix: @"elem (group: item1)\nitem1.ELEM:value"]);
}

- (void) test_card_element_search_parent
{
  NGVCard *card;
  CardGroup *inner;
  CardElement *element;

  card = [NGVCard cardWithUid: @"u1"];
  inner = [CardGroup groupWithTag: @"inner"];
  [card addChild: inner];
  element = [CardElement simpleElementWithTag: @"elem" value: @"v"];
  [inner addChild: element];
  test([element searchParentOfClass: [NGVCard class]] == card);
  test([element searchParentOfClass: [OrderedCardGroup class]] == nil);
}

- (void) test_card_element_with_class
{
  CardGroup *group;
  CardElement *element, *converted;

  element = [CardElement simpleElementWithTag: @"elem" value: @"v"];
  test([element elementWithClass: [CardElement class]] == element);

  group = [CardGroup groupWithTag: @"group"];
  element = [CardElement simpleElementWithTag: @"photo" value: @"v"];
  [group addChild: element];
  [element setGroup: @"item1"];
  converted = [element elementWithClass: [NGVCardPhoto class]];
  test(converted != element);
  test([converted isKindOfClass: [NGVCardPhoto class]]);
  testEquals([converted tag], @"photo");
  testEquals([converted flattenedValuesForKey: @""], @"v");
  testEquals([converted group], @"item1");
  test([converted parent] == group);
  test([[group children] count] == 1);
  test([[group children] objectAtIndex: 0] == converted);
}

- (void) test_card_element_copy
{
  CardElement *element, *copy;

  element = [CardElement simpleElementWithTag: @"elem" value: @"v"];
  [element setGroup: @"item1"];
  [element addType: @"home"];
  [element setSingleValue: @"sub" forKey: @"key"];
  copy = [[element copy] autorelease];
  testEquals([copy tag], @"elem");
  testEquals([copy group], @"item1");
  testEquals([copy flattenedValuesForKey: @""], @"v");
  testEquals([copy flattenedValuesForKey: @"key"], @"sub");
  testEquals([copy value: 0 ofAttribute: @"type"], @"home");

  [element setSingleValue: @"changed" forKey: @""];
  testEquals([copy flattenedValuesForKey: @""], @"v");

  copy = [[element mutableCopy] autorelease];
  testEquals([copy flattenedValuesForKey: @""], @"changed");
}

- (void) test_card_group_creation
{
  CardGroup *group;
  CardElement *child;

  group = [CardGroup groupWithTag: @"vgroup"];
  testEquals([group tag], @"vgroup");
  test([[group children] count] == 0);
  test([group isVoid]);

  child = [CardElement simpleElementWithTag: @"elem" value: @""];
  group = [CardGroup groupWithTag: @"vgroup"
                          children: [NSArray arrayWithObject: child]];
  test([[group children] count] == 1);
  test([group isVoid]);
  test([child parent] == group);

  child = [CardElement simpleElementWithTag: @"elem" value: @"x"];
  [group addChild: child];
  test(![group isVoid]);

  [group addChild: nil];
  test([[group children] count] == 2);
  test([group classForTag: @"WHATEVER"] == nil);
  test([group orderOfElements] == nil);
}

- (void) test_card_group_unique_child
{
  CardGroup *group;
  CardElement *first, *second, *obtained;

  group = [CardGroup groupWithTag: @"g"];
  first = [group uniqueChildWithTag: @"fn"];
  testEquals([first tag], @"fn");
  obtained = [group uniqueChildWithTag: @"FN"];
  test(obtained == first);
  test([[group children] count] == 1);

  second = [CardElement elementWithTag: @"fn"];
  [second setSingleValue: @"other" forKey: @""];
  [group addChild: second];
  [group setUniqueChild: second];
  test([[group children] count] == 1);
  test([[group children] objectAtIndex: 0] == second);
  [group setUniqueChild: nil];
  test([[group children] count] == 1);
}

- (void) test_card_group_first_child
{
  CardGroup *group;
  NGVCard *card;
  CardElement *element;

  group = [CardGroup groupWithTag: @"g"];
  test([group firstChildWithTag: @"missing"] == nil);

  element = [CardElement elementWithTag: @"photo"];
  [group addChild: element];
  test([[group firstChildWithTag: @"photo"] isKindOfClass: [CardElement class]]);
  test(![[group firstChildWithTag: @"photo"] isKindOfClass: [NGVCardPhoto class]]);

  element = [CardElement elementWithTag: @"zzz"];
  [group addChild: element];
  test([group firstChildWithTag: @"zzz"] == element);

  card = [NGVCard cardWithUid: @"u1"];
  element = [CardElement elementWithTag: @"photo"];
  [card addChild: element];
  test([[card firstChildWithTag: @"photo"] isKindOfClass: [NGVCardPhoto class]]);
}

- (void) test_card_group_children_manipulation
{
  CardGroup *group;
  CardElement *e1, *e2, *e3;

  group = [CardGroup groupWithTag: @"g"];
  e1 = [CardElement simpleElementWithTag: @"tel" value: @"1"];
  e2 = [CardElement simpleElementWithTag: @"tel" value: @"2"];
  e3 = [CardElement simpleElementWithTag: @"email" value: @"3"];
  [group addChildren: [NSArray arrayWithObjects: e1, e2, e3, nil]];
  test([[group childrenWithTag: @"TEL"] count] == 2);
  test([[group children] count] == 3);

  [group removeChildren: [NSArray arrayWithObjects: e1, nil]];
  test([[group children] count] == 2);
  test([e1 parent] == nil);

  [group removeChild: e3];
  test([[group children] count] == 1);
  test([e3 parent] == nil);
}

- (void) test_card_group_children_queries
{
  NGVCard *card;
  CardElement *e1, *e2, *e3;

  card = [NGVCard cardWithUid: @"u1"];
  test([[card childrenWithType: @"none"] count] == 0);

  e1 = [CardElement simpleElementWithTag: @"tel" value: @"1"];
  [e1 addType: @"home"];
  e2 = [CardElement simpleElementWithTag: @"tel" value: @"2"];
  [e2 addType: @"work"];
  e3 = [CardElement simpleElementWithTag: @"email" value: @"3"];
  [e3 addType: @"home"];
  [card addChildren: [NSArray arrayWithObjects: e1, e2, e3, nil]];

  test([[card childrenWithType: @"home"] count] == 2);
  test([[card childrenWithAttribute: @"type" havingValue: @"work"] count] == 1);
  test([[card childrenWithTag: @"tel" andAttribute: @"type" havingValue: @"work"] count] == 1);
  test([[card childrenWithTag: @"email" andAttribute: @"type" havingValue: @"work"] count] == 0);
}

- (void) test_card_group_children_group_query
{
  CardGroup *group, *inner, *other;
  NSArray *found;

  group = [CardGroup groupWithTag: @"g"];
  inner = [CardGroup groupWithTag: @"team"];
  [inner addChild: [CardElement simpleElementWithTag: @"uid" value: @"t1"]];
  other = [CardGroup groupWithTag: @"team"];
  [other addChild: [CardElement simpleElementWithTag: @"uid" value: @"t2"]];
  [group addChildren: [NSArray arrayWithObjects: inner, other, nil]];
  [group addChild: [CardElement simpleElementWithTag: @"team" value: @"t3"]];

  found = [group childrenGroupWithTag: @"team"
                             withChild: @"uid"
                   havingSimpleValue: @"t1"];
  test([found count] == 1);
  test([found objectAtIndex: 0] == inner);

  found = [group childrenGroupWithTag: @"team"
                             withChild: @"uid"
                   havingSimpleValue: @"t9"];
  test([found count] == 0);
}

- (void) test_card_group_add_child_conversion
{
  NGVCard *card;
  CardElement *plain;

  card = [NGVCard cardWithUid: @"u1"];
  plain = [CardElement elementWithTag: @"photo"];
  [card addChild: plain];
  test([[[card children] objectAtIndex: 4] isKindOfClass: [NGVCardPhoto class]]);
}

- (void) test_card_group_add_child_with_tag
{
  CardGroup *group;
  CardElement *element;

  group = [CardGroup groupWithTag: @"g"];
  [group addChildWithTag: @"tel" types: nil singleValue: @"123"];
  test([[group children] count] == 1);
  element = [[group childrenWithTag: @"tel"] objectAtIndex: 0];
  testEquals([element flattenedValuesForKey: @""], @"123");
  testEquals([element value: 0 ofAttribute: @"type"], @"");

  [group addChildWithTag: @"tel"
                   types: [NSArray arrayWithObjects: @"home", @"voice", nil]
             singleValue: @"456"];
  element = [[group childrenWithTag: @"tel"] objectAtIndex: 1];
  testEquals([element flattenedValuesForKey: @""], @"456");
  testEquals([element value: 0 ofAttribute: @"type"], @"home");
  testEquals([element value: 1 ofAttribute: @"type"], @"voice");
}

- (void) test_card_group_cleanup
{
  CardGroup *group, *inner;
  CardElement *keeper, *void1, *void2;

  group = [CardGroup groupWithTag: @"g"];
  keeper = [CardElement simpleElementWithTag: @"fn" value: @"keep"];
  void1 = [CardElement elementWithTag: @"tel"];
  inner = [CardGroup groupWithTag: @"inner"];
  void2 = [CardElement elementWithTag: @"email"];
  [inner addChild: void2];
  [group addChildren: [NSArray arrayWithObjects: keeper, void1, inner, nil]];

  [group cleanupEmptyChildren];
  test([[group children] count] == 1);
  test([[group children] objectAtIndex: 0] == keeper);
}

- (void) test_card_group_element_with_class
{
  CardGroup *group;
  CardElement *child;
  NGVCard *converted;

  group = [CardGroup groupWithTag: @"vcard"];
  child = [CardElement simpleElementWithTag: @"fn" value: @"x"];
  [group addChild: child];
  converted = [group elementWithClass: [NGVCard class]];
  test(converted != group);
  test([converted isKindOfClass: [NGVCard class]]);
  test([[converted children] count] == 1);
  test([[converted childrenWithTag: @"fn"] objectAtIndex: 0] == child);
  test([child parent] == converted);

  test([group elementWithClass: [CardGroup class]] == group);
}

- (void) test_card_group_set_children_as_copy
{
  CardGroup *group;
  CardElement *child;

  group = [CardGroup groupWithTag: @"g"];
  child = [CardElement simpleElementWithTag: @"fn" value: @"x"];
  [group setChildrenAsCopy: [NSMutableArray arrayWithObject: child]];
  test([[group children] count] == 1);
  test([child parent] == group);
}

- (void) test_card_group_replace_element
{
  CardGroup *group;
  CardElement *old, *new;

  group = [CardGroup groupWithTag: @"g"];
  old = [CardElement simpleElementWithTag: @"fn" value: @"old"];
  new = [CardElement simpleElementWithTag: @"fn" value: @"new"];
  [group addChild: old];
  [group replaceThisElement: old withThisOne: new];
  test([[group children] count] == 1);
  test([[group children] objectAtIndex: 0] == new);
}

- (void) test_card_group_copy
{
  CardGroup *group, *copy;
  CardElement *child;

  group = [CardGroup groupWithTag: @"g"];
  child = [CardElement simpleElementWithTag: @"fn" value: @"x"];
  [group addChild: child];

  copy = [[group copy] autorelease];
  test([[copy children] count] == 1);
  test([[[copy children] objectAtIndex: 0] parent] == copy);
  [child setSingleValue: @"changed" forKey: @""];
  testEquals([[[copy childrenWithTag: @"fn"] objectAtIndex: 0]
               flattenedValuesForKey: @""], @"x");

  copy = [[group mutableCopy] autorelease];
  testEquals([[[copy childrenWithTag: @"fn"] objectAtIndex: 0]
               flattenedValuesForKey: @""], @"changed");
}

- (void) test_card_group_description
{
  CardGroup *group;

  group = [CardGroup groupWithTag: @"g"];
  test([[group description] hasPrefix: @"<"]);

  [group addChild: [CardElement simpleElementWithTag: @"fn" value: @"x"]];
  test([[group description] containsString: @"children"]);
  test([[group description] containsString: @"FN:x"]);
}

- (void) test_card_group_parse_null
{
  test([CardGroup parseFromSource: nil] == nil);
  test([CardGroup parseSingleFromSource: @""] == nil);
}

- (void) test_vcard_creation
{
  NGVCard *card;

  card = [NGVCard cardWithUid: @"u1"];
  testEquals([card tag], @"vcard");
  testEquals([card uid], @"u1");
  testEquals([card version], @"3.0");
  testEquals([card vClass], @"PUBLIC");
  testEquals([card profile], @"VCARD");
}

- (void) test_vcard_class_for_tag
{
  NGVCard *card;

  card = [NGVCard cardWithUid: @"u1"];
  test([card classForTag: @"FN"] == [CardElement class]);
  test([card classForTag: @"BDAY"] == [CardElement class]);
  test([card classForTag: @"PHOTO"] == [NGVCardPhoto class]);
  test([card classForTag: @"ZZZ"] == nil);
}

- (void) test_vcard_accessors
{
  NGVCard *card;

  card = [NGVCard cardWithUid: @"u1"];

  [card setVersion: @"2.1"];
  testEquals([card version], @"2.1");
  [card setUid: @"u2"];
  testEquals([card uid], @"u2");
  [card setVClass: @"PRIVATE"];
  testEquals([card vClass], @"PRIVATE");
  [card setProdID: @"prod"];
  testEquals([card prodID], @"prod");
  [card setProfile: @"prof"];
  testEquals([card profile], @"prof");
  [card setSource: @"src"];
  testEquals([card source], @"src");
  [card setFn: @"The Name"];
  testEquals([card fn], @"The Name");
  [card setRole: @"role1"];
  testEquals([card role], @"role1");
  [card setTitle: @"title1"];
  testEquals([card title], @"title1");
  [card setBday: @"1980-02-29"];
  testEquals([card bday], @"1980-02-29");
  [card setNote: @"a note"];
  testEquals([card note], @"a note");
  [card setTz: @"Europe/Berlin"];
  testEquals([card tz], @"Europe/Berlin");
  [card setNickname: @"nick"];
  testEquals([card nickname], @"nick");
}

- (void) test_vcard_n_org_categories
{
  NGVCard *card;
  CardElement *element;

  card = [NGVCard cardWithUid: @"u1"];
  [card setNWithFamily: @"Doe"
                 given: @"John"
            additional: @"Junior"
              prefixes: @"Dr."
              suffixes: @"Jr."];
  element = [card n];
  testEquals([element flattenedValueAtIndex: 0 forKey: @""], @"Doe");
  testEquals([element flattenedValueAtIndex: 1 forKey: @""], @"John");
  testEquals([element flattenedValueAtIndex: 2 forKey: @""], @"Junior");
  testEquals([element flattenedValueAtIndex: 3 forKey: @""], @"Dr.");
  testEquals([element flattenedValueAtIndex: 4 forKey: @""], @"Jr.");
  testEquals([element versitString], @"N:Doe;John;Junior;Dr.;Jr.");

  card = [NGVCard cardWithUid: @"u1"];
  [card setNWithFamily: @"Doe"
                 given: nil
            additional: nil
              prefixes: nil
              suffixes: nil];
  testEquals([[card n] versitString], @"N:Doe");

  card = [NGVCard cardWithUid: @"u1"];
  [card setOrg: @"Inverse"
          units: [NSArray arrayWithObjects: @"unit1", @"unit2", nil]];
  testEquals([[card org] versitString], @"ORG:Inverse;unit1;unit2");
  [card setOrg: nil units: nil];
  testEquals([[card org] versitString], @"ORG:Inverse;unit1;unit2");

  card = [NGVCard cardWithUid: @"u1"];
  [card setCategories: [NSArray arrayWithObjects: @"a", @"b", nil]];
  testEquals([[card categories] objectAtIndex: 0], @"a");
  testEquals([[card categories] objectAtIndex: 1], @"b");
}

- (void) test_vcard_photo
{
  NGVCard *card;

  card = [NGVCard cardWithUid: @"u1"];
  test([card photo] == nil);
  [card setPhoto: @"QUJDRA=="];
  testEquals([card photo], @"QUJDRA==");
  testEquals([[[card childrenWithTag: @"photo"] objectAtIndex: 0] versitString],
             @"PHOTO;ENCODING=BASE64:QUJDRA==");
}

- (void) test_vcard_certificate
{
  NGVCard *card;
  NSData *data, *obtained;

  card = [NGVCard cardWithUid: @"u1"];
  data = [NSData dataWithBytes: "hello" length: 5];
  [card setCertificate: data];
  obtained = [card certificate];
  testEquals(obtained, data);
  testEquals([[[card childrenWithTag: @"key"] objectAtIndex: 0] versitString],
             @"KEY;TYPE=application/pkcs7-signature;ENCODING=base64:aGVsbG8=");
}

- (void) test_vcard_add_tel_email
{
  NGVCard *card;

  card = [NGVCard cardWithUid: @"u1"];
  [card addTel: @"123" types: [NSArray arrayWithObject: @"home"]];
  [card addTel: @"456" types: nil];
  [card addEmail: @"a@b.c" types: [NSArray arrayWithObject: @"work"]];
  testEquals([[[card childrenWithTag: @"tel"] objectAtIndex: 0] versitString],
             @"TEL;TYPE=home:123");
  testEquals([[[card childrenWithTag: @"tel"] objectAtIndex: 1] versitString],
             @"TEL:456");
  testEquals([[[card childrenWithTag: @"email"] objectAtIndex: 0] versitString],
             @"EMAIL;TYPE=work:a@b.c");
}

- (void) test_vcard_preferred_selector
{
  NGVCard *card;
  CardElement *e1, *e2, *tel;

  card = [NGVCard cardWithUid: @"u1"];
  e1 = [CardElement simpleElementWithTag: @"email" singleType: @"pref"
                                    value: @"first@x"];
  e2 = [CardElement simpleElementWithTag: @"email" value: @"second@x"];
  [card addChild: e1];
  [card addChild: e2];

  [card setPreferred: e1];
  testEquals([e1 value: 0 ofAttribute: @"type"], @"pref");

  [card setPreferred: e2];
  testEquals([e2 value: 0 ofAttribute: @"type"], @"pref");
  testEquals([e1 value: 0 ofAttribute: @"type"], @"");

  tel = [CardElement simpleElementWithTag: @"tel" singleType: @"pref"
                                    value: @"123"];
  [card addChild: tel];
  [card setPreferred: tel];
  testEquals([tel value: 0 ofAttribute: @"type"], @"pref");
  testEquals([e2 value: 0 ofAttribute: @"type"], @"pref");

  [card setPreferred: e1];
  testEquals([e1 value: 0 ofAttribute: @"type"], @"pref");
  testEquals([e2 value: 0 ofAttribute: @"type"], @"");
  testEquals([tel value: 0 ofAttribute: @"type"], @"pref");
}

- (void) test_vcard_preferred_accessors
{
  NGVCard *card;
  CardElement *e1, *e2, *e3;

  card = [NGVCard cardWithUid: @"u1"];
  testEquals([card preferredEMail], nil);
  testEquals([card preferredTel], nil);
  test([card preferredAdr] == nil);

  e1 = [CardElement simpleElementWithTag: @"email" value: @"plain@x"];
  e2 = [CardElement simpleElementWithTag: @"email" singleType: @"work"
                                    value: @"work@x"];
  e3 = [CardElement simpleElementWithTag: @"email" value: @"home@x"];
  [e3 addType: @"pref"];
  [card addChildren: [NSArray arrayWithObjects: e1, e2, e3, nil]];
  testEquals([card preferredEMail], @"home@x");

  [e3 removeValue: @"pref" fromAttribute: @"type"];
  testEquals([card preferredEMail], @"work@x");

  [e2 removeValue: @"work" fromAttribute: @"type"];
  testEquals([card preferredEMail], @"plain@x");

  e1 = [CardElement simpleElementWithTag: @"tel" value: @"111"];
  [card addChild: e1];
  testEquals([card preferredTel], @"111");

  e1 = [CardElement simpleElementWithTag: @"adr" value: @"box"];
  [card addChild: e1];
  testEquals([[card preferredAdr] flattenedValuesForKey: @""], @"box");
}

- (void) test_vcard_versit_string
{
  NGVCard *card;

  card = [NGVCard cardWithUid: @"u1"];
  testEquals([card versitString],
             @"BEGIN:VCARD\r\nUID:u1\r\nVERSION:3.0\r\nCLASS:PUBLIC\r\nPROFILE:VCARD\r\nEND:VCARD");

  [card setVersion: @"2.1"];
  testEquals([card versitString],
             @"BEGIN:VCARD\r\nUID:u1\r\nVERSION:3.0\r\nCLASS:PUBLIC\r\nPROFILE:VCARD\r\nEND:VCARD");
}

- (void) test_vcard_round_trip
{
  NSString *versit;
  NGVCard *card, *parsed;

  versit = @"BEGIN:VCARD\r\nVERSION:3.0\r\nUID:abc\r\nFN:John Doe\r\nEND:VCARD";
  card = [NGVCard parseSingleFromSource: versit];
  test([card isKindOfClass: [NGVCard class]]);
  testEquals([card uid], @"abc");
  testEquals([card fn], @"John Doe");
  testEquals([card versitString], versit);
}

- (void) test_vcard_description
{
  NGVCard *card;

  card = [NGVCard cardWithUid: @"u1"];
  test([[card description] hasSuffix: @"[NGVCard]: uid='u1'>"]);
}

- (void) test_vcard_photo_class
{
  NGVCardPhoto *photo;

  photo = [NGVCardPhoto elementWithTag: @"photo"];
  test([photo isInline]);
  testEquals([photo type], @"JPEG");
  [photo setValue: 0 ofAttribute: @"type" to: @"gif"];
  testEquals([photo type], @"GIF");

  photo = [NGVCardPhoto elementWithTag: @"photo"];
  [photo setValue: 0 ofAttribute: @"value" to: @"uri"];
  test(![photo isInline]);
  test([photo decodedContent] == nil);

  photo = [NGVCardPhoto elementWithTag: @"photo"];
  [photo setValue: 0 ofAttribute: @"encoding" to: @"b"];
  test([photo decodedContent] == nil);

  photo = [NGVCardPhoto elementWithTag: @"photo"];
  [photo setValue: 0 ofAttribute: @"encoding" to: @"x-uu"];
  [photo setSingleValue: @"data" forKey: @""];
  test([photo decodedContent] == nil);

  photo = [NGVCardPhoto elementWithTag: @"photo"];
  [photo setValue: 0 ofAttribute: @"encoding" to: @"BASE64"];
  [photo setSingleValue: @"aGVsbG8=" forKey: @""];
  testEquals([photo decodedContent],
             [NSData dataWithBytes: "hello" length: 5]);
}

- (void) test_vcard_reference
{
  NGVCardReference *reference;

  reference = [NGVCardReference elementWithTag: @"card"];
  [reference setFn: @"John"];
  testEquals([reference fn], @"John");
  [reference setEmail: @"john@x"];
  testEquals([reference email], @"john@x");
  [reference setReference: @"abcd-1234"];
  testEquals([reference reference], @"abcd-1234");
}

- (void) test_vlist
{
  NGVList *list;
  NGVCardReference *r1, *r2, *r3;

  list = [NGVList listWithUid: @"l1"];
  testEquals([list tag], @"vlist");
  testEquals([list uid], @"l1");
  testEquals([list version], @"1.0");

  test([list classForTag: @"CARD"] == [NGVCardReference class]);
  test([list classForTag: @"DESCRIPTION"] == [CardElement class]);
  test([list classForTag: @"ZZZ"] == nil);

  [list setProdID: @"prod"];
  testEquals([list prodID], @"prod");
  [list setFn: @"list fn"];
  testEquals([list fn], @"list fn");
  [list setNickname: @"nick"];
  testEquals([list nickname], @"nick");
  [list setDescription: @"the description"];
  testEquals([list description], @"the description");

  test([list isPublic]);
  [list setAccessClass: @"private"];
  test([list symbolicAccessClass] == 1);
  test(![list isPublic]);
  [list setAccessClass: @"confidential"];
  test([list symbolicAccessClass] == 2);
  [list setAccessClass: @"weird"];
  test([list symbolicAccessClass] == 0);

  r1 = [NGVCardReference elementWithTag: @"card"];
  [r1 setReference: @"r1"];
  r2 = [NGVCardReference elementWithTag: @"card"];
  [r2 setReference: @"r1"];
  r3 = [NGVCardReference elementWithTag: @"card"];
  [r3 setReference: @"r3"];
  [list addCardReference: r1];
  [list addCardReference: r2];
  [list addCardReference: r3];
  test([[list cardReferences] count] == 3);
  [list deleteCardReference: r1];
  test([[list cardReferences] count] == 1);
}

- (void) test_string_folded_short
{
  testEquals([@"" foldedForVersitCards], @"");
  testEquals([@"abc" foldedForVersitCards], @"abc");
  testEquals([@"Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" foldedForVersitCards],
             @"Aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
}

- (void) test_string_folded_medium
{
  NSMutableString *seventySeven;
  NSMutableString *expected;
  int i;

  seventySeven = [NSMutableString string];
  for (i = 0; i < 77; i++)
    [seventySeven appendString: @"x"];

  expected = [NSMutableString string];
  for (i = 0; i < 75; i++)
    [expected appendString: @"x"];
  [expected appendString: @"\r\n "];
  [expected appendString: @"xx"];

  testEquals([seventySeven foldedForVersitCards], expected);
}

- (void) test_string_folded_long
{
  NSMutableString *oneSixty;
  NSMutableString *expected;
  int i;

  oneSixty = [NSMutableString string];
  for (i = 0; i < 160; i++)
    [oneSixty appendString: @"y"];

  expected = [NSMutableString string];
  for (i = 0; i < 75; i++)
    [expected appendString: @"y"];
  [expected appendString: @"\r\n "];
  for (i = 0; i < 74; i++)
    [expected appendString: @"y"];
  [expected appendString: @"\r\n "];
  for (i = 0; i < 11; i++)
    [expected appendString: @"y"];

  testEquals([oneSixty foldedForVersitCards], expected);
}

- (void) test_string_folded_surrogate_start
{
  NSString *surrogate, *folded;

  surrogate = [NSString stringWithFormat: @"%@%C%C%@",
                          [@"A" stringByPaddingToLength: 74 withString: @"A" startingAtIndex: 0],
                          (unichar) 0xD83D, (unichar) 0xDE00,
                          [@"B" stringByPaddingToLength: 40 withString: @"B" startingAtIndex: 0]];
  test([surrogate length] == 116);
  folded = [surrogate foldedForVersitCards];
  test([folded length] == 119);
  test([folded hasPrefix: [@"A" stringByPaddingToLength: 74 withString: @"A" startingAtIndex: 0]]);
  test([folded hasSuffix: [@"B" stringByPaddingToLength: 40 withString: @"B" startingAtIndex: 0]]);
}

- (void) test_string_folded_surrogate_continuation
{
  NSString *surrogate, *folded;

  surrogate = [NSString stringWithFormat: @"%@%C%C%@",
                          [@"C" stringByPaddingToLength: 148 withString: @"C" startingAtIndex: 0],
                          (unichar) 0xD83D, (unichar) 0xDE00,
                          [@"B" stringByPaddingToLength: 50 withString: @"B" startingAtIndex: 0]];
  test([surrogate length] == 200);
  folded = [surrogate foldedForVersitCards];
  test([folded length] == 206);
  test([folded hasPrefix: [@"C" stringByPaddingToLength: 75 withString: @"C" startingAtIndex: 0]]);
  test([folded hasSuffix: [@"B" stringByPaddingToLength: 50 withString: @"B" startingAtIndex: 0]]);
}

- (void) test_string_as_card_attribute_values
{
  NSArray *values;

  values = [@"abc" asCardAttributeValues];
  test([values count] == 1);
  testEquals([values objectAtIndex: 0], @"abc");

  values = [@"a,b" asCardAttributeValues];
  test([values count] == 2);
  testEquals([values objectAtIndex: 0], @"a");
  testEquals([values objectAtIndex: 1], @"b");

  values = [@"a\\,b" asCardAttributeValues];
  test([values count] == 1);
  testEquals([values objectAtIndex: 0], @"a,b");

  values = [@"\"x,y\"" asCardAttributeValues];
  test([values count] == 1);
  testEquals([values objectAtIndex: 0], @"x,y");

  values = [@"\"a,b" asCardAttributeValues];
  test([values count] == 2);
  testEquals([values objectAtIndex: 0], @"\"a");
  testEquals([values objectAtIndex: 1], @"b");

  values = [@"a\\nb\\rc\\td\\be\\\\f" asCardAttributeValues];
  test([values count] == 1);
  testEquals([values objectAtIndex: 0], @"a\nb\rc\td\be\\f");

  values = [@"a\\Nb\\Rc\\Td\\Be" asCardAttributeValues];
  testEquals([values objectAtIndex: 0], @"a\nb\rc\td\be");

  values = [@"a\\" asCardAttributeValues];
  test([values count] == 1);
  testEquals([values objectAtIndex: 0], @"a");

  values = [@"\\," asCardAttributeValues];
  test([values count] == 1);
  testEquals([values objectAtIndex: 0], @",");
}

- (void) test_string_escaped_for_cards
{
  testEquals([@"plain" escapedForCardsAsAttributes: NO], @"plain");
  testEquals([@"a,b;c" escapedForCardsAsAttributes: NO], @"a\\,b\\;c");
  testEquals([@"a\nb\rc\\d\"e" escapedForCardsAsAttributes: NO],
             @"a\\nb\\rc\\\\d\"e");
  testEquals([@"a,b;c" escapedForCardsAsAttributes: YES], @"a\\,b\\;c");
  testEquals([@"\"a,b\"" escapedForCardsAsAttributes: YES], @"\"a,b\"");
  testEquals([@"\"a,b\"" escapedForCardsAsAttributes: NO], @"\"a\\,b\"");
}

- (void) test_string_vcard_subvalues
{
  NSDictionary *values;
  NSArray *ordered, *sub;

  values = [@"" vCardSubvalues];
  test([values count] == 1);
  test([[values objectForKey: @""] count] == 1);
  test([[values objectForKey: @""] objectAtIndex: 0] != nil);

  values = [@"Doe;John" vCardSubvalues];
  test([values count] == 1);
  ordered = [values objectForKey: @""];
  test([ordered count] == 2);
  sub = [ordered objectAtIndex: 0];
  test([sub count] == 1);
  testEquals([sub objectAtIndex: 0], @"Doe");

  values = [@"NAMED1=subvalue;NAMED2=subvalue1,subvalue2" vCardSubvalues];
  test([values count] == 2);
  sub = [[values objectForKey: @"named1"] objectAtIndex: 0];
  testEquals([sub objectAtIndex: 0], @"subvalue");
  sub = [[values objectForKey: @"named2"] objectAtIndex: 0];
  test([sub count] == 2);
  testEquals([sub objectAtIndex: 1], @"subvalue2");

  values = [@"a\\nb;c\\\\d" vCardSubvalues];
  sub = [[values objectForKey: @""] objectAtIndex: 0];
  testEquals([sub objectAtIndex: 0], @"a\nb");
  sub = [[values objectForKey: @""] objectAtIndex: 1];
  testEquals([sub objectAtIndex: 0], @"c\\d");

  values = [@"e\\Rf" vCardSubvalues];
  sub = [[values objectForKey: @""] objectAtIndex: 0];
  testEquals([sub objectAtIndex: 0], @"e\rf");

  values = [@"ABCDEFGHIJKLMNOP=x" vCardSubvalues];
  sub = [[values objectForKey: @""] objectAtIndex: 0];
  testEquals([sub objectAtIndex: 0], @"ABCDEFGHIJKLMNOP=x");

  values = [@"key=;second" vCardSubvalues];
  test([[values objectForKey: @"key"] count] == 1);
  test([[values objectForKey: @""] count] == 1);
}

- (void) test_string_misc_helpers
{
  NSCalendarDate *date;

  testEquals([@"mailto:a@b.c" rfc822Email], @"a@b.c");
  testEquals([@"a@b.c" rfc822Email], @"a@b.c");

  test([@"20080815" isAllDayDate]);
  test(![@"20080815T101112" isAllDayDate]);

  date = [@"19800229" asCalendarDate];
  test([date yearOfCommonEra] == 1980);
  test([date monthOfYear] == 2);
  test([date dayOfMonth] == 29);
  date = [@"1980-02-29T13:14:15" asCalendarDate];
  test([date hourOfDay] == 13);
  test([date minuteOfHour] == 14);
  test([date secondOfMinute] == 15);
  date = [@"19800229T131415" asCalendarDate];
  test([date hourOfDay] == 13);
  test([date minuteOfHour] == 14);
  test([date secondOfMinute] == 15);
  test([@"short" asCalendarDate] == nil);
}

- (void) test_string_duration
{
  test([@"PT1H" durationAsTimeInterval] == 3600);
  test([@"PT30M" durationAsTimeInterval] == 1800);
  test([@"P1D" durationAsTimeInterval] == 86400);
  test([@"P2W" durationAsTimeInterval] == 1209600);
  test([@"PT1H30M" durationAsTimeInterval] == 5400);
  test([@"-PT1H" durationAsTimeInterval] == -3600);
  test([@"P1DT2H" durationAsTimeInterval] == 93600);
  test([@"PT15S" durationAsTimeInterval] == 15.0);
  test([@"XT1H" durationAsTimeInterval] == 0);
  test([@"PT1X" durationAsTimeInterval] == 0);
}

- (void) test_array_helpers
{
  NSArray *array;

  array = [NSArray arrayWithObjects: @"One", @"TWO", nil];
  testEquals([array valueForCaseInsensitiveString: @"two"], @"TWO");
  testEquals([array valueForCaseInsensitiveString: @"three"], nil);
  test([array hasCaseInsensitiveString: @"one"]);
  test(![array hasCaseInsensitiveString: @"four"]);

  array = [NSArray arrayWithObjects: [CardElement elementWithTag: @"tel"],
                     [CardElement elementWithTag: @"email"],
                     nil];
  test([[array cardElementsWithTag: @"TEL"] count] == 1);
  test([[array cardElementsWithTag: @"zzz"] count] == 0);
}

- (void) test_array_card_elements_with_attribute
{
  NSArray *array;
  CardElement *e1, *e2;

  e1 = [CardElement simpleElementWithTag: @"tel" singleType: @"home" value: @"1"];
  e2 = [CardElement simpleElementWithTag: @"tel" value: @"2"];
  array = [NSArray arrayWithObjects: e1, e2, nil];
  test([[array cardElementsWithAttribute: @"type" havingValue: @"HOME"] count] == 1);
  test([[array cardElementsWithAttribute: @"type" havingValue: @"work"] count] == 0);
}

- (void) test_dictionary_case_insensitive
{
  NSDictionary *dict;

  dict = [NSDictionary dictionaryWithObject: @"v" forKey: @"MyKey"];
  testEquals([dict objectForCaseInsensitiveKey: @"MYKEY"], @"v");
  testEquals([dict objectForCaseInsensitiveKey: @"other"], nil);
}

- (void) test_dictionary_versit_render_ordering
{
  NSDictionary *dict, *attrDict;
  NSMutableString *buffer;
  NSArray *orderedA, *orderedZ;

  orderedA = [NSArray arrayWithObject: [NSArray arrayWithObject: @"va"]];
  orderedZ = [NSArray arrayWithObject: [NSArray arrayWithObject: @"vz"]];
  dict = [NSDictionary dictionaryWithObjectsAndKeys:
                     orderedA, @"a", orderedZ, @"z", nil];
  attrDict = [NSDictionary dictionaryWithObjectsAndKeys:
                        [NSArray arrayWithObject: @"va"], @"a",
                        [NSArray arrayWithObject: @"vz"], @"z", nil];

  buffer = [NSMutableString string];
  [dict versitRenderInString: buffer
             withKeyOrdering: [NSArray arrayWithObject: @"zz"]
                asAttributes: NO];
  testEquals(buffer, @"Z=vz;A=va");

  buffer = [NSMutableString string];
  [dict versitRenderInString: buffer
             withKeyOrdering: [NSArray arrayWithObject: @"a"]
                asAttributes: NO];
  testEquals(buffer, @"A=va;Z=vz");

  buffer = [NSMutableString string];
  [dict versitRenderInString: buffer
             withKeyOrdering: [NSArray arrayWithObject: @"z"]
                asAttributes: NO];
  testEquals(buffer, @"Z=vz;A=va");

  buffer = [NSMutableString string];
  [attrDict versitRenderInString: buffer
             withKeyOrdering: [NSArray arrayWithObject: @"a"]
                asAttributes: YES];
  testEquals(buffer, @"A=va;Z=vz");
}

- (void) test_renderer_group_prefix
{
  CardVersitRenderer *renderer;
  CardElement *element;

  renderer = AUTORELEASE([CardVersitRenderer new]);
  element = [CardElement elementWithTag: @"tel"];
  [element setGroup: @"item1"];
  [element setSingleValue: @"123" forKey: @""];
  testEquals([renderer render: element], @"item1.TEL:123\r\n");
}

- (void) test_renderer_no_tag
{
  CardVersitRenderer *renderer;
  CardElement *element;
  CardGroup *group;

  renderer = AUTORELEASE([CardVersitRenderer new]);
  element = [CardElement elementWithTag: nil];
  [element setSingleValue: @"123" forKey: @""];
  testEquals([renderer render: element], @"<NO-TAG>:123\r\n");

  group = [CardGroup groupWithTag: nil];
  [group addChild: element];
  testEquals([renderer render: group], @"BEGIN:<NO-TAG>\r\n<NO-TAG>:123\r\nEND:<NO-TAG>\r\n");
}

- (void) test_renderer_void
{
  CardVersitRenderer *renderer;

  renderer = AUTORELEASE([CardVersitRenderer new]);
  testEquals([renderer render: [CardElement elementWithTag: @"x"]], @"");
}

- (void) test_renderer_element_ordering
{
  CardVersitRenderer *renderer;
  OrderedCardGroup *group;

  renderer = AUTORELEASE([CardVersitRenderer new]);
  group = [OrderedCardGroup groupWithTag: @"g"];
  [group addChild: [CardElement simpleElementWithTag: @"a" value: @"va"]];
  [group addChild: [CardElement simpleElementWithTag: @"b" value: @"vb"]];
  [group addChild: [CardElement simpleElementWithTag: @"c" value: @"vc"]];
  testEquals([renderer render: group],
             @"BEGIN:G\r\nC:vc\r\nA:va\r\nB:vb\r\nEND:G\r\n");
}

- (void) test_renderer_attribute_quoting
{
  CardVersitRenderer *renderer;
  CardElement *element;

  renderer = AUTORELEASE([CardVersitRenderer new]);

  element = [CardElement elementWithTag: @"url"];
  [element addAttribute: @"p" value: @"http://x"];
  [element setSingleValue: @"v" forKey: @""];
  testEquals([renderer render: element], @"URL;P=\"http://x\":v\r\n");

  element = [CardElement elementWithTag: @"url"];
  [element addAttribute: @"p" value: @"a,b"];
  [element setSingleValue: @"v" forKey: @""];
  testEquals([renderer render: element], @"URL;P=\"a,b\":v\r\n");

  element = [CardElement elementWithTag: @"url"];
  [element addAttribute: @"p" value: @","];
  [element setSingleValue: @"v" forKey: @""];
  testEquals([renderer render: element], @"URL;P=\\,:v\r\n");

  element = [CardElement elementWithTag: @"url"];
  [element addAttribute: @"p" value: @","];
  [element setSingleValue: @"v" forKey: @""];
  testEquals([renderer render: element], @"URL;P=\\,:v\r\n");

  element = [CardElement elementWithTag: @"url"];
  [element addAttribute: @"q" value: @"a;b"];
  [element setSingleValue: @"v" forKey: @""];
  testEquals([renderer render: element], @"URL;Q=a\\;b:v\r\n");
}

- (void) test_renderer_newlines_in_values
{
  CardVersitRenderer *renderer;
  CardElement *element;

  renderer = AUTORELEASE([CardVersitRenderer new]);
  element = [CardElement elementWithTag: @"note"];
  [element setSingleValue: @"line1\nline2\rline3" forKey: @""];
  testEquals([renderer render: element], @"NOTE:line1\\nline2\\rline3\r\n");
}

- (void) test_sax_handler_direct
{
  NGCardsSaxHandler *handler;
  unichar buffer[2];

  buffer[0] = 'a';
  buffer[1] = 'b';

  handler = [[NGCardsSaxHandler alloc] init];
  [handler startDocument];
  test([[handler cards] count] == 0);

  [handler startGroupElement: @"vcard"];
  test([[handler cards] count] == 1);
  test([[[handler cards] objectAtIndex: 0] isKindOfClass: [CardGroup class]]);
  [handler endGroupElement];

  [handler startCollectingContent];
  [handler characters: buffer length: 2];
  [handler startCollectingContent];
  [handler characters: buffer length: 2];
  [handler characters: buffer length: 2];
  [handler endElement: @"note" namespace: nil rawName: @"note"];

  [handler startCollectingContent];
  test([handler finishCollectingContent] == nil);

  [handler startCollectingContent];
  [handler characters: buffer length: 2];
  [handler reset];
  test([[handler cards] count] == 0);

  [handler endDocument];
  [handler release];
}

@end
