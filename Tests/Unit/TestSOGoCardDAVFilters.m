#import <EOControl/EOQualifier.h>
#import <GDLContentStore/EOQualifier+GCS.h>

#import "SOGoTest.h"

@interface SOGoFolder : NSObject
@end

@interface SOGoFolder (CardDAVFilterBuilding)
+ (EOQualifier *) _cardDAVTextMatchQualifierForKeys: (NSArray *) keys
                                              value: (NSString *) value
                                         matchType: (NSString *) matchType
                                         collation: (NSString *) collation
                                   commaSeparated: (BOOL) commaSeparated
                                           negated: (BOOL) negated;
+ (EOQualifier *) _cardDAVDefinedQualifierForKeys: (NSArray *) keys;
+ (EOQualifier *) _cardDAVNotDefinedQualifierForKeys: (NSArray *) keys;
+ (EOQualifier *) _cardDAVCombineQualifiers: (NSArray *) qualifiers
                                       test: (NSString *) test;
@end

static NSArray *MailKeys(void)
{
  return [NSArray arrayWithObject: @"c_mail"];
}

static NSArray *NameKeys(void)
{
  return [NSArray arrayWithObjects: @"c_sn", @"c_givenname", @"c_cn", nil];
}

static NSString *SQLFor(EOQualifier *qualifier)
{
  NSMutableString *sql;

  sql = [NSMutableString stringWithCapacity: 128];
  [qualifier appendSQLToString: sql];

  return sql;
}

static EOQualifier *MailMatch(NSString *value, NSString *matchType,
                              NSString *collation, BOOL commaSeparated, BOOL negated)
{
  return [SOGoFolder _cardDAVTextMatchQualifierForKeys: MailKeys()
                                                 value: value
                                            matchType: matchType
                                            collation: collation
                                      commaSeparated: commaSeparated
                                              negated: negated];
}

@interface TestSOGoCardDAVFilters : SOGoTest
@end

@implementation TestSOGoCardDAVFilters

- (void) test_textMatchEqualsMatchesWholeValueCaseInsensitively
{
  testEquals(SQLFor(MailMatch(@"Foo@Bar.com", @"equals", nil, NO, NO)),
             @"UPPER(c_mail) LIKE UPPER('Foo@Bar.com')");
}

- (void) test_textMatchEqualsOnCommaSeparatedValues
{
  testEquals(SQLFor(MailMatch(@"a@b.c", @"equals", nil, YES, NO)),
             @"(UPPER(c_mail) LIKE UPPER('a@b.c')) OR (UPPER(c_mail) LIKE UPPER('a@b.c,*')) OR (UPPER(c_mail) LIKE UPPER('*,a@b.c')) OR (UPPER(c_mail) LIKE UPPER('*,a@b.c,*'))");
}

- (void) test_textMatchStartsWith
{
  testEquals(SQLFor(MailMatch(@"foo", @"starts-with", nil, NO, NO)),
             @"UPPER(c_mail) LIKE UPPER('foo*')");
  testEquals(SQLFor(MailMatch(@"email2", @"starts-with", nil, YES, NO)),
             @"(UPPER(c_mail) LIKE UPPER('email2*')) OR (UPPER(c_mail) LIKE UPPER('*,email2*'))");
}

- (void) test_textMatchEndsWith
{
  testEquals(SQLFor(MailMatch(@"com", @"ends-with", nil, NO, NO)),
             @"UPPER(c_mail) LIKE UPPER('*com')");
  testEquals(SQLFor(MailMatch(@"a@b", @"ends-with", nil, YES, NO)),
             @"(UPPER(c_mail) LIKE UPPER('*a@b')) OR (UPPER(c_mail) LIKE UPPER('*a@b,*'))");
}

- (void) test_textMatchContains
{
  testEquals(SQLFor(MailMatch(@"foo", @"contains", nil, NO, NO)),
             @"UPPER(c_mail) LIKE UPPER('*foo*')");
}

- (void) test_textMatchOctetCollationIsCaseSensitive
{
  testEquals(SQLFor(MailMatch(@"foo", @"contains", @"i;octet", NO, NO)),
             @"c_mail LIKE '*foo*'");
}

- (void) test_textMatchNegatedKeepsNullRows
{
  testEquals(SQLFor(MailMatch(@"foo", @"contains", nil, NO, YES)),
             @"( NOT (UPPER(c_mail) LIKE UPPER('*foo*'))) OR (c_mail IS NULL)");
}

- (void) test_textMatchNegatedOnNameCoversEveryColumn
{
  testEquals(SQLFor([SOGoFolder _cardDAVTextMatchQualifierForKeys: NameKeys()
                                                             value: @"john"
                                                        matchType: @"contains"
                                                        collation: nil
                                                  commaSeparated: NO
                                                          negated: YES]),
             @"(( NOT (UPPER(c_sn) LIKE UPPER('*john*'))) OR (c_sn IS NULL)) AND (( NOT (UPPER(c_givenname) LIKE UPPER('*john*'))) OR (c_givenname IS NULL)) AND (( NOT (UPPER(c_cn) LIKE UPPER('*john*'))) OR (c_cn IS NULL))");
}

- (void) test_textMatchOnNameCoversAllNameColumns
{
  testEquals(SQLFor([SOGoFolder _cardDAVTextMatchQualifierForKeys: NameKeys()
                                                             value: @"john"
                                                        matchType: @"contains"
                                                        collation: nil
                                                  commaSeparated: NO
                                                          negated: NO]),
             @"(UPPER(c_sn) LIKE UPPER('*john*')) OR (UPPER(c_givenname) LIKE UPPER('*john*')) OR (UPPER(c_cn) LIKE UPPER('*john*'))");
}

- (void) test_definedEmail
{
  testEquals(SQLFor([SOGoFolder _cardDAVDefinedQualifierForKeys: MailKeys()]),
             @"c_mail != ''");
}

- (void) test_definedName
{
  testEquals(SQLFor([SOGoFolder _cardDAVDefinedQualifierForKeys: NameKeys()]),
             @"(c_sn != '') OR (c_givenname != '') OR (c_cn != '')");
}

- (void) test_notDefinedEmail
{
  testEquals(SQLFor([SOGoFolder _cardDAVNotDefinedQualifierForKeys: MailKeys()]),
             @"(c_mail = '') OR (c_mail IS NULL)");
}

- (void) test_notDefinedName
{
  testEquals(SQLFor([SOGoFolder _cardDAVNotDefinedQualifierForKeys: NameKeys()]),
             @"((c_sn = '') OR (c_sn IS NULL)) AND ((c_givenname = '') OR (c_givenname IS NULL)) AND ((c_cn = '') OR (c_cn IS NULL))");
}

- (void) test_combineAnyOf
{
  EOQualifier *q1, *q2, *combined;
  NSArray *qualifiers;

  q1 = MailMatch(@"foo", @"contains", nil, NO, NO);
  q2 = MailMatch(@"bar", @"contains", nil, NO, NO);
  qualifiers = [NSArray arrayWithObjects: q1, q2, nil];
  combined = [SOGoFolder _cardDAVCombineQualifiers: qualifiers test: @"anyof"];
  testEquals(SQLFor(combined),
             @"(UPPER(c_mail) LIKE UPPER('*foo*')) OR (UPPER(c_mail) LIKE UPPER('*bar*'))");

  combined = [SOGoFolder _cardDAVCombineQualifiers: qualifiers test: @"allof"];
  testEquals(SQLFor(combined),
             @"(UPPER(c_mail) LIKE UPPER('*foo*')) AND (UPPER(c_mail) LIKE UPPER('*bar*'))");
}

- (void) test_combineSingleQualifier
{
  EOQualifier *q1;

  q1 = MailMatch(@"foo", @"equals", nil, NO, NO);
  test([SOGoFolder _cardDAVCombineQualifiers: [NSArray arrayWithObject: q1]
                                        test: @"anyof"] == q1);
}

- (void) test_combineEmpty
{
  test([SOGoFolder _cardDAVCombineQualifiers: [NSArray array] test: @"anyof"] == nil);
  test([SOGoFolder _cardDAVDefinedQualifierForKeys: [NSArray array]] == nil);
  test(MailMatch(@"foo", @"contains", nil, NO, NO) != nil);
}

@end
