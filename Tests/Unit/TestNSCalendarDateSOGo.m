#import "SOGoTest.h"

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSTimeZone.h>

#import <SOGo/NSCalendarDate+SOGo.h>

@interface SOGoCalendarFakeUserDefaults : NSObject
@end

@implementation SOGoCalendarFakeUserDefaults

- (NSTimeZone *) timeZone
{
  return [NSTimeZone timeZoneForSecondsFromGMT: 7200];
}

- (unsigned int) dayStartHour
{
  return 8;
}

@end

@interface SOGoCalendarFakeUser : NSObject
@end

@implementation SOGoCalendarFakeUser

- (id) userDefaults
{
  return [SOGoCalendarFakeUserDefaults new];
}

@end

@interface TestNSCalendarDateSOGo : SOGoTest
@end

@implementation TestNSCalendarDateSOGo

- (void) test_date_from_short_date_string_and_time
{
  NSCalendarDate *date;
  NSTimeZone *gmt;

  gmt = [NSTimeZone timeZoneWithName: @"GMT"];
  date = [NSCalendarDate dateFromShortDateString: @"20200229"
                               andShortTimeString: @"1230"
                                       inTimeZone: gmt];
  test([date yearOfCommonEra] == 2020);
  test([date monthOfYear] == 2);
  test([date dayOfMonth] == 29);
  test([date hourOfDay] == 12);
  test([date minuteOfHour] == 30);
  testEquals([date shortDateString], @"20200229");
}

- (void) test_date_from_short_date_string_without_time
{
  NSCalendarDate *date;
  NSTimeZone *gmt;

  gmt = [NSTimeZone timeZoneWithName: @"GMT"];
  date = [NSCalendarDate dateFromShortDateString: @"20200101"
                               andShortTimeString: nil
                                       inTimeZone: gmt];
  test([date yearOfCommonEra] == 2020);
  test([date hourOfDay] == 12);
  test([date minuteOfHour] == 0);
  date = [NSCalendarDate dateFromShortDateString: @"20200101"
                               andShortTimeString: @"123"
                                       inTimeZone: gmt];
  test([date hourOfDay] == 12);
  test([date minuteOfHour] == 0);
}

- (void) test_date_from_short_date_string_boundaries
{
  NSCalendarDate *date;
  NSTimeZone *gmt;

  gmt = [NSTimeZone timeZoneWithName: @"GMT"];
  date = [NSCalendarDate dateFromShortDateString: @"00010101"
                               andShortTimeString: @"0000"
                                       inTimeZone: gmt];
  test([date yearOfCommonEra] == 1);
  test([date monthOfYear] == 1);
  test([date dayOfMonth] == 1);
  test([date hourOfDay] == 0);
  test([date minuteOfHour] == 0);
  testEquals([date shortDateString], @"00010101");
  date = [NSCalendarDate dateFromShortDateString: @"99991231"
                               andShortTimeString: @"2359"
                                       inTimeZone: gmt];
  test([date yearOfCommonEra] == 9999);
  test([date monthOfYear] == 12);
  test([date dayOfMonth] == 31);
  test([date hourOfDay] == 23);
  test([date minuteOfHour] == 59);
  testEquals([date shortDateString], @"99991231");
}

- (void) test_date_from_short_date_string_invalid
{
  NSCalendarDate *date;
  NSTimeZone *gmt;

  gmt = [NSTimeZone timeZoneWithName: @"GMT"];
  date = [NSCalendarDate dateFromShortDateString: @"20200229"
                               andShortTimeString: @"0000"
                                       inTimeZone: gmt];
  testEquals([date shortDateString], @"20200229");
  date = [NSCalendarDate dateFromShortDateString: @"20210229"
                               andShortTimeString: @"0000"
                                       inTimeZone: gmt];
  testEquals([date shortDateString], @"20210301");
  date = [NSCalendarDate dateFromShortDateString: @"20201301"
                               andShortTimeString: @"0000"
                                       inTimeZone: gmt];
  testEquals([date shortDateString], @"20210101");
  date = [NSCalendarDate dateFromShortDateString: @"20200132"
                               andShortTimeString: @"0000"
                                       inTimeZone: gmt];
  testEquals([date shortDateString], @"20200201");
  date = [NSCalendarDate dateFromShortDateString: @"20200431"
                               andShortTimeString: @"0000"
                                       inTimeZone: gmt];
  testEquals([date shortDateString], @"20200501");
  date = [NSCalendarDate dateFromShortDateString: @"abcdefgh"
                               andShortTimeString: @"0000"
                                       inTimeZone: gmt];
  testEquals([date shortDateString], @"00000100");
  date = [NSCalendarDate dateFromShortDateString: @"20200101"
                               andShortTimeString: @"2530"
                                       inTimeZone: gmt];
  test([date dayOfMonth] == 2);
  test([date hourOfDay] == 1);
  test([date minuteOfHour] == 30);
  date = [NSCalendarDate dateFromShortDateString: @"20200101"
                               andShortTimeString: @"0099"
                                       inTimeZone: gmt];
  test([date hourOfDay] == 1);
  test([date minuteOfHour] == 39);
}

- (void) test_date_from_nil_or_empty_date_string
{
  NSCalendarDate *date, *now;
  NSTimeZone *gmt;

  gmt = [NSTimeZone timeZoneWithName: @"GMT"];
  now = [NSCalendarDate calendarDate];
  [now setTimeZone: gmt];
  date = [NSCalendarDate dateFromShortDateString: nil
                               andShortTimeString: @"0101"
                                       inTimeZone: gmt];
  test([date yearOfCommonEra] == [now yearOfCommonEra]);
  test([date monthOfYear] == [now monthOfYear]);
  test([date dayOfMonth] == [now dayOfMonth]);
  test([date hourOfDay] == 1);
  test([date minuteOfHour] == 1);
  date = [NSCalendarDate dateFromShortDateString: @""
                               andShortTimeString: nil
                                       inTimeZone: gmt];
  test([date yearOfCommonEra] == [now yearOfCommonEra]);
  test([date monthOfYear] == [now monthOfYear]);
  test([date dayOfMonth] == [now dayOfMonth]);
  test([date hourOfDay] == 12);
}

- (void) test_is_date_in_same_month
{
  NSCalendarDate *date, *other;
  NSTimeZone *gmt;

  gmt = [NSTimeZone timeZoneWithName: @"GMT"];
  date = [NSCalendarDate dateWithYear: 2020 month: 3 day: 15
                        hour: 10 minute: 0 second: 0 timeZone: gmt];
  other = [NSCalendarDate dateWithYear: 2020 month: 3 day: 20
                         hour: 12 minute: 30 second: 0 timeZone: gmt];
  test([date isDateInSameMonth: other]);
  test([other isDateInSameMonth: date]);
  other = [NSCalendarDate dateWithYear: 2020 month: 4 day: 1
                         hour: 0 minute: 0 second: 0 timeZone: gmt];
  test(![date isDateInSameMonth: other]);
  other = [NSCalendarDate dateWithYear: 2019 month: 3 day: 15
                         hour: 0 minute: 0 second: 0 timeZone: gmt];
  test(![date isDateInSameMonth: other]);
}

- (void) test_short_date_string_padding
{
  NSCalendarDate *date;
  NSTimeZone *gmt;

  gmt = [NSTimeZone timeZoneWithName: @"GMT"];
  date = [NSCalendarDate dateWithYear: 2020 month: 1 day: 5
                        hour: 0 minute: 0 second: 0 timeZone: gmt];
  testEquals([date shortDateString], @"20200105");
}

- (void) test_begin_of_day_for_user
{
  NSCalendarDate *date, *beginDay;
  NSTimeZone *userTimeZone;

  userTimeZone = [NSTimeZone timeZoneForSecondsFromGMT: 7200];
  date = [NSCalendarDate dateWithYear: 2020 month: 5 day: 15
                        hour: 17 minute: 45 second: 9 timeZone: userTimeZone];
  beginDay = [date beginOfDayForUser: (SOGoUser *) [SOGoCalendarFakeUser new]];
  test([beginDay yearOfCommonEra] == 2020);
  test([beginDay monthOfYear] == 5);
  test([beginDay dayOfMonth] == 15);
  test([beginDay hourOfDay] == 8);
  test([beginDay minuteOfHour] == 0);
}

- (void) test_rfc822_date_string
{
  NSCalendarDate *date;
  NSTimeZone *gmt, *india, *newYork;

  gmt = [NSTimeZone timeZoneWithName: @"GMT"];
  india = [NSTimeZone timeZoneForSecondsFromGMT: 19800];
  newYork = [NSTimeZone timeZoneForSecondsFromGMT: -18000];
  date = [NSCalendarDate dateWithYear: 2020 month: 1 day: 1
                        hour: 0 minute: 0 second: 0 timeZone: gmt];
  testEquals([date rfc822DateString], @"Wed, 01 Jan 2020 00:00:00 +0000");
  date = [NSCalendarDate dateWithYear: 2020 month: 1 day: 1
                        hour: 0 minute: 0 second: 0 timeZone: india];
  testEquals([date rfc822DateString], @"Wed, 01 Jan 2020 00:00:00 +0530");
  date = [NSCalendarDate dateWithYear: 2019 month: 12 day: 31
                        hour: 19 minute: 30 second: 42 timeZone: newYork];
  testEquals([date rfc822DateString], @"Tue, 31 Dec 2019 19:30:42 -0500");
}

- (void) test_iso8601_date_string
{
  NSCalendarDate *date;
  NSTimeZone *gmt, *india, *newYork;

  gmt = [NSTimeZone timeZoneWithName: @"GMT"];
  india = [NSTimeZone timeZoneForSecondsFromGMT: 19800];
  newYork = [NSTimeZone timeZoneForSecondsFromGMT: -18000];
  date = [NSCalendarDate dateWithYear: 2020 month: 1 day: 1
                        hour: 0 minute: 0 second: 0 timeZone: gmt];
  testEquals([date iso8601DateString], @"2020-01-01T00:00+00:00");
  date = [NSCalendarDate dateWithYear: 2020 month: 1 day: 1
                        hour: 5 minute: 30 second: 0 timeZone: india];
  testEquals([date iso8601DateString], @"2020-01-01T05:30+05:30");
  date = [NSCalendarDate dateWithYear: 2019 month: 12 day: 31
                        hour: 19 minute: 0 second: 0 timeZone: newYork];
  testEquals([date iso8601DateString], @"2019-12-31T19:00-05:00");
}

- (void) test_distant_future_and_past
{
  test([NSCalendarDate distantFuture] != nil);
  test([[NSCalendarDate distantFuture] timeIntervalSinceReferenceDate] == 1073741823.0);
  test([NSCalendarDate distantPast] != nil);
  test([[NSCalendarDate distantPast] timeIntervalSinceReferenceDate] == -1073741823.0);
  test([NSCalendarDate distantFuture] == [NSCalendarDate distantFuture]);
  test([NSCalendarDate distantPast] == [NSCalendarDate distantPast]);
  test(![[NSCalendarDate distantFuture] isEqual: [NSCalendarDate distantPast]]);
}

@end
