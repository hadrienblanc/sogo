/* UIxComponentEditor.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2015 Inverse inc.
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

#import <Foundation/NSValue.h>
#import <Foundation/NSURL.h>

#import <NGCards/iCalToDo.h>
#import <NGCards/iCalTrigger.h>

#import <NGCards/NSString+NGCards.h>
#import <NGCards/NSCalendarDate+NGCards.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WOResponse.h>
#import <NGExtensions/NSCalendarDate+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSString+misc.h>

#import <Appointments/iCalAlarm+SOGo.h>
#import <Appointments/iCalEntityObject+SOGo.h>
#import <Appointments/iCalPerson+SOGo.h>
#import <Appointments/SOGoWebAppointmentFolder.h>
#import <Appointments/SOGoAppointmentFolders.h>
#import <Appointments/SOGoTaskObject.h>
#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserManager.h>
#import <SOGo/SOGoPermissions.h>
#import <SOGo/WOResourceManager+SOGo.h>

#import "UIxComponentEditor.h"

#define componentReadableWritable  0
#define componentOwnerIsInvited    1
#define componentReadableOnly      2

static NSArray *reminderItems = nil;
static NSArray *reminderValues = nil;

@implementation UIxComponentEditor

+ (void) initialize
{
  if (!reminderItems && !reminderValues)
    {
      reminderItems = [NSArray arrayWithObjects:
			       @"5_MINUTES_BEFORE",
			       @"10_MINUTES_BEFORE",
			       @"15_MINUTES_BEFORE",
			       @"30_MINUTES_BEFORE",
			       @"45_MINUTES_BEFORE",
			       @"-",
			       @"1_HOUR_BEFORE",
			       @"2_HOURS_BEFORE",
			       @"5_HOURS_BEFORE",
			       @"15_HOURS_BEFORE",
			       @"-",
			       @"1_DAY_BEFORE",
			       @"2_DAYS_BEFORE",
			       @"1_WEEK_BEFORE",
			       @"-",
			       @"CUSTOM",
			       nil];
      reminderValues = [NSArray arrayWithObjects:
				@"-PT5M",
				@"-PT10M",
				@"-PT15M",
				@"-PT30M",
				@"-PT45M",
				@"",
				@"-PT1H",
				@"-PT2H",
				@"-PT5H",
				@"-PT15H",
				@"",
				@"-P1D",
				@"-P2D",
				@"-P1W",
				@"",
				@"",
				nil];

      [reminderItems retain];
      [reminderValues retain];
    }
}

- (id) init
{
  if ((self = [super init]))
    {
      component = nil;
      componentCalendar = nil;
    }

  return self;
}

- (void) dealloc
{
  [component release];
  [componentCalendar release];

  [super dealloc];
}

- (id) initWithContext: (WOContext *) _context
{
  if ((self = [super initWithContext: _context]))
    {
      component = [[self clientObject] occurence];
      [[component parent] retain];

      componentCalendar = [[self clientObject] container];
      if ([componentCalendar isKindOfClass: [SOGoCalendarComponent class]])
        componentCalendar = [componentCalendar container];
      [componentCalendar retain];
    }

  return self;
}

- (BOOL) isChildOccurrence
{
  return [[self clientObject] isKindOfClass: [SOGoComponentOccurence class]];
}

- (NSNumber *) reply
{
  NSString *owner, *ownerEmail;
  SOGoUserManager *um;
  iCalPerson *ownerAsAttendee;
  iCalPersonPartStat participationStatus;

  um = [SOGoUserManager sharedUserManager];
  owner = [componentCalendar ownerInContext: context];
  ownerEmail = [um getEmailForUID: owner];
  ownerAsAttendee = [component findAttendeeWithEmail: (id)ownerEmail];
  participationStatus = [ownerAsAttendee participationStatus];

  return [NSNumber numberWithInt: participationStatus];
}

/* contact editor compatibility */

- (void) _handleAttendeesEdition
{
  NSMutableArray *newAttendees;
  NSUInteger count, max;
  NSString *currentEmail;
  iCalPerson *currentAttendee;
  NSString *json, *role, *partstat;
  NSDictionary *attendeesData;
  NSArray *attendees;
  NSDictionary *currentData;
  WORequest *request;

  request = [context request];
  json = [request formValueForKey: @"attendees"];
  if ([json length])
    {
      attendees = [NSArray array];
      attendeesData = [json objectFromJSONString];
      if (attendeesData && [attendeesData isKindOfClass: [NSDictionary class]])
	{
	  newAttendees = [NSMutableArray array];
	  attendees = [attendeesData allValues];
	  max = [attendees count];
	  for (count = 0; count < max; count++)
	    {
	      currentData = [attendees objectAtIndex: count];
	      currentEmail = [currentData objectForKey: @"email"];
              if ([currentEmail length] > 0)
                {
                  role = [[currentData objectForKey: @"role"] uppercaseString];
                  if (!role)
                    role = @"REQ-PARTICIPANT";
                  if ([role isEqualToString: @"NON-PARTICIPANT"])
                    partstat = @"";
                  else
                    {
                      partstat = [[currentData objectForKey: @"partstat"]
                                   uppercaseString];
                      if (!partstat)
                        partstat = @"NEEDS-ACTION";
                    }
                  currentAttendee = [component findAttendeeWithEmail: currentEmail];
                  if (!currentAttendee)
                    {
                      currentAttendee = [iCalPerson elementWithTag: @"attendee"];
                      [currentAttendee setCn: [currentData objectForKey: @"name"]];
                      [currentAttendee setEmail: currentEmail];
                    }
                  [currentAttendee
                    setRsvp: ([role isEqualToString: @"NON-PARTICIPANT"]
                              ? @"FALSE"
                              : @"TRUE")];
                  [currentAttendee setRole: role];
                  [currentAttendee setPartStat: partstat];
                  [newAttendees addObject: currentAttendee];
                }
	    }
	  [component setAttendees: newAttendees];
	}
    }
}

- (void) _handleOrganizer
{
  NSString *owner, *login, *currentEmail;
  iCalPerson *organizer;
  BOOL isOwner;

  owner = [componentCalendar ownerInContext: context];
  login = [[context activeUser] login];
  isOwner = [owner isEqualToString: login];
  currentEmail = [[[context activeUser] allEmails] objectAtIndex: 0];

  if ([[component attendees] count] > 0)
    {
      SOGoUser *user;
      id identity;

      organizer = [iCalPerson elementWithTag: @"organizer"];
      [component setOrganizer: organizer];

      user = [SOGoUser userWithLogin: owner roles: nil];
      identity = [user defaultIdentity];
      [organizer setCn: [identity objectForKey: @"fullName"]]; 
      [organizer setEmail: [identity  objectForKey: @"email"]];

      if (!isOwner)
        {
          NSString *quotedEmail;
	  
          quotedEmail = [NSString stringWithFormat: @"\"MAILTO:%@\"",
                                  currentEmail];
          [organizer setValue: 0 ofAttribute: @"SENT-BY"
                           to: quotedEmail];
        }
    }
  else
    {
      organizer = nil;
    }
  [component setOrganizer: organizer];

  // In case of a new component, if the current user isn't the owner of the calendar, we
  // add the "X-SOGo-Component-Created-By: <email address>" attribute
  if ([[self clientObject] isNew] &&
      !isOwner &&
      [currentEmail length])
    {
      [component addChild: [CardElement simpleElementWithTag: @"X-SOGo-Component-Created-By"
                                                       value: currentEmail]];
    }
}

- (NSDictionary *) alarm
{
  NSArray *attendees;
  NSMutableDictionary *alarmData;
  NSString *ownerId, *email;
  iCalAlarm *anAlarm;
  iCalPerson *aAttendee;
  iCalTrigger *trigger;
  SOGoUser *owner;
  BOOL emailOrganizer, emailAttendees;
  int count, max;

  alarmData = nil;
  if ([component hasAlarms])
    {
      anAlarm = [component firstSupportedAlarm];
      trigger = [anAlarm trigger];
      if (![[trigger valueType] length] || [[trigger valueType] caseInsensitiveCompare: @"DURATION"] == NSOrderedSame)
        {
          alarmData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             [[anAlarm action] lowercaseString], @"action",
                                           nil];
          [alarmData addEntriesFromDictionary: [trigger asDictionary]];

          emailOrganizer = NO;
          emailAttendees = NO;
          attendees = [anAlarm attendees];
          ownerId = [[self clientObject] ownerInContext: nil];
          owner = [SOGoUser userWithLogin: ownerId];
          email = [[owner defaultIdentity] objectForKey: @"email"];
          max = [attendees count];
          for (count = 0;
               !(emailOrganizer && emailAttendees)
                 && count < max;
               count++)
            {
              aAttendee = [attendees objectAtIndex: count];
              if ([[aAttendee rfc822Email] isEqualToString: email])
                emailOrganizer = YES;
              else
                emailAttendees = YES;
            }
          [alarmData setObject: [NSNumber numberWithBool: emailOrganizer] forKey: @"organizer"];
          [alarmData setObject: [NSNumber numberWithBool: emailAttendees] forKey: @"attendees"];
        }
    }

  return alarmData;
}

- (NSArray *) attachUrls
{
  return [component attachUrlsForEditor];
}

- (void) setAttributes: (NSDictionary *) data
{
  NSCalendarDate *now;
  NSMutableDictionary *dataWithOwner;
  NSString *owner;
  SOGoAppointmentFolders *folders;
  id destinationCalendar;

  now = [NSCalendarDate calendarDate];
  owner = [componentCalendar ownerInContext: context];

  // Append the calendar's owner to the data as it's required when setting alarms
  dataWithOwner = [NSMutableDictionary dictionaryWithDictionary: data];
  [dataWithOwner setObject: owner forKey: @"owner"];
  [component setAttributes: dataWithOwner inContext: context];

  destinationCalendar = [data objectForKey: @"destinationCalendar"];
  if ([destinationCalendar isKindOfClass: [NSString class]])
    {
      folders = [[context activeUser] calendarsFolderInContext: context];
      componentCalendar = [folders lookupName: [destinationCalendar stringValue]
                                    inContext: context
                                      acquire: 0];
      [componentCalendar retain];

    }

  [self _handleOrganizer];

  //Be careful. The way sogo works, it only uses the property ATTACH for the url.
  //But the other property URL, in the ics, will also be seen as an ATTACH in the UI.
  //To avoid having both ATTACH and URL with the same uri, check the presence and value of URL first.
  if ([[data objectForKey: @"attachUrls"] isKindOfClass: [NSArray class]])
    [component setAttachUrlsFromEditor: [data objectForKey: @"attachUrls"]];

  if ([[self clientObject] isNew])
    {
      [component setCreated: now];
      [component setTimeStampAsDate: now];
    }
  [component setLastModified: now];
}

- (int) ownerIsAttendee: (SOGoUser *) ownerUser
       andClientObject: (SOGoContentObject
                         <SOGoComponentOccurence> *) clientObject
{
 BOOL isOrganizer;
 iCalPerson *ownerAttendee;
 int rc;

 rc = 0;

 isOrganizer = [component userIsOrganizer: ownerUser];
 if (isOrganizer)
   isOrganizer = ![ownerUser hasEmail: [[component organizer] sentBy]];

 if (!isOrganizer && ![[component tag] isEqualToString: @"VTODO"])
   {
     ownerAttendee = [component userAsAttendee: ownerUser];
     if (ownerAttendee)
       rc = 1;
   }

 return rc;
}

- (int) delegateIsAttendee: (SOGoUser *) ownerUser
          andClientObject: (SOGoContentObject
                            <SOGoComponentOccurence> *) clientObject
{
 SoSecurityManager *sm;
 iCalPerson *ownerAttendee;
 int rc;

 rc = componentReadableWritable;

 sm = [SoSecurityManager sharedSecurityManager];
 if (![sm validatePermission: SOGoCalendarPerm_ModifyComponent
                    onObject: clientObject
                   inContext: context])
   rc = [self ownerIsAttendee: ownerUser
              andClientObject: clientObject];
 else if (![sm validatePermission: SOGoCalendarPerm_RespondToComponent
                         onObject: clientObject
                        inContext: context])
   {
     ownerAttendee = [component userAsAttendee: ownerUser];
     if ([[ownerAttendee rsvp] isEqualToString: @"true"]
         && ![component userIsOrganizer: ownerUser])
       rc = componentOwnerIsInvited;
     else
       rc = componentReadableOnly;
   }
 else
   rc = componentReadableOnly;

 return rc;
}

- (int) getEventRWType
{
  SOGoContentObject <SOGoComponentOccurence> *clientObject;
  SOGoUser *ownerUser;
  int rc;

  clientObject = [self clientObject];
  ownerUser = [SOGoUser userWithLogin: [clientObject ownerInContext: context]];
  if ([[clientObject container] isKindOfClass: [SOGoWebAppointmentFolder class]])
    rc = componentReadableOnly;
  else
    {
      if ([ownerUser isEqual: [context activeUser]])
        rc = [self ownerIsAttendee: ownerUser
                   andClientObject: clientObject];
      else
        rc = [self delegateIsAttendee: ownerUser
                      andClientObject: clientObject];
    }

  return rc;
}

- (BOOL) isEditable
{
 return [self getEventRWType] == componentReadableWritable;
}

- (BOOL) isErasable
{
  NSString *owner, *userLogin;

  userLogin = [[context activeUser] login];
  owner = [componentCalendar ownerInContext: context];

  return ([owner isEqualToString: userLogin] || [[componentCalendar aclsForUser: userLogin] containsObject: SOGoRole_ObjectEraser]);
}

- (BOOL) userHasRSVP
{
  return ([self getEventRWType] == componentOwnerIsInvited);
}

// returns the raw content of the object
- (WOResponse *) rawAction
{
  NSMutableString *content;
  WOResponse *response;

  content = [NSMutableString string];
  response = [context response];

  [content appendFormat: @"%@", [[self clientObject] contentAsString]];
  [response setHeader: @"text/plain; charset=utf-8" 
            forKey: @"content-type"];
  [response appendContentString: [content stringByEscapingHTMLString]];

  return response;
}

+ (NSArray *) reminderValues
{
  return reminderValues;
}

@end
