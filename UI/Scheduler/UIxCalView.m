/* UIxCalView.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2016 Inverse inc.
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
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */


#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSString+misc.h>
#import <NGCards/NGCards.h>

#import <SOPE/NGCards/iCalRecurrenceRule.h>

#import <Appointments/SOGoAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoMobileProvision.h>

#import "UIxCalView.h"

@interface UIxCalView (PrivateAPI)
- (NSString *) _userFolderURI;
@end

@implementation UIxCalView

- (id) init
{
  SOGoUserDefaults *ud;

  self = [super init];
  if (self)
    {
      ud = [[context activeUser] userDefaults];
      ASSIGN (timeZone, [ud timeZone]);
      ASSIGN (enabledWeekDays, [ud calendarWeekdays]);
    }

  return self;
}

- (void) dealloc
{
  [timeZone release];
  [super dealloc];
}

- (void) setCurrentView: (NSString *) theView
{
  SOGoUser *activeUser;
  NSString *module;
  SOGoUserSettings *us;
  NSMutableDictionary *moduleSettings;
  SOGoAppointmentFolders *clientObject;

  activeUser = [context activeUser];
  clientObject = [self clientObject];

  module = [clientObject nameInContainer];

  us = [activeUser userSettings];
  moduleSettings = [us objectForKey: module];
  if (!moduleSettings)
    {
      moduleSettings = [NSMutableDictionary dictionary];
      [us setObject: moduleSettings forKey: module];
    }
  if (![theView isEqualToString: (NSString*)[moduleSettings objectForKey: @"View"]])
    {
      [moduleSettings setObject: theView
			 forKey: @"View"];
      [us synchronize];
    }
}

/* defaults */

- (unsigned) dayStartHour
{
  return 0;
}

- (unsigned) dayEndHour
{
  return 23;
}

/* fetching */

- (NSCalendarDate *) startDate
{
  return [self selectedDate];
}

- (NSCalendarDate *) endDate
{
  return [[self startDate] tomorrow];
}

/* date selection & conversion */

- (NSCalendarDate *) _nextValidDate: (NSCalendarDate *) date
{
  NSCalendarDate *validDate;
  NSString *weekDay;

  validDate = [[date copy] autorelease];
  if ([enabledWeekDays count])
    {
      weekDay = iCalWeekDayString[[validDate dayOfWeek]];
      while (![enabledWeekDays containsObject: weekDay])
        {
          validDate = [validDate dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0];
          weekDay = iCalWeekDayString[[validDate dayOfWeek]];
        }
    }

  return validDate;
}

- (int) _nextValidOffset: (int) daysOffset
{
  NSCalendarDate *date;
  NSString *weekDay;
  int count, offset;

  count = (daysOffset < 0)? -1 : +1;
  offset = daysOffset;

  if ([enabledWeekDays count])
    {
      date = [[self startDate] dateByAddingYears:0 months:0 days:offset hours:0 minutes:0 seconds:0];
      weekDay = iCalWeekDayString[[date dayOfWeek]];
      while (![enabledWeekDays containsObject: weekDay])
        {
          offset += count;
          date = [date dateByAddingYears:0 months:0 days:count hours:0 minutes:0 seconds:0];
          weekDay = iCalWeekDayString[[date dayOfWeek]];
        }
    }

  return offset;
}

- (NSDictionary *) _dateQueryParametersWithOffset: (int) daysOffset
{
  NSCalendarDate *date;

  date = [[self startDate] dateByAddingYears: 0 months: 0
                           days: daysOffset
                           hours: 0 minutes: 0 seconds: 0];

  return [self queryParametersBySettingSelectedDate: date];
}

- (NSDictionary *) todayQueryParameters
{
  NSCalendarDate *today;

  today = [NSCalendarDate date];
  [today setTimeZone: timeZone];

  return [self queryParametersBySettingSelectedDate: [self _nextValidDate: today]];
}

/* Actions */

- (NSString *) _userFolderURI
{
  WOContext *ctx;
  id        obj;
  NSURL     *url;

  ctx = [self context];
  obj = [[ctx objectTraversalStack] objectAtIndex: 1];
  url = [NSURL URLWithString: [obj baseURLInContext: ctx]];
  return [[url path] stringByUnescapingURL];
}

- (id) redirectForUIDsAction
{
  NSMutableString *uri;
  NSString *uidsString, *loc, *prevMethod, *userFolderID;
  id <WOActionResults> r;
  BOOL useGroups;
  NSUInteger index;


  uidsString = [self queryParameterForKey: @"userUIDString"];
  uidsString = [uidsString stringByTrimmingSpaces];
  [self setQueryParameter: nil forKey: @"userUIDString"];

  prevMethod = [self queryParameterForKey: @"previousMethod"];
  if (prevMethod == nil)
    prevMethod = @"";

  uri = [[NSMutableString alloc] initWithString: [self _userFolderURI]];
  /* if we have more than one entry, use groups - otherwise don't */
  useGroups = [uidsString rangeOfString: @","].length > 0;
  userFolderID = [uri lastPathComponent];
  if (useGroups)
    {
      NSArray *uids;

      uids = [uidsString componentsSeparatedByString: @","];
      /* guarantee that our id is the first */
      if (((index = [uids indexOfObject: userFolderID]) != NSNotFound)
          && (index != 0))
        {
          uids = [[uids mutableCopy] autorelease];
          [(NSMutableArray *) uids removeObjectAtIndex: index];
          [(NSMutableArray *) uids insertObject: userFolderID atIndex: 0];
          uidsString = [uids componentsJoinedByString: @","];
        }
      [uri appendString: @"Groups/_custom_"];
      [uri appendString: uidsString];
      [uri appendString: @"/"];
    }
  else
    {
      /* check if lastPathComponent is the base that we want to have */
      if ((([uidsString length] != 0)
           && (![userFolderID isEqualToString: uidsString])))
        {
          NSRange r;

          /* uri ends with an '/', so we have to adjust the range a little */
          r = NSMakeRange(0, [uri length] - 1);
          r = [uri rangeOfString: @"/"
                   options: NSBackwardsSearch
                   range: r];
          r = NSMakeRange(r.location + 1, [uri length] - r.location - 2);
          [uri replaceCharactersInRange: r withString: uidsString];
        }
    }
  [uri appendString: @"Calendar/"];
  [uri appendString: prevMethod];

  loc = [self completeHrefForMethod: uri]; /* this might return uri! */
  r = [self redirectToLocation: loc];
  [uri release];
  return r;
}

- (WOResponse *) mobileconfigAction
{
  SOGoAppointmentFolders *folders;
  NSString *davURL, *plistContent, *disposition;
  WOResponse *response;

  folders = [self clientObject];
  davURL = [[folders container] davURLAsString];
  plistContent = [SOGoMobileProvision plistForCalendarsWithContext: context andPath: davURL andName: [folders owner]];
 
  if (nil != plistContent) {
    response = [self responseWithStatus: 200
                            andString: plistContent];
    [response setHeader: @"application/x-plist; charset=utf-8" 
                forKey: @"content-type"];
    disposition = [NSString stringWithString: @"attachment; filename=\"calendar.mobileconfig\""];
    [response setHeader: disposition forKey: @"Content-Disposition"];
  } else {
    response = [self responseWithStatus: 500
                            andString: @"Error while generating profile"];
  }

  return response;
}

@end /* UIxCalView */
