#import <EOControl/EOQualifier.h>
#import <GDLContentStore/EOQualifier+GCS.h>

#import "SOGoTest.h"

@interface SOGoFolder : NSObject
@end

@interface SOGoFolder (CardDAVFilterBuilding)
+ (EOQualifier *) _cardDAVTextMatchQualifierForKeys: (NSArray *) keys
                                              value: (NSString *) value
                                         matchType: (NSString *) matchType
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

@interface TestSOGoCardDAVFilters : SOGoTest
@end

@implementation TestSOGoCardDAVFilters

- (void) test_textMatchEqualsMatchesWholeValueCaseInsensitively
{
  testEquals(SQLFor([SOGoFolder _cardDAVTextMatchQualifierForKeys: MailKeys()
                                                             value: @"Foo@Bar.com"
                                                        matchType: @"equals"
                                                          negated: NO]),
             @"UPPER(c_mail) LIKE UPPER('Foo@Bar.com')");
}

- (void) test_textMatchStartsWith
{
  testEquals(SQLFor([SOGoFolder _cardDAVTextMatchQualifierForKeys: MailKeys()
                                                             value: @"foo"
                                                        matchType: @"starts-with"
                                                          negated: NO]),
             @"UPPER(c_mail) LIKE UPPER('foo*')");
}

- (void) test_textMatchEndsWith
{
  testEquals(SQLFor([SOGoFolder _cardDAVTextMatchQualifierForKeys: MailKeys()
                                                             value: @"com"
                                                        matchType: @"ends-with"
                                                          negated: NO]),
             @"UPPER(c_mail) LIKE UPPER('*com')");
}

- (void) test_textMatchContains
{
  testEquals(SQLFor([SOGoFolder _cardDAVTextMatchQualifierForKeys: MailKeys()
                                                             value: @"foo"
                                                        matchType: @"contains"
                                                          negated: NO]),
             @"UPPER(c_mail) LIKE UPPER('*foo*')");
}

- (void) test_textMatchNegated
{
  testEquals(SQLFor([SOGoFolder _cardDAVTextMatchQualifierForKeys: MailKeys()
                                                             value: @"foo"
                                                        matchType: @"contains"
                                                          negated: YES]),
             @" NOT (UPPER(c_mail) LIKE UPPER('*foo*'))");
}

- (void) test_textMatchOnNameCoversAllNameColumns
{
  testEquals(SQLFor([SOGoFolder _cardDAVTextMatchQualifierForKeys: NameKeys()
                                                             value: @"john"
                                                        matchType: @"contains"
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

  q1 = [SOGoFolder _cardDAVTextMatchQualifierForKeys: MailKeys()
                                               value: @"foo"
                                          matchType: @"contains"
                                            negated: NO];
  q2 = [SOGoFolder _cardDAVTextMatchQualifierForKeys: MailKeys()
                                               value: @"bar"
                                          matchType: @"contains"
                                            negated: NO];
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

  q1 = [SOGoFolder _cardDAVTextMatchQualifierForKeys: MailKeys()
                                               value: @"foo"
                                          matchType: @"equals"
                                            negated: NO];
  test([SOGoFolder _cardDAVCombineQualifiers: [NSArray arrayWithObject: q1]
                                            test: @"anyof"] == q1);
}

- (void) test_combineEmpty
{
  test([SOGoFolder _cardDAVCombineQualifiers: [NSArray array] test: @"anyof"] == nil);
  test([SOGoFolder _cardDAVDefinedQualifierForKeys: [NSArray array]] == nil);
}

@end
