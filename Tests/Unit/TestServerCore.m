#import <Foundation/Foundation.h>
#import <Foundation/NSFileManager.h>

#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/NSException+HTTP.h>

#import <DOM/DOMProtocols.h>
#import <DOM/DOMElement.h>
#import <DOM/DOMDocument.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SOGo/NSObject+DAV.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/SOGoPermissions.h>

#import <SOGo/SOGoCache.h>
#import <SOGo/SOGoContentObject.h>
#import <SOGo/SOGoDomainDefaults.h>
#import <SOGo/SOGoFolder.h>
#import <SOGo/SOGoGCSFolder.h>
#import <SOGo/SOGoObject.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>

#import "SOGoTest.h"

@interface StubServerCoreRequest : NSObject
{
  NSString *methodValue;
  NSDictionary *headersValue;
  NSString *uriValue;
  NSDictionary *formValuesValue;
  BOOL webDAVValue;
  BOOL iCal4Value;
  BOOL defaultHandlerValue;
  NSString *appNameValue;
  id domDocumentValue;
  id bodyValue;
}
+ (StubServerCoreRequest *) requestWithMethod: (NSString *) method;
+ (StubServerCoreRequest *) requestWithMethod: (NSString *) method
				       headers: (NSDictionary *) headers;
- (void) setUri: (NSString *) uri;
- (void) setFormValues: (NSDictionary *) formValues;
- (void) setWebDAV: (BOOL) webDAV;
- (void) setICal4: (BOOL) iCal4;
- (void) setHandledByDefaultHandler: (BOOL) flag;
- (void) setApplicationName: (NSString *) appName;
@end

@implementation StubServerCoreRequest

+ (StubServerCoreRequest *) requestWithMethod: (NSString *) method
{
  return [self requestWithMethod: method headers: nil];
}

+ (StubServerCoreRequest *) requestWithMethod: (NSString *) method
				     headers: (NSDictionary *) headers
{
  StubServerCoreRequest *request;

  request = [[StubServerCoreRequest new] autorelease];
  request->methodValue = [method retain];
  request->headersValue = [headers retain];

  return request;
}

- (void) dealloc
{
  [methodValue release];
  [headersValue release];
  [uriValue release];
  [formValuesValue release];
  [appNameValue release];
  [domDocumentValue release];
  [bodyValue release];
  [super dealloc];
}

- (void) setUri: (NSString *) uri
{
  ASSIGN (uriValue, uri);
}

- (void) setFormValues: (NSDictionary *) formValues
{
  ASSIGN (formValuesValue, formValues);
}

- (void) setWebDAV: (BOOL) webDAV
{
  webDAVValue = webDAV;
}

- (void) setICal4: (BOOL) iCal4
{
  iCal4Value = iCal4;
}

- (void) setHandledByDefaultHandler: (BOOL) flag
{
  defaultHandlerValue = flag;
}

- (void) setApplicationName: (NSString *) appName
{
  ASSIGN (appNameValue, appName);
}

- (void) setDOMDocument: (id) document
{
  ASSIGN (domDocumentValue, document);
}

- (void) setBody: (NSString *) body
{
  ASSIGN (bodyValue, body);
}

- (NSString *) davBodyAsString
{
  return bodyValue;
}

- (NSString *) method
{
  return methodValue;
}

- (NSString *) headerForKey: (NSString *) key
{
  return [headersValue objectForKey: key];
}

- (NSString *) uri
{
  return uriValue;
}

- (NSDictionary *) formValues
{
  return formValuesValue;
}

- (BOOL) isSoWebDAVRequest
{
  return webDAVValue;
}

- (BOOL) isICal4
{
  return iCal4Value;
}

- (BOOL) handledByDefaultHandler
{
  return defaultHandlerValue;
}

- (NSString *) applicationName
{
  return appNameValue;
}

- (NSString *) contentAsString
{
  return @"BEGIN:VCARD\r\nEND:VCARD\r\n";
}

- (id) contentAsDOMDocument
{
  return domDocumentValue;
}

- (NSString *) requestHandlerKey
{
  return @"dav";
}

- (BOOL) isThunderbird
{
  return NO;
}

@end

@interface StubServerCoreUserDefaults : NSObject
@end

@implementation StubServerCoreUserDefaults

- (NSString *) language
{
  return @"English";
}

@end

@interface StubServerCoreDomainDefaults : NSObject
{
  BOOL sendACLEmailValue;
  BOOL foldersSendEmailValue;
  NSString *subscriptionFormatValue;
}
- (void) setSendACLEmail: (BOOL) flag;
- (void) setFoldersSendEmail: (BOOL) flag;
- (void) setSubscriptionFormat: (NSString *) format;
@end

@implementation StubServerCoreDomainDefaults

- (void) dealloc
{
  [subscriptionFormatValue release];
  [super dealloc];
}

- (void) setSendACLEmail: (BOOL) flag
{
  sendACLEmailValue = flag;
}

- (void) setFoldersSendEmail: (BOOL) flag
{
  foldersSendEmailValue = flag;
}

- (void) setSubscriptionFormat: (NSString *) format
{
  ASSIGN (subscriptionFormatValue, format);
}

- (BOOL) aclSendEMailNotifications
{
  return sendACLEmailValue;
}

- (BOOL) foldersSendEMailNotifications
{
  return foldersSendEmailValue;
}

- (NSString *) subscriptionFolderFormat
{
  return subscriptionFormatValue;
}

- (NSArray *) calendarDefaultRoles
{
  return nil;
}

- (NSArray *) contactsDefaultRoles
{
  return nil;
}

@end

@interface StubServerCoreUserSettings : SOGoUserSettings
{
  NSMutableDictionary *values;
}
@end

@implementation StubServerCoreUserSettings

- (id) init
{
  if ((self = [super init]))
    values = [[NSMutableDictionary alloc] init];

  return self;
}

- (void) dealloc
{
  [values release];
  [super dealloc];
}

- (id) objectForKey: (NSString *) key
{
  return [values objectForKey: key];
}

- (void) setObject: (id) object
	    forKey: (NSString *) key
{
  [values setObject: object forKey: key];
}

- (BOOL) synchronize
{
  return YES;
}

@end

@interface StubServerCoreUser : SOGoUser
{
  BOOL superUserValue;
  NSArray *rolesValue;
  StubServerCoreDomainDefaults *domainDefaultsValue;
  StubServerCoreUserSettings *settingsValue;
  NSString *cnValue;
  NSArray *allEmailsValue;
}
+ (StubServerCoreUser *) userWithLogin: (NSString *) login;
- (void) setSuperUser: (BOOL) flag;
- (void) setRolesForObject: (NSArray *) roles;
- (void) setCn: (NSString *) cn;
- (void) setAllEmails: (NSArray *) emails;
- (StubServerCoreUserSettings *) settings;
@end

@implementation StubServerCoreUser

+ (StubServerCoreUser *) userWithLogin: (NSString *) login
{
  StubServerCoreUser *user;

  user = [[StubServerCoreUser alloc] initWithLogin: login
					     roles: nil
					     trust: YES];
  [user autorelease];
  user->domainDefaultsValue = [StubServerCoreDomainDefaults new];
  user->settingsValue = [StubServerCoreUserSettings new];

  return user;
}

- (void) dealloc
{
  [rolesValue release];
  [domainDefaultsValue release];
  [settingsValue release];
  [cnValue release];
  [allEmailsValue release];
  [super dealloc];
}

- (void) setSuperUser: (BOOL) flag
{
  superUserValue = flag;
}

- (void) setRolesForObject: (NSArray *) roles
{
  ASSIGN (rolesValue, roles);
}

- (void) setCn: (NSString *) cn
{
  ASSIGN (cnValue, cn);
}

- (void) setAllEmails: (NSArray *) emails
{
  ASSIGN (allEmailsValue, emails);
}

- (StubServerCoreUserSettings *) settings
{
  return settingsValue;
}

- (StubServerCoreDomainDefaults *) domainDefaults
{
  return domainDefaultsValue;
}

- (StubServerCoreUserSettings *) userSettings
{
  return settingsValue;
}

- (SOGoUserDefaults *) userDefaults
{
  return (SOGoUserDefaults *) [[StubServerCoreUserDefaults new] autorelease];
}

- (BOOL) isSuperUser
{
  return superUserValue;
}

- (BOOL) canAuthenticate
{
  return NO;
}

- (NSString *) domain
{
  return @"example.com";
}

- (NSString *) cn
{
  return cnValue;
}

- (NSArray *) allEmails
{
  return allEmailsValue;
}

- (NSArray *) rolesForObject: (NSObject *) object
		  inContext: (WOContext *) context
{
  return rolesValue;
}

@end

@interface StubServerCoreContext : NSObject
{
  StubServerCoreUser *userValue;
  StubServerCoreRequest *requestValue;
  WOResponse *responseValue;
  NSURL *serverURLValue;
  NSString *rootURLValue;
}
+ (StubServerCoreContext *) contextWithUser: (StubServerCoreUser *) user
				    request: (StubServerCoreRequest *) request;
- (void) setServerURL: (NSURL *) url;
- (void) setRootURL: (NSString *) url;
@end

@implementation StubServerCoreContext

+ (StubServerCoreContext *) contextWithUser: (StubServerCoreUser *) user
				    request: (StubServerCoreRequest *) request
{
  StubServerCoreContext *context;

  context = [[StubServerCoreContext new] autorelease];
  context->userValue = [user retain];
  context->requestValue = [request retain];
  context->responseValue = [WOResponse new];
  context->serverURLValue = [[NSURL URLWithString: @"http://sogo.example"] retain];
  context->rootURLValue = [@"/SOGo" retain];

  return context;
}

- (void) dealloc
{
  [userValue release];
  [requestValue release];
  [responseValue release];
  [serverURLValue release];
  [rootURLValue release];
  [super dealloc];
}

- (void) setServerURL: (NSURL *) url
{
  ASSIGN (serverURLValue, url);
}

- (void) setRequest: (StubServerCoreRequest *) request
{
  ASSIGN (requestValue, request);
}

- (void) setRootURL: (NSString *) url
{
  ASSIGN (rootURLValue, url);
}

- (SOGoUser *) activeUser
{
  return userValue;
}

- (StubServerCoreRequest *) request
{
  return requestValue;
}

- (WOResponse *) response
{
  return responseValue;
}

- (NSURL *) serverURL
{
  return serverURLValue;
}

- (NSString *) rootURL
{
  return rootURLValue;
}

@end

@interface StubServerCoreContainer : NSObject
{
  NSString *nameValue;
  NSString *ownerValue;
  BOOL publicZoneValue;
  NSString *davURLValue;
  NSArray *aclRolesValue;
  NSString *defaultFolderNameValue;
  NSMutableArray *setRolesCalls;
  NSMutableArray *removeUsersCalls;
  NSMutableArray *removedChildNames;
  StubServerCoreContainer *parentValue;
  id userFolderValue;
}
+ (StubServerCoreContainer *) rootContainer;
+ (StubServerCoreContainer *) containerWithName: (NSString *) name
					  owner: (NSString *) owner;
- (void) setPublicZone: (BOOL) flag;
- (void) setDavURL: (NSString *) url;
- (void) setAclRoles: (NSArray *) roles;
- (void) setDefaultFolderName: (NSString *) name;
- (NSArray *) setRolesCalls;
- (NSArray *) removeUsersCalls;
- (NSArray *) removedChildNames;
@end

@implementation StubServerCoreContainer

+ (StubServerCoreContainer *) rootContainer
{
  StubServerCoreContainer *container;

  container = [[StubServerCoreContainer new] autorelease];
  container->setRolesCalls = [NSMutableArray new];
  container->removeUsersCalls = [NSMutableArray new];
  container->removedChildNames = [NSMutableArray new];

  return container;
}

+ (StubServerCoreContainer *) containerWithName: (NSString *) name
					  owner: (NSString *) owner
{
  StubServerCoreContainer *container;

  container = [[StubServerCoreContainer new] autorelease];
  container->nameValue = [name retain];
  container->ownerValue = [owner retain];
  container->davURLValue = [@"/SOGo/dav/bob/Calendar/" retain];
  container->setRolesCalls = [NSMutableArray new];
  container->removeUsersCalls = [NSMutableArray new];
  container->removedChildNames = [NSMutableArray new];
  container->parentValue = [[self rootContainer] retain];

  return container;
}

- (void) dealloc
{
  [nameValue release];
  [ownerValue release];
  [davURLValue release];
  [aclRolesValue release];
  [defaultFolderNameValue release];
  [setRolesCalls release];
  [removeUsersCalls release];
  [removedChildNames release];
  [parentValue release];
  [userFolderValue release];
  [super dealloc];
}

- (void) setPublicZone: (BOOL) flag
{
  publicZoneValue = flag;
}

- (void) setDavURL: (NSString *) url
{
  ASSIGN (davURLValue, url);
}

- (void) setAclRoles: (NSArray *) roles
{
  ASSIGN (aclRolesValue, roles);
}

- (void) setDefaultFolderName: (NSString *) name
{
  ASSIGN (defaultFolderNameValue, name);
}

- (void) setUserFolder: (id) folder
{
  ASSIGN (userFolderValue, folder);
}

- (NSArray *) setRolesCalls
{
  return setRolesCalls;
}

- (NSArray *) removeUsersCalls
{
  return removeUsersCalls;
}

- (NSArray *) removedChildNames
{
  return removedChildNames;
}

- (NSString *) nameInContainer
{
  return nameValue;
}

- (id) container
{
  return parentValue;
}

- (NSString *) ownerInContext: (id) ctx
{
  return ownerValue;
}

- (BOOL) isInPublicZone
{
  return publicZoneValue;
}

- (NSString *) davURLAsString
{
  return davURLValue;
}

- (NSArray *) subscriptionRoles
{
  return [NSArray arrayWithObject: @"ObjectViewer"];
}

- (id) lookupUserFolder
{
  return userFolderValue;
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  return aclRolesValue;
}

- (void) setRoles: (NSArray *) roles
	   forUser: (NSString *) uid
   forObjectAtPath: (NSArray *) path
{
  [setRolesCalls addObject: [NSDictionary dictionaryWithObjectsAndKeys:
				     roles, @"roles",
				     uid, @"uid",
				     path, @"path",
				     nil]];
}

- (void) removeAclsForUsers: (NSArray *) users
	      forObjectAtPath: (NSArray *) path
{
  [removeUsersCalls addObject: users];
}

- (NSArray *) aclUsersForObjectAtPath: (NSArray *) path
{
  return [NSArray arrayWithObject: @"alice"];
}

- (NSArray *) pathArrayToFolder
{
  return [NSArray arrayWithObjects: @"bob", @"Calendar", nil];
}

- (NSArray *) pathArrayToSoObject
{
  return [NSArray arrayWithObject: nameValue];
}

- (GCSFolder *) ocsFolder
{
  return nil;
}

- (void) removeChildRecordWithName: (NSString *) name
{
  [removedChildNames addObject: name];
}

- (NSString *) defaultFolderName
{
  return defaultFolderNameValue;
}

@end

@interface StubServerCoreObject : SOGoObject
{
  BOOL folderishValue;
  NSString *contentValue;
  NSString *etagValue;
  NSArray *aclUsersValue;
  NSArray *aclsValue;
  NSString *defaultUIDValue;
  NSString *davDisplayNameValue;
}
- (void) setFolderish: (BOOL) flag;
- (void) setContent: (NSString *) content;
- (void) setEtag: (NSString *) etag;
- (void) setAclUsers: (NSArray *) users;
- (void) setAcls: (NSArray *) acls;
- (void) setDefaultUID: (NSString *) uid;
@end

@implementation StubServerCoreObject

- (void) dealloc
{
  [contentValue release];
  [etagValue release];
  [aclUsersValue release];
  [aclsValue release];
  [defaultUIDValue release];
  [davDisplayNameValue release];
  [super dealloc];
}

- (void) setFolderish: (BOOL) flag
{
  folderishValue = flag;
}

- (void) setContent: (NSString *) content
{
  ASSIGN (contentValue, content);
}

- (void) setEtag: (NSString *) etag
{
  ASSIGN (etagValue, etag);
}

- (void) setAclUsers: (NSArray *) users
{
  ASSIGN (aclUsersValue, users);
}

- (void) setAcls: (NSArray *) acls
{
  ASSIGN (aclsValue, acls);
}

- (void) setDefaultUID: (NSString *) uid
{
  ASSIGN (defaultUIDValue, uid);
}

- (BOOL) isFolderish
{
  return folderishValue;
}

- (NSString *) contentAsString
{
  return contentValue;
}

- (NSString *) davEntityTag
{
  return etagValue;
}

- (NSArray *) aclUsers
{
  return aclUsersValue;
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  return aclsValue;
}

- (void) setRoles: (NSArray *) roles
	   forUser: (NSString *) uid
{
  [[self container] setRoles: roles
		       forUser: uid
	       forObjectAtPath: [NSArray arrayWithObject: [self nameInContainer]]];
}

- (void) removeAclsForUsers: (NSArray *) users
{
  [[self container] removeAclsForUsers: users
			forObjectAtPath: [NSArray arrayWithObject: [self nameInContainer]]];
}

- (NSString *) defaultUserID
{
  return defaultUIDValue;
}

- (NSException *) setDavDisplayName: (NSString *) newName
{
  ASSIGN (davDisplayNameValue, newName);

  return nil;
}

- (NSException *) setDavWhatever: (NSString *) newValue
{
  return nil;
}

- (id) davCustomThing: (id) ctx
{
  return @"custom-marker";
}

- (NSException *) delete
{
  return nil;
}

@end

@interface StubServerCoreBareContainer : NSObject
@end

@implementation StubServerCoreBareContainer

- (NSString *) nameInContainer
{
  return @"Calendar";
}

- (NSString *) ownerInContext: (id) ctx
{
  return @"bob";
}

@end

@interface StubServerCoreKeysFolder : SOGoFolder
@end

@implementation StubServerCoreKeysFolder

- (NSString *) folderType
{
  return @"Appointment";
}

- (NSArray *) toManyRelationshipKeys
{
  return [NSArray arrayWithObjects: @"subOne", @"subTwo", nil];
}

@end

@interface StubServerCoreFolder : SOGoFolder
@end

@implementation StubServerCoreFolder

- (NSString *) folderType
{
  return @"Appointment";
}

@end

@interface StubServerCoreGroupDavFolder : SOGoFolder
@end

@implementation StubServerCoreGroupDavFolder

- (NSString *) folderType
{
  return @"Appointment";
}

- (NSString *) groupDavResourceType
{
  return @"vevent-collection";
}

@end

@interface StubServerCoreVersitComponent : NSObject
@end

@implementation StubServerCoreVersitComponent

- (NSString *) versitString
{
  return @"BEGIN:VCARD\r\nEND:VCARD\r\n";
}

@end

@interface StubServerCoreParsingClass : NSObject
@end

@implementation StubServerCoreParsingClass

+ (id) parseSingleFromSource: (NSString *) source
{
  return [[[StubServerCoreVersitComponent alloc] init] autorelease];
}

@end

@interface StubServerCoreContentObject : SOGoContentObject
{
  NSString *movedToValue;
}
- (NSString *) movedTo;
@end

@implementation StubServerCoreContentObject

- (void) dealloc
{
  [movedToValue release];
  [super dealloc];
}

- (Class *) parsingClass
{
  return (Class *) [StubServerCoreParsingClass class];
}

- (NSException *) moveToFolder: (SOGoGCSFolder *) newFolder
{
  ASSIGN (movedToValue, [newFolder nameInContainer]);

  return nil;
}

- (NSException *) copyToFolder: (SOGoGCSFolder *) newFolder
{
  return nil;
}

- (NSString *) movedTo
{
  return movedToValue;
}

@end

@interface StubServerCoreGCSFolder : SOGoGCSFolder
{
  NSArray *aclRolesValue;
}
- (void) setAclRoles: (NSArray *) roles;
@end

@implementation StubServerCoreGCSFolder

- (void) dealloc
{
  [aclRolesValue release];
  [super dealloc];
}

- (void) setAclRoles: (NSArray *) roles
{
  ASSIGN (aclRolesValue, roles);
}

- (NSString *) folderType
{
  return @"Appointment";
}

- (NSString *) _nodeTagForProperty: (NSString *) property
{
  return @"getetag";
}

- (Class) objectClassForComponentName: (NSString *) componentName
{
  return [StubServerCoreContentObject class];
}

- (Class) objectClassForContent: (NSString *) content
{
  return [StubServerCoreContentObject class];
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  return aclRolesValue;
}

@end

@interface StubServerCoreDOMElement : NSObject <DOMNode>
{
  NSString *localNameValue;
  StubServerCoreDOMElement *nextValue;
  StubServerCoreDOMElement *childValue;
}
+ (StubServerCoreDOMElement *) elementWithLocalName: (NSString *) name
					nextSibling: (StubServerCoreDOMElement *) sibling;
- (void) setChild: (StubServerCoreDOMElement *) child;
@end

@implementation StubServerCoreDOMElement

+ (StubServerCoreDOMElement *) elementWithLocalName: (NSString *) name
					nextSibling: (StubServerCoreDOMElement *) sibling
{
  StubServerCoreDOMElement *element;

  element = [[StubServerCoreDOMElement new] autorelease];
  element->localNameValue = [name retain];
  element->nextValue = [sibling retain];

  return element;
}

- (void) dealloc
{
  [localNameValue release];
  [nextValue release];
  [childValue release];
  [super dealloc];
}

- (void) setChild: (StubServerCoreDOMElement *) child
{
  ASSIGN (childValue, child);
}

- (DOMNodeType) nodeType
{
  return DOM_ELEMENT_NODE;
}

- (NSString *) nodeName
{
  return localNameValue;
}

- (NSString *) nodeValue
{
  return nil;
}

- (NSString *) localName
{
  return localNameValue;
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
  return nextValue;
}

- (id<NSObject, DOMNodeList>) childNodes
{
  return nil;
}

- (BOOL) hasChildNodes
{
  return (childValue != nil);
}

- (id<NSObject, DOMNode>) firstChild
{
  return childValue;
}

- (id<NSObject, DOMNode>) lastChild
{
  return childValue;
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

@interface StubServerCoreRetainingObject : SOGoObject
@end

@implementation StubServerCoreRetainingObject

- (BOOL) doesRetainContainer
{
  return YES;
}

@end

@interface StubServerCoreFailingContentObject : StubServerCoreContentObject
@end

@implementation StubServerCoreFailingContentObject

- (NSException *) saveComponent: (id) theComponent
                     baseVersion: (unsigned int) newVersion
{
  return [NSException exceptionWithName: @"SaveFailed"
				 reason: @"save refused"
			       userInfo: nil];
}

@end

@interface TestServerCore : SOGoTest
@end

@implementation TestServerCore

+ (void) initialize
{
  NSDictionary *defaults;
  NSUserDefaults *ud;

  if (self == [TestServerCore class])
    {
      defaults = [NSDictionary dictionaryWithObjectsAndKeys:
			     @"127.0.0.1:11211",
			   @"SOGoMemcachedHost",
			   nil];
      ud = [NSUserDefaults standardUserDefaults];
      [ud setVolatileDomain: defaults
		     forName: @"sogo-tests-server-core"];
      [ud addSuiteNamed: @"sogo-tests-server-core"];
    }
}

- (StubServerCoreContext *) contextWithLogin: (NSString *) login
				      method: (NSString *) method
{
  StubServerCoreUser *user;
  StubServerCoreRequest *request;

  user = [StubServerCoreUser userWithLogin: login];
  request = [StubServerCoreRequest requestWithMethod: method];

  return [StubServerCoreContext contextWithUser: user
					request: request];
}

- (void) test_globallyUniqueObjectId
{
  NSString *first;
  NSString *second;
  NSArray *components;
  unsigned int hexValue;

  first = [SOGoObject globallyUniqueObjectId];
  second = [SOGoObject globallyUniqueObjectId];
  failIf(first == nil);
  failIf(second == nil);
  failIf([first isEqualToString: second]);
  components = [first componentsSeparatedByString: @"-"];
  failIf([components count] != 4);
  [[NSScanner scannerWithString: [components objectAtIndex: 0]] scanHexInt: &hexValue];
  failIf(hexValue == 0);
  [[NSScanner scannerWithString: [components objectAtIndex: 1]] scanHexInt: &hexValue];
  failIf(hexValue == 0);
}

- (void) test_instanceUniqueObjectIds
{
  StubServerCoreContainer *container;
  SOGoObject *object;
  NSString *objectId;
  NSString *messageId;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  objectId = [object globallyUniqueObjectId];
  messageId = [object mailUniqueMessageId];
  failIf(![objectId isKindOfClass: [NSString class]]);
  failIf([messageId length] != 36);
  failIf([[messageId componentsSeparatedByString: @"-"] count] != 5);
  failIf([[SOGoObject mailUniqueMessageId] isEqualToString: messageId]);
}

- (void) test_objectWithNameInContainer
{
  StubServerCoreContainer *container;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  testEquals([object nameInContainer], @"personal");
  testEquals([object container], container);
  testEquals([object displayName], @"personal");
  failIf([object doesRetainContainer]);
  testEquals([object owner], @"bob");
}

- (void) test_initWithNameEmptyRaises
{
  StubServerCoreContainer *container;
  BOOL raised;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  raised = NO;
  NS_DURING
    {
      [SOGoObject objectWithName: @"" inContainer: container];
    }
  NS_HANDLER
    {
      raised = YES;
      testEquals([localException name], NSInvalidArgumentException);
    }
  NS_ENDHANDLER;
  failIf(!raised);
}

- (void) test_contextAccessors
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  failIf([object context] != nil);
  [object setContext: (WOContext *) context];
  testEquals([object context], context);
}

- (void) test_setNameInContainer
{
  StubServerCoreContainer *container;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  [object setNameInContainer: @"changed"];
  testEquals([object nameInContainer], @"changed");
}

- (void) test_soURL
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  object = [StubServerCoreObject objectWithName: @"personal"
				  inContainer: container];
  [object setContext: (WOContext *) context];
  testEquals([[object soURL] absoluteString],
	     @"http://sogo.example/SOGo/so/Calendar/personal");
}

- (void) test_davURL
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  object = [StubServerCoreObject objectWithName: @"personal"
				  inContainer: container];
  [object setContext: (WOContext *) context];
  testEquals([[object davURL] absoluteString],
	     @"http://sogo.example/SOGo/dav/Calendar/personal");
}

- (void) test_davURLWithPort
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  [context setServerURL: [NSURL URLWithString: @"https://sogo.example:8443"]];
  object = [StubServerCoreObject objectWithName: @"personal"
				  inContainer: container];
  [object setContext: (WOContext *) context];
  testEquals([[object davURL] absoluteString],
	     @"https://sogo.example:8443/SOGo/dav/Calendar/personal");
}

- (void) test_davURLWithHTTPRootURL
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  [context setRootURL: @"http://other.example/SOGo"];
  object = [StubServerCoreObject objectWithName: @"personal"
				  inContainer: container];
  [object setContext: (WOContext *) context];
  testEquals([[object davURL] absoluteString],
	     @"http://sogo.example/SOGo/dav/Calendar/personal");
}

- (void) test_soURLToBaseContainerForUser
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  object = [StubServerCoreObject objectWithName: @"personal"
				  inContainer: container];
  [object setContext: (WOContext *) context];
  testEquals([[object soURLToBaseContainerForUser: @"alice"] absoluteString],
	     @"http://sogo.example/SOGo/so/alice/personal");
  testEquals([[object soURLToBaseContainerForCurrentUser] absoluteString],
	     @"http://sogo.example/SOGo/so/bob/personal");
}

- (void) test_relativeSoURLToBaseContainerForCurrentUser
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  [context setServerURL: [NSURL URLWithString: @"http://attacker.invalid"]];
  object = [StubServerCoreObject objectWithName: @"personal"
				  inContainer: container];
  [object setContext: (WOContext *) context];
  testEquals([[object relativeSoURLToBaseContainerForCurrentUser]
	      absoluteString],
	     @"/SOGo/so/bob/personal");
}

- (void) test_relativeSoURLToModule
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  object = [StubServerCoreObject objectWithName: @"personal"
				  inContainer: container];
  [object setContext: (WOContext *) context];
  testEquals([[object relativeSoURLToModule: @"Mail"] absoluteString],
	     @"/SOGo/so/Calendar/personal/Mail");
}

- (void) test_relativeSoURLToModuleWithPoisonedHostHeader
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  [context setServerURL: [NSURL URLWithString: @"http://attacker.invalid"]];
  object = [StubServerCoreObject objectWithName: @"personal"
				  inContainer: container];
  [object setContext: (WOContext *) context];
  testEquals([[object soURL] absoluteString],
	     @"http://attacker.invalid/SOGo/so/Calendar/personal");
  testEquals([[object relativeSoURLToModule: @"Mail"] absoluteString],
	     @"/SOGo/so/Calendar/personal/Mail");
}

- (void) test_davURLAsString
{
  StubServerCoreContainer *container;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  testEquals([object davURLAsString],
	     @"/SOGo/dav/bob/Calendar/personal");
}

- (void) test_lookupNameUnknown
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  failIf([object lookupName: @"unknown"
		  inContext: (WOContext *) context
		      acquire: NO] != nil);
}

- (void) test_lookupNameCached
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  SOGoObject *object;
  NSString *marker;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  marker = @"cached-marker";
  [[SOGoCache sharedCache] registerObject: marker
				   withName: @"cached"
			       inContainer: object];
  testEquals([object lookupName: @"cached"
		      inContext: (WOContext *) context
			  acquire: NO],
	     marker);
  [[SOGoCache sharedCache] unregisterObjectWithName: @"cached"
					  inContainer: object];
}

- (void) test_lookupNameReport
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"REPORT"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  failIf([object lookupName: @"unknown-report"
		  inContext: (WOContext *) context
		      acquire: NO] != nil);
}

- (void) test_lookupObjectAtDAVUrl
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  request = [StubServerCoreRequest requestWithMethod: @"GET"];
  [request setApplicationName: @"SOGo"];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  [object setContext: (WOContext *) context];
  failIf([object lookupObjectAtDAVUrl: @"/SOGo/dav/bob/Calendar/personal"] != nil);
}

- (void) test_exceptionWithHTTPStatus
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  SOGoObject *object;
  NSException *exception;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"GET"];
  [request setHandledByDefaultHandler: YES];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  [object setContext: (WOContext *) context];
  exception = [object exceptionWithHTTPStatus: 404];
  failIf([exception httpStatus] != 404);
  exception = [object exceptionWithHTTPStatus: 501
					reason: @"not me"];
  failIf([exception httpStatus] != 501);
  testEquals([exception reason], @"not me");
}

- (void) test_exceptionWithDAVStatus
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  SOGoObject *object;
  NSException *exception;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"GET"];
  [request setHandledByDefaultHandler: NO];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  [object setContext: (WOContext *) context];
  exception = [object exceptionWithHTTPStatus: 412];
  failIf([exception httpStatus] != 412);
  exception = [object exceptionWithHTTPStatus: 412
					reason: @"precondition"];
  failIf([exception httpStatus] != 412);
  testEquals([exception reason], @"precondition");
}

- (void) test_GCSFolderManagerSafety
{
  StubServerCoreContainer *container;
  SOGoGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [SOGoGCSFolder objectWithName: @"personal"
			    inContainer: container];
  failIf([folder ocsPath] != nil);
  failIf([folder ocsFolder] != nil);
  failIf([folder folderIsMandatory] != YES);
}

- (void) test_userWithLoginFromCache
{
  SOGoUser *user;
  SOGoUser *again;

  user = [[StubServerCoreUser alloc] initWithLogin: @"cacheuser"
					      roles: nil
					      trust: YES];
  [[SOGoCache sharedCache] registerUser: user
				withName: @"cacheuser"];
  again = [SOGoUser userWithLogin: @"cacheuser"];
  testEquals(again, user);
  [[SOGoCache sharedCache] killCache];
  [user release];
}

- (void) test_ownerAndIgnoreRights
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  testEquals([object owner], @"bob");
  context = [self contextWithLogin: @"bob" method: @"GET"];
  [object setContext: (WOContext *) context];
  failIf(![object ignoreRights]);
  context = [self contextWithLogin: @"carol" method: @"GET"];
  [object setContext: (WOContext *) context];
  failIf([object ignoreRights]);
}

- (void) test_ignoreRightsForSuperUser
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreUser *user;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  user = [StubServerCoreUser userWithLogin: @"carol"];
  [user setSuperUser: YES];
  context = [StubServerCoreContext contextWithUser: user
					   request: [StubServerCoreRequest requestWithMethod: @"GET"]];
  [object setContext: (WOContext *) context];
  failIf(![object ignoreRights]);
}

- (void) test_isInPublicZone
{
  StubServerCoreContainer *container;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  [container setPublicZone: YES];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  failIf(![object isInPublicZone]);
}

- (void) test_lookupUserFolder
{
  StubServerCoreContainer *container;
  SOGoObject *object;
  SOGoObject *bare;
  NSString *marker;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  marker = @"user-folder";
  [container setUserFolder: marker];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  testEquals([object lookupUserFolder], marker);
  bare = [SOGoObject objectWithName: @"personal"
			 inContainer: [StubServerCoreBareContainer new]];
  failIf([bare lookupUserFolder] != nil);
}

- (void) test_fetchSubfoldersWithoutKeys
{
  StubServerCoreContainer *container;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  failIf([object fetchSubfolders] != nil);
}

- (void) test_fetchSubfoldersSkippingUnknown
{
  StubServerCoreContainer *container;
  StubServerCoreKeysFolder *folder;
  NSArray *subfolders;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreKeysFolder objectWithName: @"personal"
				      inContainer: container];
  [[SOGoCache sharedCache] registerObject: [NSException exceptionWithName: @"test"
									reason: @"skip"
								      userInfo: nil]
				   withName: @"subOne"
			       inContainer: folder];
  subfolders = [folder fetchSubfolders];
  failIf([subfolders count] != 0);
  [[SOGoCache sharedCache] unregisterObjectWithName: @"subOne"
					  inContainer: folder];
}

- (void) test_sleep
{
  StubServerCoreContainer *container;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  [object sleep];
  failIf([object container] != nil);
}

- (void) test_delete
{
  StubServerCoreContainer *container;
  SOGoObject *object;
  NSException *exception;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  exception = [object delete];
  failIf(exception == nil);
  failIf([exception httpStatus] != 501);
}

- (void) test_DELETEAction
{
  StubServerCoreContainer *container;
  SOGoObject *object;
  NSException *result;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  result = [object DELETEAction: nil];
  failIf(result == nil);
  failIf(![result isKindOfClass: [NSException class]]);
}

- (void) test_valueForUndefinedKey
{
  StubServerCoreContainer *container;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  failIf([object valueForUndefinedKey: @"missing"] != nil);
}

- (void) test_davHelpers
{
  StubServerCoreContainer *container;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  testEquals([object davDisplayName], @"personal");
  testEquals([object davContentType], @"text/plain");
  failIf([object davLastModified] == nil);
  failIf([object davIsCollection]);
}

- (void) test_parseETagList
{
  StubServerCoreContainer *container;
  SOGoObject *object;
  NSArray *etags;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  failIf([object parseETagList: @""] != nil);
  failIf([object parseETagList: @"*"] != nil);
  etags = [object parseETagList: @"\"a\", \"b\""];
  failIf([etags count] != 2);
  testEquals([etags objectAtIndex: 0], @"\"a\"");
  testEquals([etags objectAtIndex: 1], @"\"b\"");
}

- (void) test_checkIfMatchCondition
{
  StubServerCoreContainer *container;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setEtag: @"\"v1\""];
  failIf([object checkIfMatchCondition: @"*" inContext: nil] != nil);
  failIf([object checkIfMatchCondition: @"" inContext: nil] != nil);
  failIf([object checkIfMatchCondition: @"\"v1\"" inContext: nil] != nil);
  failIf([object checkIfMatchCondition: @"\"v1\", \"v2\"" inContext: nil] != nil);
  failIf([object checkIfMatchCondition: @"\"other\"" inContext: nil] == nil);
  [object setEtag: @""];
  failIf([object checkIfMatchCondition: @"\"other\"" inContext: nil] != nil);
}

- (void) test_checkIfNoneMatchCondition
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;
  NSException *exception;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setEtag: @"\"v1\""];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  exception = [object checkIfNoneMatchCondition: @"\"v1\""
					inContext: (WOContext *) context];
  failIf(exception == nil);
  failIf([exception httpStatus] != 304);
  failIf([object checkIfNoneMatchCondition: @"\"other\""
					inContext: (WOContext *) context] != nil);
  failIf([object checkIfNoneMatchCondition: @"*"
					inContext: (WOContext *) context] != nil);
  context = [self contextWithLogin: @"bob" method: @"PUT"];
  failIf([object checkIfNoneMatchCondition: @"\"v1\""
					inContext: (WOContext *) context] != nil);
}

- (void) test_matchesRequestConditionInContext
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setEtag: @"\"v1\""];
  context = [StubServerCoreContext contextWithUser: nil
					   request: nil];
  failIf([object matchesRequestConditionInContext: (WOContext *) context] != nil);
  request = [StubServerCoreRequest requestWithMethod: @"GET"
						  headers: [NSDictionary dictionaryWithObjectsAndKeys:
							      @"\"v1\"", @"if-none-match",
							      nil]];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  failIf([object matchesRequestConditionInContext: (WOContext *) context] == nil);
  request = [StubServerCoreRequest requestWithMethod: @"GET"
						  headers: [NSDictionary dictionaryWithObjectsAndKeys:
							      @"\"other\"", @"if-match",
							      nil]];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  failIf([object matchesRequestConditionInContext: (WOContext *) context] == nil);
  failIf([[object matchesRequestConditionInContext: (WOContext *) context] httpStatus] != 412);
}

- (void) test_davBooleans
{
  StubServerCoreContainer *container;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  testEquals([object davBooleanForResult: YES], @"true");
  testEquals([object davBooleanForResult: NO], @"false");
  failIf(![object isValidDAVBoolean: @"true"]);
  failIf(![object isValidDAVBoolean: @"false"]);
  failIf(![object isValidDAVBoolean: @"1"]);
  failIf(![object isValidDAVBoolean: @"0"]);
  failIf([object isValidDAVBoolean: @"maybe"]);
  failIf(![object resultForDAVBoolean: @"true"]);
  failIf(![object resultForDAVBoolean: @"1"]);
  failIf([object resultForDAVBoolean: @"false"]);
  failIf([object resultForDAVBoolean: @"0"]);
}

- (void) test_labelForKey
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  object = [StubServerCoreObject objectWithName: @"personal"
				   inContainer: container];
  [object setContext: (WOContext *) context];
  testEquals([object labelForKey: @"greeting"], @"HelloLabel");
  testEquals([object labelForKey: @"absent"], @"absent");
}

- (void) test_GETActionRedirect
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreObject *object;
  WOResponse *response;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"GET"];
  [request setUri: @"/SOGo/so/bob/Calendar/personal"];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setContent: @"hello"];
  response = [object GETAction: (WOContext *) context];
  failIf(response == nil);
  failIf([response status] != 302);
  testEquals([response headerForKey: @"location"],
	     @"/SOGo/so/bob/Calendar/personal/view");
}

- (void) test_GETActionWebDAV
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreObject *object;
  WOResponse *response;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"GET"];
  [request setWebDAV: YES];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setContent: @"hello"];
  [object setEtag: @"\"v1\""];
  response = [object GETAction: (WOContext *) context];
  failIf(response == nil);
  failIf([response status] != 200);
  testEquals([response headerForKey: @"content-type"],
	     @"text/plain; charset=utf-8");
  testEquals([response headerForKey: @"etag"], @"\"v1\"");
}

- (void) test_POSTAction
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  request = [StubServerCoreRequest requestWithMethod: @"POST"];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  failIf([object POSTAction: (WOContext *) context] != nil);
  request = [StubServerCoreRequest requestWithMethod: @"POST"
					      headers: [NSDictionary dictionaryWithObjectsAndKeys:
							  @"text/plain", @"content-type",
							  nil]];
  [request setWebDAV: YES];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  failIf([object POSTAction: (WOContext *) context] != nil);
  request = [StubServerCoreRequest requestWithMethod: @"POST"
					      headers: [NSDictionary dictionaryWithObjectsAndKeys:
							  @"application/xml", @"content-type",
							  nil]];
  [request setWebDAV: YES];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  failIf([object POSTAction: (WOContext *) context] != nil);
}

- (void) test_davPOSTRequestXML
{
  StubServerCoreContainer *container;
  StubServerCoreRequest *request;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  request = [StubServerCoreRequest requestWithMethod: @"POST"];
  failIf([object davPOSTRequest: request
		 withContentType: @"application/xml"
		       inContext: nil] != nil);
  failIf([object davPOSTRequest: request
		 withContentType: @"text/plain"
		       inContext: nil] != nil);
}

- (void) test_davSetProperties
{
  StubServerCoreContainer *container;
  StubServerCoreObject *object;
  NSDictionary *properties;
  NSException *exception;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  properties = [NSDictionary dictionaryWithObject: @"My Name"
					  forKey: @"whatever"];
  failIf([object davSetProperties: properties
	      removePropertiesNamed: nil
			  inContext: nil] != nil);
  properties = [NSDictionary dictionaryWithObject: @"X"
					  forKey: @"displayname"];
  exception = [object davSetProperties: properties
		  removePropertiesNamed: nil
			      inContext: nil];
  failIf(exception == nil);
  failIf([exception httpStatus] != 403);
  properties = [NSDictionary dictionaryWithObject: @"X"
					  forKey: @"unmapped-property"];
  exception = [object davSetProperties: properties
		  removePropertiesNamed: nil
			      inContext: nil];
  failIf(exception == nil);
  failIf([exception httpStatus] != 403);
}

- (void) test_davCurrentUserPrincipal
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  context = [self contextWithLogin: @"anonymous" method: @"GET"];
  [object setContext: (WOContext *) context];
  failIf([object davCurrentUserPrincipal] != nil);
  context = [self contextWithLogin: @"bob" method: @"GET"];
  [object setContext: (WOContext *) context];
  failIf([object davCurrentUserPrincipal] == nil);
}

- (void) test_davValues
{
  StubServerCoreContainer *container;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  failIf([object davOwner] == nil);
  failIf([object davAclRestrictions] == nil);
  failIf([object davSupportedPrivilegeSet] == nil);
}

- (void) test_webdavAclManagers
{
  failIf([SOGoObject webdavAclManager] == nil);
  testEquals([SOGoObject webdavAclManager], [SOGoObject webdavAclManager]);
  failIf([SOGoFolder webdavAclManager] == nil);
  testEquals([SOGoFolder webdavAclManager], [SOGoFolder webdavAclManager]);
  failIf([SOGoGCSFolder webdavAclManager] == nil);
}

- (void) test_davCurrentUserPrivilegeSet
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreUser *user;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  user = [StubServerCoreUser userWithLogin: @"bob"];
  [user setRolesForObject: [NSArray array]];
  context = [StubServerCoreContext contextWithUser: user
					   request: [StubServerCoreRequest requestWithMethod: @"PROPFIND"]];
  [object setContext: (WOContext *) context];
  failIf([object davCurrentUserPrivilegeSet] == nil);
}

- (void) test_davAcl
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreUser *user;
  StubServerCoreUser *alice;
  StubServerCoreUser *owner;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  owner = [[StubServerCoreUser userWithLogin: @"bob"] retain];
  [[SOGoCache sharedCache] registerUser: owner
				withName: @"bob"];
  alice = [[StubServerCoreUser userWithLogin: @"alice"] retain];
  [alice setRolesForObject: [NSArray arrayWithObject: @"ObjectViewer"]];
  [[SOGoCache sharedCache] registerUser: alice
				withName: @"alice"];
  user = [StubServerCoreUser userWithLogin: @"carol"];
  [user setRolesForObject: [NSArray array]];
  context = [StubServerCoreContext contextWithUser: user
					   request: [StubServerCoreRequest requestWithMethod: @"PROPFIND"]];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setContext: (WOContext *) context];
  [object setAclUsers: [NSArray arrayWithObject: @"alice"]];
  [object setAcls: [NSArray array]];
  failIf([object davAcl] == nil);
  [[SOGoCache sharedCache] killCache];
  [owner release];
  [alice release];
}

- (void) test_addUserInAcls
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"PROPPATCH"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setContext: (WOContext *) context];
  [object setAcls: [NSArray array]];
  failIf([object addUserInAcls: @""]);
  failIf([object addUserInAcls: @"bob"]);
  failIf(![object addUserInAcls: @"alice"]);
  failIf([[container setRolesCalls] count] != 1);
}

- (void) test_addUserInAclsWithAdvisory
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreUser *user;
  StubServerCoreUser *alice;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  alice = [[StubServerCoreUser userWithLogin: @"alice"] retain];
  [[SOGoCache sharedCache] registerUser: alice
				withName: @"alice"];
  user = [StubServerCoreUser userWithLogin: @"bob"];
  [(StubServerCoreDomainDefaults *) [user domainDefaults] setSendACLEmail: YES];
  context = [StubServerCoreContext contextWithUser: user
					   request: [StubServerCoreRequest requestWithMethod: @"PROPPATCH"]];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setContext: (WOContext *) context];
  [object setAcls: [NSArray array]];
  failIf(![object addUserInAcls: @"alice"]);
  [[SOGoCache sharedCache] killCache];
  [alice release];
}

- (void) test_removeUserFromAcls
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"PROPPATCH"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setContext: (WOContext *) context];
  failIf([object removeUserFromAcls: @""]);
  failIf(![object removeUserFromAcls: @"alice"]);
  failIf([[container removeUsersCalls] count] != 1);
}

- (void) test_davRecordForUser
{
  StubServerCoreContainer *container;
  StubServerCoreUser *alice;
  SOGoObject *object;
  NSArray *params;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  params = [NSArray arrayWithObjects: @"nocn", @"noemail", nil];
  testEquals([object davRecordForUser: @"bob"
			    parameters: params],
	     @"<id>bob</id>");
  alice = [[StubServerCoreUser userWithLogin: @"alice"] retain];
  [alice setCn: @"Alice Wonderland"];
  [alice setAllEmails: [NSArray arrayWithObject: @"alice@example.com"]];
  [[SOGoCache sharedCache] registerUser: alice
				withName: @"alice"];
  testEquals([object davRecordForUser: @"alice"
			    parameters: nil],
	     @"<id>alice</id><displayName>Alice Wonderland</displayName><email>alice@example.com</email>");
  testEquals([object davRecordForUser: @"alice"
			    parameters: [NSArray arrayWithObject: @"nocn"]],
	     @"<id>alice</id><email>alice@example.com</email>");
  testEquals([object davRecordForUser: @"alice"
			    parameters: [NSArray arrayWithObject: @"noemail"]],
	     @"<id>alice</id><displayName>Alice Wonderland</displayName>");
  [[SOGoCache sharedCache] killCache];
  [alice release];
}

- (void) test_davAclUserListQuery
{
  StubServerCoreContainer *container;
  StubServerCoreUser *alice;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  alice = [[StubServerCoreUser userWithLogin: @"alice"] retain];
  [alice setCn: @"Alice Wonderland"];
  [alice setAllEmails: [NSArray arrayWithObject: @"alice@example.com"]];
  [[SOGoCache sharedCache] registerUser: alice
				withName: @"alice"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setDefaultUID: @"<default>"];
  [object setAclUsers: [NSArray arrayWithObjects: @"<default>", @"alice", nil]];
  testEquals([object _davAclUserListQuery: @"nocn,noemail"],
	     @"<default-user><id>&lt;default&gt;</id></default-user>"
	     @"<user><id>alice</id></user>");
  testEquals([object _davAclUserListQuery: nil],
	     @"<default-user><id>&lt;default&gt;</id></default-user>"
	     @"<user><id>alice</id><displayName>Alice Wonderland</displayName>"
	     @"<email>alice@example.com</email></user>");
  [[SOGoCache sharedCache] killCache];
  [alice release];
}

- (void) test_davAclUserRoles
{
  StubServerCoreContainer *container;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setAcls: [NSArray arrayWithObjects: @"ObjectViewer", @"ObjectEditor", nil]];
  testEquals([object _davAclUserRoles: @"alice"],
	     @"<ObjectViewer/><ObjectEditor/>");
  [object setAcls: [NSArray array]];
  testEquals([object _davAclUserRoles: @"alice"], @"");
}

- (void) test_davGetRolesFromRequest
{
  StubServerCoreContainer *container;
  SOGoObject *object;
  StubServerCoreDOMElement *parent;
  StubServerCoreDOMElement *first;
  StubServerCoreDOMElement *second;
  NSArray *roles;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  second = [StubServerCoreDOMElement elementWithLocalName: @"ObjectEditor"
					      nextSibling: nil];
  first = [StubServerCoreDOMElement elementWithLocalName: @"ObjectViewer"
					     nextSibling: second];
  parent = [StubServerCoreDOMElement elementWithLocalName: @"acl-query"
					     nextSibling: nil];
  [parent setChild: first];
  roles = [object _davGetRolesFromRequest: parent];
  failIf([roles count] != 2);
  testEquals([roles objectAtIndex: 0], @"ObjectViewer");
  testEquals([roles objectAtIndex: 1], @"ObjectEditor");
}

- (void) test_davComplianceClassesForContentObject
{
  StubServerCoreContainer *container;
  StubServerCoreObject *object;
  NSArray *classes;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  classes = [object davComplianceClassesInContext: nil];
  failIf(![classes containsObject: @"1"]);
  failIf(![classes containsObject: @"access-control"]);
  failIf([classes containsObject: @"addressbook"]);
  failIf([classes containsObject: @"calendar-access"]);
}

- (void) test_davComplianceClassesForUserFolder
{
  SOGoUserFolder *folder;
  NSArray *classes;

  folder = [SOGoUserFolder objectWithName: @"alice"
			      inContainer: nil];
  classes = [folder davComplianceClassesInContext: nil];
  failIf(![classes containsObject: @"1"]);
  failIf(![classes containsObject: @"access-control"]);
  failIf(![classes containsObject: @"addressbook"]);
  failIf(![classes containsObject: @"calendar-access"]);
  failIf(![classes containsObject: @"calendar-schedule"]);
}

- (void) test_descriptionAndLoggingPrefix
{
  StubServerCoreContainer *container;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  failIf([[object description] rangeOfString: @"name=personal"].location
	  == NSNotFound);
  failIf([[object loggingPrefix] rangeOfString: @"personal"].location
	  == NSNotFound);
}

- (void) test_contentObjectBasics
{
  StubServerCoreContainer *container;
  StubServerCoreContentObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreContentObject objectWithName: @"card.vcf"
					   andContent: @"DATA"
					      inContainer: container];
  testEquals([object contentAsString], @"DATA");
  failIf([object isNew]);
  [object setIsNew: YES];
  failIf(![object isNew]);
  [object setIsNew: NO];
  failIf([object isNew]);
  failIf([object version] != 0);
  failIf([object isFolderish]);
  testEquals([object davEntityTag], @"\"gcs00000000\"");
  testEquals([object davContentLength], @"4");
  testEquals([object displayName], @"card.vcf");
  object = [StubServerCoreContentObject objectWithName: @"card.vcf"
					   andContent: nil
					      inContainer: container];
  testEquals([object davContentLength], @"0");
}

- (void) test_contentObjectFromRecord
{
  StubServerCoreContainer *container;
  NSDictionary *record;
  SOGoContentObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  record = [NSDictionary dictionaryWithObjectsAndKeys:
			   @"card.vcf", @"c_name",
			   @"DATA", @"c_content",
			   [NSNumber numberWithInt: 5], @"c_version",
			   [NSNumber numberWithInt: 1000], @"c_creationdate",
			   [NSNumber numberWithInt: 2000], @"c_lastmodified",
			   nil];
  object = [SOGoContentObject objectWithRecord: record
				    inContainer: container];
  testEquals([object nameInContainer], @"card.vcf");
  testEquals([object contentAsString], @"DATA");
  failIf([object version] != 5);
  failIf([[object creationDate] timeIntervalSince1970] != 1000);
  failIf([[object lastModified] timeIntervalSince1970] != 2000);
  failIf([object davCreationDate] == nil);
  failIf([object davLastModified] == nil);
  testEquals([object davEntityTag], @"\"gcs00000005\"");
}

- (void) test_contentObjectFromRecordData
{
  StubServerCoreContainer *container;
  NSDictionary *record;
  SOGoContentObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  record = [NSDictionary dictionaryWithObjectsAndKeys:
			   @"a.vcf", @"c_name",
			   [NSData dataWithBytes: "hi\0" length: 3], @"c_content",
			   nil];
  object = [SOGoContentObject objectWithRecord: record
				    inContainer: container];
  testEquals([object contentAsString], @"hi");
  record = [NSDictionary dictionaryWithObjectsAndKeys:
			   @"b.vcf", @"c_name",
			   [NSData dataWithBytes: "hello" length: 5], @"c_content",
			   nil];
  object = [SOGoContentObject objectWithRecord: record
				    inContainer: container];
  testEquals([object contentAsString], @"hello");
}

- (void) test_contentObjectNilDates
{
  StubServerCoreContainer *container;
  SOGoContentObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoContentObject objectWithRecord: [NSDictionary dictionaryWithObject: @"x"
										    forKey: @"c_name"]
				    inContainer: container];
  failIf([object creationDate] != nil);
  failIf([object lastModified] != nil);
  failIf([object davCreationDate] != nil);
  failIf([object davLastModified] != nil);
}

- (void) test_contentObjectSaveComponent
{
  StubServerCoreContainer *container;
  StubServerCoreContentObject *object;
  StubServerCoreVersitComponent *component;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreContentObject objectWithName: @"card.vcf"
					   andContent: nil
					      inContainer: container];
  component = [[[StubServerCoreVersitComponent alloc] init] autorelease];
  failIf([object saveComponent: component] != nil);
  testEquals([object contentAsString], @"BEGIN:VCARD\r\nEND:VCARD\r\n");
  failIf([object creationDate] == nil);
  failIf([object lastModified] == nil);
  failIf([object version] != 0);
  failIf([[container removedChildNames] count] != 1);
  testEquals([[container removedChildNames] objectAtIndex: 0], @"card.vcf");
  failIf([object saveComponent: component] != nil);
  failIf([object version] != 0);
}

- (void) test_contentObjectDeleteWithoutFolder
{
  StubServerCoreContainer *container;
  StubServerCoreContentObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreContentObject objectWithName: @"card.vcf"
					   andContent: @"DATA"
					      inContainer: container];
  failIf([object delete] != nil);
  failIf([object touch] != nil);
}

- (void) test_contentObjectAclsForUser
{
  StubServerCoreContainer *container;
  StubServerCoreContentObject *object;
  NSArray *acls;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreContentObject objectWithName: @"card.vcf"
					   andContent: @"DATA"
					      inContainer: container];
  [object setIsNew: YES];
  [container setAclRoles: [NSArray arrayWithObject: SOGoRole_ObjectCreator]];
  acls = [object aclsForUser: @"bob"];
  failIf([acls count] != 2);
  failIf(![acls containsObject: SOGoRole_ObjectCreator]);
  failIf(![acls containsObject: SOGoRole_ObjectEditor]);
  [container setAclRoles: [NSArray arrayWithObjects: SOGoRole_ObjectViewer, SOGoRole_ObjectEditor, nil]];
  acls = [object aclsForUser: @"bob"];
  failIf([acls count] != 1);
  failIf(![acls containsObject: SOGoRole_ObjectViewer]);
  [object setIsNew: NO];
  acls = [object aclsForUser: @"bob"];
  failIf([acls count] != 2);
  [container setAclRoles: nil];
  acls = [object aclsForUser: @"bob"];
  failIf([acls count] != 0);
}

- (void) test_contentObjectAclUsers
{
  StubServerCoreContainer *container;
  StubServerCoreContentObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreContentObject objectWithName: @"card.vcf"
					   andContent: @"DATA"
					      inContainer: container];
  testEquals([object aclUsers], [NSArray arrayWithObject: @"alice"]);
}

- (void) test_contentObjectSetRoles
{
  StubServerCoreContainer *container;
  StubServerCoreContentObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreContentObject objectWithName: @"card.vcf"
					   andContent: @"DATA"
					      inContainer: container];
  [object setRoles: [NSArray arrayWithObject: @"ObjectViewer"]
	   forUser: @"alice"];
  failIf([[container setRolesCalls] count] != 1);
  [object removeAclsForUsers: [NSArray arrayWithObject: @"alice"]];
  failIf([[container removeUsersCalls] count] != 1);
  testEquals([object defaultUserID], @"<default>");
}

- (void) test_contentObjectPUTActionNew
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreContentObject *object;
  WOResponse *response;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"PUT"];
  [request setBody: @"BEGIN:VCARD\nVERSION:3.0\nUID:x\nFN:x\nEND:VCARD\n"];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  object = [StubServerCoreContentObject objectWithName: @"card.vcf"
					   andContent: nil
					      inContainer: container];
  [object setIsNew: YES];
  response = [object PUTAction: (WOContext *) context];
  failIf(response == nil);
  failIf([response status] != 201);
  testEquals([response headerForKey: @"etag"], @"\"gcs00000000\"");
}

- (void) test_contentObjectPUTActionExisting
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreContentObject *object;
  WOResponse *response;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"PUT"];
  [request setBody: @"BEGIN:VCARD\nVERSION:3.0\nUID:x\nFN:x\nEND:VCARD\n"];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  object = [StubServerCoreContentObject objectWithName: @"card.vcf"
					   andContent: @"DATA"
					      inContainer: container];
  response = [object PUTAction: (WOContext *) context];
  failIf(response == nil);
  failIf([response status] != 204);
}

- (void) test_contentObjectPUTActionPrecondition
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreContentObject *object;
  id response;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"PUT"
						  headers: [NSDictionary dictionaryWithObjectsAndKeys:
							      @"\"nope\"", @"if-match",
							      nil]];
  [request setBody: @"BEGIN:VCARD\nVERSION:3.0\nUID:x\nFN:x\nEND:VCARD\n"];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  object = [StubServerCoreContentObject objectWithName: @"card.vcf"
					   andContent: @"DATA"
					      inContainer: container];
  response = [object PUTAction: (WOContext *) context];
  failIf(response == nil);
  failIf(![response isKindOfClass: [NSException class]]);
  failIf([response httpStatus] != 412);
}

- (void) test_contentObjectDavMoveAndCopy
{
  StubServerCoreContainer *container;
  StubServerCoreContainer *target;
  StubServerCoreContentObject *object;
  NSException *exception;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  target = [StubServerCoreContainer containerWithName: @"Calendar2"
						owner: @"bob"];
  object = [StubServerCoreContentObject objectWithName: @"card.vcf"
					   andContent: @"DATA"
					      inContainer: container];
  failIf([object davMoveToTargetObject: target
				newName: @"card.vcf"
			      inContext: nil] != nil);
  testEquals([object movedTo], @"Calendar2");
  exception = [object davCopyToTargetObject: target
				    newName: @"card.vcf"
				  inContext: nil];
  failIf(exception == nil);
  failIf([exception httpStatus] != 405);
}

- (void) test_folderDisplayName
{
  StubServerCoreContainer *container;
  StubServerCoreFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  testEquals([folder displayName], @"personal");
  [folder setDisplayName: @"My Calendar"];
  testEquals([folder displayName], @"My Calendar");
}

- (void) test_folderSubscription
{
  StubServerCoreContainer *container;
  StubServerCoreFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  failIf([folder isSubscription]);
  testEquals([folder realNameInContainer], @"personal");
  [folder setIsSubscription: YES];
  failIf(![folder isSubscription]);
  [folder setNameInContainer: @"bob_personal"];
  testEquals([folder realNameInContainer], @"personal");
}

- (void) test_folderTypes
{
  StubServerCoreContainer *container;
  StubServerCoreFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  testEquals([folder folderType], @"Appointment");
  failIf([folder toOneRelationshipKeys] != nil);
  failIf([folder toManyRelationshipKeys] != nil);
  failIf([folder isFolderish] != YES);
  failIf([folder davIsCollection] != YES);
  failIf([folder isValidContentName: @""]);
  failIf(![folder isValidContentName: @"x.ics"]);
}

- (void) test_folderDavURLAsString
{
  StubServerCoreContainer *container;
  StubServerCoreFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  testEquals([folder davURLAsString],
	     @"/SOGo/dav/bob/Calendar/personal/");
}

- (void) test_folderAdvisoryURLs
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  [folder setContext: (WOContext *) context];
  testEquals([folder httpURLForAdvisoryToUser: @"bob"],
	     @"http://sogo.example/SOGo/so/Calendar/personal/");
  testEquals([folder resourceURLForAdvisoryToUser: @"bob"],
	     @"http://sogo.example/SOGo/dav/Calendar/personal/");
}

- (void) test_folderCompare
{
  StubServerCoreContainer *container;
  StubServerCoreFolder *folder;
  StubServerCoreFolder *other;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreFolder objectWithName: @"work"
				    inContainer: container];
  other = [StubServerCoreFolder objectWithName: @"personal"
				   inContainer: container];
  failIf([folder compare: other] != NSOrderedDescending);
  failIf([other compare: folder] != NSOrderedAscending);
  failIf([other compare: other] != NSOrderedSame);
  [other setNameInContainer: @"work"];
  failIf([folder compare: other] != NSOrderedSame);
  [folder setDisplayName: @"Beta"];
  [other setDisplayName: @"Alpha"];
  failIf([folder compare: other] != NSOrderedDescending);
}

- (void) test_folderCompareByOrigin
{
  StubServerCoreContainer *container;
  StubServerCoreFolder *folder;
  StubServerCoreFolder *other;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreFolder objectWithName: @"work"
				    inContainer: container];
  other = [StubServerCoreFolder objectWithName: @"work"
				   inContainer: container];
  [folder setIsSubscription: YES];
  failIf([folder compare: other] != NSOrderedDescending);
  failIf([other compare: folder] != NSOrderedAscending);
  [other setIsSubscription: YES];
  failIf([folder compare: other] != NSOrderedSame);
}

- (void) test_folderDavBasics
{
  StubServerCoreContainer *container;
  StubServerCoreFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  testEquals([folder davEntityTag], @"\"None\"");
  testEquals([folder davContentType], @"httpd/unix-directory");
  testEquals([folder davResourceType], [NSArray arrayWithObject: @"collection"]);
  failIf([[folder davGroupMemberSet] count] != 0);
  failIf([[folder davGroupMembership] count] != 0);
}

- (void) test_folderDavResourceTypeGroupDav
{
  StubServerCoreContainer *container;
  StubServerCoreGroupDavFolder *folder;
  NSArray *resourceType;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGroupDavFolder objectWithName: @"personal"
					    inContainer: container];
  resourceType = [folder davResourceType];
  failIf([resourceType count] != 2);
  testEquals([resourceType objectAtIndex: 0], @"collection");
  failIf([[resourceType objectAtIndex: 1] count] != 2);
}

- (void) test_folderIsEqual
{
  StubServerCoreContainer *container;
  StubServerCoreFolder *folder;
  StubServerCoreFolder *same;
  StubServerCoreFolder *other;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  same = [StubServerCoreFolder objectWithName: @"personal"
			           inContainer: container];
  other = [StubServerCoreFolder objectWithName: @"work"
			          inContainer: container];
  failIf(![folder isEqual: same]);
  failIf([folder isEqual: other]);
  failIf([folder isEqual: [NSString string]]);
}

- (void) test_folderExtractHREFS
{
  StubServerCoreContainer *container;
  StubServerCoreFolder *folder;
  NSArray *values;
  NSArray *hrefs;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  values = [NSArray arrayWithObjects:
                   [NSDictionary dictionaryWithObjectsAndKeys:
			     @"href", @"method",
			     @"/x/", @"content",
			     nil],
                   @"<href>/y/</href>",
                   [NSDictionary dictionaryWithObjectsAndKeys:
		     @"getetag", @"method",
		     @"\"v1\"", @"content",
		     nil],
                   [NSNumber numberWithInt: 1],
                   nil];
  hrefs = [folder _extractHREFSFromPropertyValues: values];
  failIf([hrefs count] != 2);
  testEquals([hrefs objectAtIndex: 0], @"/x/");
  testEquals([hrefs objectAtIndex: 1], @"/y/");
}

- (void) test_folderInterpretWebDAVValue
{
  StubServerCoreContainer *container;
  StubServerCoreFolder *folder;
  NSArray *result;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  result = [folder _interpretWebDAVValue: @"/x/"];
  failIf([result count] != 1);
  testEquals([result objectAtIndex: 0], @"/x/");
  failIf([folder _interpretWebDAVValue: [NSNumber numberWithInt: 1]] != nil);
  result = [folder _interpretWebDAVValue:
                   [NSArray arrayWithObjects: @"getetag", @"DAV:", @"D",
			     @"\"v1\"", nil]];
  failIf([result count] != 1);
  failIf(![[result objectAtIndex: 0] isKindOfClass: [NSDictionary class]]);
  result = [folder _interpretWebDAVValue:
                   [NSArray arrayWithObjects:
                     [NSArray arrayWithObjects: @"getetag", @"DAV:", @"D",
                       @"\"v1\"", nil],
                     [NSArray arrayWithObjects: @"getcontenttype", @"DAV:", @"D",
                       @"text/plain", nil],
                     nil]];
  failIf([result count] != 2);
  failIf(![[result objectAtIndex: 0] isKindOfClass: [NSDictionary class]]);
  failIf(![[result objectAtIndex: 1] isKindOfClass: [NSDictionary class]]);
}

- (void) test_folderAclDefaults
{
  StubServerCoreContainer *container;
  StubServerCoreFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  failIf([folder defaultUserID] != nil);
  failIf([folder aclsForUser: @"alice"] != nil);
  failIf([folder aclUsers] != nil);
  failIf([[folder subscriptionRoles] count] != 5);
}

- (void) test_folderDavPrincipalURL
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreFolder *folder;
  NSArray *principalURL;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"PROPFIND"];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  [folder setContext: (WOContext *) context];
  principalURL = [folder davPrincipalURL];
  failIf([principalURL count] != 1);
  failIf([[principalURL objectAtIndex: 0] count] != 4);
  [request setICal4: YES];
  principalURL = [folder davPrincipalURL];
  failIf([principalURL count] != 1);
  failIf([[context response] headerForKey: @"DAV"] == nil);
}

- (void) test_gcsFolderBasics
{
  StubServerCoreContainer *container;
  StubServerCoreGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  failIf(![folder folderIsMandatory]);
  [folder setNameInContainer: @"work"];
  failIf([folder folderIsMandatory]);
  [folder setOCSPath: @"/Users/bob/Calendar/personal"];
  testEquals([folder ocsPath], @"/Users/bob/Calendar/personal");
  [folder setOCSPath: @"/Users/bob/Calendar/personal"];
  testEquals([folder ocsPath], @"/Users/bob/Calendar/personal");
}

- (void) test_gcsFolderReference
{
  StubServerCoreContainer *container;
  StubServerCoreGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  testEquals([folder folderReference], @"bob:Calendar/personal");
}

- (void) test_gcsPathArrayToFolder
{
  StubServerCoreContainer *container;
  StubServerCoreGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  [folder setOCSPath: @"/Users/bob/Calendar/personal"];
  testEquals([folder pathArrayToFolder],
	     ([NSArray arrayWithObjects: @"bob", @"Calendar", @"personal", nil]));
}

- (void) test_gcsSetDavDisplayNameEmpty
{
  StubServerCoreContainer *container;
  StubServerCoreGCSFolder *folder;
  NSException *exception;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  exception = [folder setDavDisplayName: @""];
  failIf(exception == nil);
  failIf([exception httpStatus] != 403);
}

- (void) test_gcsDisplayNameFromRow
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreGCSFolder *folder;
  NSDictionary *row;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  [container setDefaultFolderName: @"personal"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  [folder setContext: (WOContext *) context];
  row = [NSDictionary dictionaryWithObject: @"personal"
				   forKey: @"c_foldername"];
  testEquals([folder _displayNameFromRow: row], @"personal");
  row = [NSDictionary dictionaryWithObject: @"Custom Name"
				   forKey: @"c_foldername"];
  testEquals([folder _displayNameFromRow: row], @"Custom Name");
  row = [NSDictionary dictionary];
  failIf([folder _displayNameFromRow: row] != nil);
}

- (void) test_gcsAclSQLListingFilter
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreUser *user;
  StubServerCoreGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  [folder setContext: (WOContext *) context];
  testEquals([folder aclSQLListingFilter], @"");
  user = [StubServerCoreUser userWithLogin: @"carol"];
  [user setSuperUser: YES];
  context = [StubServerCoreContext contextWithUser: user
					   request: [StubServerCoreRequest requestWithMethod: @"GET"]];
  [folder setContext: (WOContext *) context];
  testEquals([folder aclSQLListingFilter], @"");
  user = [StubServerCoreUser userWithLogin: @"carol"];
  context = [StubServerCoreContext contextWithUser: user
					   request: [StubServerCoreRequest requestWithMethod: @"GET"]];
  [folder setContext: (WOContext *) context];
  [folder setAclRoles: [NSArray arrayWithObject: SOGoRole_ObjectViewer]];
  testEquals([folder aclSQLListingFilter], @"");
  [folder setAclRoles: [NSArray array]];
  failIf([folder aclSQLListingFilter] != nil);
}

- (void) test_gcsToOneRelationshipKeysWithoutFilter
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  context = [self contextWithLogin: @"carol" method: @"GET"];
  [folder setContext: (WOContext *) context];
  failIf([[folder toOneRelationshipKeys] count] != 0);
}

- (void) test_gcsPureHelpers
{
  StubServerCoreContainer *container;
  StubServerCoreGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  failIf([folder componentSQLFilter] != nil);
  testEquals([folder additionalWebdavSyncFilters], @"");
  failIf([folder _getMaxStartDate] != nil);
  [folder removeChildRecordWithName: @"x.ics"];
  testEquals([folder _nodeTag: @"{DAV:}getetag"], @"getetag");
  testEquals([folder _nodeTag: @"{DAV:}getetag"], [folder _nodeTag: @"{DAV:}getetag"]);
}

- (void) test_gcsDavSQLFields
{
  StubServerCoreContainer *container;
  StubServerCoreGCSFolder *folder;
  NSDictionary *fields;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  fields = [folder _davSQLFieldsForProperties:
                   [NSArray arrayWithObject: @"{DAV:}getetag"]];
  testEquals([fields objectForKey: @"{DAV:}getetag"], @"c_version");
  fields = [folder _davSQLFieldsForProperties:
                   [NSArray arrayWithObject: @"{DAV:}unknown"]];
  failIf([fields count] != 0);
}

- (void) test_gcsAclsFromUserRoles
{
  StubServerCoreContainer *container;
  StubServerCoreGCSFolder *folder;
  NSArray *records;
  NSArray *acls;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  records = [NSArray arrayWithObjects:
                   [NSDictionary dictionaryWithObjectsAndKeys:
		     @"alice", @"c_uid",
		     @"ObjectViewer", @"c_role",
		     nil],
                   [NSDictionary dictionaryWithObjectsAndKeys:
		     @"bob", @"c_uid",
		     @"ObjectEditor", @"c_role",
		     nil],
                   nil];
  acls = [folder _aclsFromUserRoles: records matchingUID: @"alice"];
  failIf([acls count] != 1);
  testEquals([acls objectAtIndex: 0], @"ObjectViewer");
  acls = [folder _aclsFromUserRoles: records matchingUID: @"nobody"];
  failIf([acls count] != 0);
}

- (void) test_gcsIsValidSyncToken
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  [folder setOCSPath: @"/Users/bob/Calendar/personal"];
  context = [self contextWithLogin: @"carol" method: @"REPORT"];
  [folder setContext: (WOContext *) context];
  failIf(![folder _isValidSyncToken: @""]);
  failIf(![folder _isValidSyncToken: @"-1"]);
  failIf(![folder _isValidSyncToken: @"123"]);
  failIf([folder _isValidSyncToken: @"12a"]);
}

- (void) test_gcsLookupNamePUT
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreGCSFolder *folder;
  SOGoContentObject *child;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"carol" method: @"PUT"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  [folder setOCSPath: @"/Users/bob/Calendar/personal"];
  [folder setContext: (WOContext *) context];
  child = [folder lookupName: @"new.ics"
		  inContext: (WOContext *) context
		      acquire: NO];
  failIf(child == nil);
  failIf(![child isKindOfClass: [SOGoContentObject class]]);
  testEquals([child nameInContainer], @"new.ics");
  failIf(![(SOGoContentObject *) child isNew]);
  [[SOGoCache sharedCache] unregisterObjectWithName: @"new.ics"
					  inContainer: folder];
}

- (void) test_gcsDeduceObjectNamesFromURLs
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreGCSFolder *folder;
  NSDictionary *names;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  [container setDavURL: @"/SOGo/dav/Calendar/"];
  context = [self contextWithLogin: @"bob" method: @"REPORT"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  [folder setContext: (WOContext *) context];
  names = [folder _deduceObjectNamesFromURLs:
                   [NSArray arrayWithObject:
                     @"http://sogo.example/SOGo/dav/Calendar/personal/card.vcf"]];
  failIf([names count] != 1);
  testEquals([names objectForKey: @"card.vcf"],
	     @"http://sogo.example/SOGo/dav/Calendar/personal/card.vcf");
  names = [folder _deduceObjectNamesFromURLs:
                   [NSArray arrayWithObject:
                     @"http://sogo.example/other/path/card.vcf"]];
  failIf([names count] != 0);
}

- (void) test_gcsAppendMissingObjectRef
{
  StubServerCoreContainer *container;
  StubServerCoreGCSFolder *folder;
  NSMutableString *buffer;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  buffer = [NSMutableString string];
  [folder appendMissingObjectRef: @"/SOGo/dav/x"
			 toBuffer: buffer];
  testEquals(buffer,
	     @"<D:response><D:href>/SOGo/dav/x</D:href>"
	     @"<D:status>HTTP/1.1 404 Not Found</D:status></D:response>");
}

- (void) test_gcsAppendPropstat
{
  StubServerCoreContainer *container;
  StubServerCoreGCSFolder *folder;
  NSMutableString *buffer;
  NSDictionary *propstat;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  buffer = [NSMutableString string];
  propstat = [NSDictionary dictionaryWithObjectsAndKeys:
			     [NSArray arrayWithObject: @"<D:getetag>x</D:getetag>"],
			     @"properties",
			     @"HTTP/1.1 200 OK",
			     @"status",
			     nil];
  [folder _appendPropstat: propstat toBuffer: buffer];
  testEquals(buffer,
	     @"<D:propstat><D:prop><D:getetag>x</D:getetag></D:prop>"
	     @"<D:status>HTTP/1.1 200 OK</D:status></D:propstat>");
}

- (void) test_gcsRenameSubscriber
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreUser *user;
  StubServerCoreGCSFolder *folder;
  NSDictionary *moduleSettings;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"alice"];
  user = [StubServerCoreUser userWithLogin: @"bob"];
  context = [StubServerCoreContext contextWithUser: user
					   request: [StubServerCoreRequest requestWithMethod: @"PROPPATCH"]];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  [folder setContext: (WOContext *) context];
  [folder setDisplayName: @"Old Name"];
  [folder renameTo: @"Old Name"];
  moduleSettings = [[user settings] objectForKey: @"Calendar"];
  failIf([moduleSettings objectForKey: @"FolderDisplayNames"] != nil);
  [folder renameTo: @"New Name"];
  moduleSettings = [[user settings] objectForKey: @"Calendar"];
  failIf([moduleSettings objectForKey: @"FolderDisplayNames"] == nil);
  testEquals([[moduleSettings objectForKey: @"FolderDisplayNames"]
               objectForKey: [folder folderReference]],
	     @"New Name");
}

- (void) test_gcsSynchronize
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreUser *user;
  StubServerCoreGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"alice"];
  user = [StubServerCoreUser userWithLogin: @"bob"];
  context = [StubServerCoreContext contextWithUser: user
					   request: [StubServerCoreRequest requestWithMethod: @"PROPFIND"]];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  [folder setContext: (WOContext *) context];
  failIf([folder synchronize]);
  [folder setSynchronize: YES];
  failIf(![folder synchronize]);
  [folder setSynchronize: NO];
  failIf([folder synchronize]);
  failIf([folder folderPropertyValueInCategory: @"FolderSynchronize"
					  forUser: (SOGoUser *) user] != nil);
}

- (void) test_retainingContainer
{
  StubServerCoreContainer *container;
  StubServerCoreRetainingObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [[StubServerCoreRetainingObject objectWithName: @"personal"
					    inContainer: container] retain];
  failIf(![object doesRetainContainer]);
  [object sleep];
  [object release];
  test(YES);
}

- (void) test_fetchSubfoldersWithCachedFolder
{
  StubServerCoreContainer *container;
  StubServerCoreKeysFolder *folder;
  NSArray *subfolders;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreKeysFolder objectWithName: @"personal"
				      inContainer: container];
  [[SOGoCache sharedCache] registerObject: @"subfolder-marker"
				   withName: @"subOne"
			       inContainer: folder];
  subfolders = [folder fetchSubfolders];
  failIf([subfolders count] != 1);
  testEquals([subfolders objectAtIndex: 0], @"subfolder-marker");
  [[SOGoCache sharedCache] unregisterObjectWithName: @"subOne"
					  inContainer: folder];
}

- (void) test_davPrincipalCollectionSet
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"PROPFIND"];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setContext: (WOContext *) context];
  failIf([object davPrincipalCollectionSet] == nil);
  [request setICal4: YES];
  failIf([object davPrincipalCollectionSet] == nil);
  failIf([[context response] headerForKey: @"DAV"] == nil);
}

- (void) test_DELETEActionWithSuccess
{
  StubServerCoreContainer *container;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  failIf(![[object DELETEAction: nil] isKindOfClass: [NSNumber class]]);
}

- (void) test_subclassResponsibilityRaises
{
  StubServerCoreContainer *container;
  SOGoObject *object;
  BOOL raised;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  raised = NO;
  NS_DURING
    {
      [object isFolderish];
    }
  NS_HANDLER
    {
      raised = YES;
      testEquals([localException name], NSInvalidArgumentException);
    }
  NS_ENDHANDLER;
  failIf(!raised);
  raised = NO;
  NS_DURING
    {
      [object aclUsers];
    }
  NS_HANDLER
    {
      raised = YES;
    }
  NS_ENDHANDLER;
  failIf(!raised);
  raised = NO;
  NS_DURING
    {
      [object aclsForUser: @"alice"];
    }
  NS_HANDLER
    {
      raised = YES;
    }
  NS_ENDHANDLER;
  failIf(!raised);
  raised = NO;
  NS_DURING
    {
      [object setRoles: nil forUser: @"alice"];
    }
  NS_HANDLER
    {
      raised = YES;
    }
  NS_ENDHANDLER;
  failIf(!raised);
  raised = NO;
  NS_DURING
    {
      [object removeAclsForUsers: nil];
    }
  NS_HANDLER
    {
      raised = YES;
    }
  NS_ENDHANDLER;
  failIf(!raised);
  raised = NO;
  NS_DURING
    {
      [object defaultUserID];
    }
  NS_HANDLER
    {
      raised = YES;
    }
  NS_ENDHANDLER;
  failIf(!raised);
  raised = NO;
  NS_DURING
    {
      [object httpURLForAdvisoryToUser: @"alice"];
    }
  NS_HANDLER
    {
      raised = YES;
    }
  NS_ENDHANDLER;
  failIf(!raised);
  raised = NO;
  NS_DURING
    {
      [object resourceURLForAdvisoryToUser: @"alice"];
    }
  NS_HANDLER
    {
      raised = YES;
    }
  NS_ENDHANDLER;
  failIf(!raised);
}

- (void) test_setRolesForUsers
{
  StubServerCoreContainer *container;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setRoles: [NSArray arrayWithObject: @"ObjectViewer"]
	  forUsers: [NSArray arrayWithObjects: @"alice", @"carol", nil]];
  failIf([[container setRolesCalls] count] != 2);
}

- (void) test_setOwnerWithContext
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  [object setContext: (WOContext *) context];
  [object setOwner: @"bob"];
  failIf(![object ignoreRights]);
  [object setOwner: @"alice"];
  failIf([object ignoreRights]);
}

- (void) test_subscriptionRoles
{
  StubServerCoreContainer *container;
  SOGoObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoObject objectWithName: @"personal"
			  inContainer: container];
  testEquals([object subscriptionRoles], [NSArray arrayWithObject: @"ObjectViewer"]);
}

- (void) test_checkIfNoneMatchConditionEmpty
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setEtag: @"\"v1\""];
  context = [self contextWithLogin: @"bob" method: @"GET"];
  failIf([object checkIfNoneMatchCondition: @""
				 inContext: (WOContext *) context] != nil);
}

- (void) test_davPOSTRequestWithCommand
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreObject *object;
  id result;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"POST"];
  [request setDOMDocument: [NGDOMDocument documentFromString:
				   @"<custom-thing/>"]];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  result = [object davPOSTRequest: request
		   withContentType: @"application/xml"
			 inContext: (WOContext *) context];
  testEquals(result, @"custom-marker");
}

- (void) test_davAclActionFromQuery
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreUser *alice;
  StubServerCoreObject *object;
  id document;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  alice = [[StubServerCoreUser userWithLogin: @"alice"] retain];
  [alice setCn: @"Alice Wonderland"];
  [alice setAllEmails: [NSArray arrayWithObject: @"alice@example.com"]];
  [[SOGoCache sharedCache] registerUser: alice
				withName: @"alice"];
  context = [self contextWithLogin: @"bob" method: @"REPORT"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setContext: (WOContext *) context];
  [object setDefaultUID: @"<default>"];
  [object setAclUsers: [NSArray arrayWithObject: @"alice"]];
  [object setAcls: [NSArray array]];
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><user-list params='nocn,noemail'/></acl-query>"];
  testEquals([object _davAclActionFromQuery: document],
	     @"<user-list><default-user><id>&lt;default&gt;</id></default-user>"
	     @"<user><id>alice</id></user></user-list>");
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><roles user='alice'/></acl-query>"];
  [object setAcls: [NSArray arrayWithObject: @"ObjectViewer"]];
  testEquals([object _davAclActionFromQuery: document],
	     @"<roles><ObjectViewer/></roles>");
  [[SOGoCache sharedCache] killCache];
  [alice release];
}

- (void) test_davAclActionSetRoles
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;
  id document;
  NSString *result;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"REPORT"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setContext: (WOContext *) context];
  [object setAcls: [NSArray array]];
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><set-roles user='alice'>"
		     @"<ObjectViewer/><ObjectEditor/></set-roles></acl-query>"];
  result = [object _davAclActionFromQuery: document];
  testEquals(result, @"");
  failIf([[container setRolesCalls] count] != 1);
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><set-roles users='alice,carol'>"
		     @"<ObjectViewer/></set-roles></acl-query>"];
  result = [object _davAclActionFromQuery: document];
  testEquals(result, @"");
  failIf([[container setRolesCalls] count] != 3);
  context = [self contextWithLogin: @"carol" method: @"REPORT"];
  [object setContext: (WOContext *) context];
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><set-roles user='alice'>"
		     @"<ObjectViewer/></set-roles></acl-query>"];
  failIf([object _davAclActionFromQuery: document] != nil);
}

- (void) test_davAclActionAddRemoveUsers
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreObject *object;
  id document;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"bob" method: @"REPORT"];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setContext: (WOContext *) context];
  [object setAcls: [NSArray array]];
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><add-user user='alice'/></acl-query>"];
  testEquals([object _davAclActionFromQuery: document], @"");
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><add-user user=''/></acl-query>"];
  failIf([object _davAclActionFromQuery: document] != nil);
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><add-user user='bob'/></acl-query>"];
  failIf([object _davAclActionFromQuery: document] != nil);
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><add-users users='alice,carol'/></acl-query>"];
  testEquals([object _davAclActionFromQuery: document], @"");
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><add-users users='alice,bob'/></acl-query>"];
  failIf([object _davAclActionFromQuery: document] != nil);
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><remove-user user='alice'/></acl-query>"];
  testEquals([object _davAclActionFromQuery: document], @"");
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><remove-user user=''/></acl-query>"];
  failIf([object _davAclActionFromQuery: document] != nil);
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><remove-users users='alice,carol'/></acl-query>"];
  testEquals([object _davAclActionFromQuery: document], @"");
  document = [NGDOMDocument documentFromString:
		     @"<acl-query><unknown-node/></acl-query>"];
  failIf([object _davAclActionFromQuery: document] != nil);
}

- (void) test_davAclQuery
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreObject *object;
  WOResponse *response;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"REPORT"];
  [request setDOMDocument: [NGDOMDocument documentFromString:
				   @"<acl-query><user-list params='nocn,noemail'/></acl-query>"]];
  context = [self contextWithLogin: @"bob" method: @"REPORT"];
  [context setRequest: request];
  object = [StubServerCoreObject objectWithName: @"personal"
				    inContainer: container];
  [object setContext: (WOContext *) context];
  [object setDefaultUID: @"<default>"];
  [object setAclUsers: [NSArray array]];
  response = [object davAclQuery: (WOContext *) context];
  failIf(response == nil);
  failIf([response status] != 207);
  testEquals([response headerForKey: @"content-type"],
	     @"application/xml; charset=\"utf-8\"");
  [request setDOMDocument: [NGDOMDocument documentFromString:
				   @"<acl-query><unknown-node/></acl-query>"]];
  response = [object davAclQuery: (WOContext *) context];
  failIf([response status] != 400);
  [request setDOMDocument: [NGDOMDocument documentFromString:
				   @"<acl-query><remove-user user='alice'/></acl-query>"]];
  response = [object davAclQuery: (WOContext *) context];
  failIf([response status] != 204);
}

- (void) test_contentObjectSubclassResponsibility
{
  StubServerCoreContainer *container;
  SOGoContentObject *object;
  BOOL raised;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  object = [SOGoContentObject objectWithName: @"card.vcf"
				  andContent: @"DATA"
				 inContainer: container];
  raised = NO;
  NS_DURING
    {
      [object parsingClass];
    }
  NS_HANDLER
    {
      raised = YES;
      testEquals([localException name], NSInvalidArgumentException);
    }
  NS_ENDHANDLER;
  failIf(!raised);
  raised = NO;
  NS_DURING
    {
      [object copyToFolder: nil];
    }
  NS_HANDLER
    {
      raised = YES;
    }
  NS_ENDHANDLER;
  failIf(!raised);
  raised = NO;
  NS_DURING
    {
      [object moveToFolder: nil];
    }
  NS_HANDLER
    {
      raised = YES;
    }
  NS_ENDHANDLER;
  failIf(!raised);
}

- (void) test_contentObjectPUTActionMultipleEtags
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreContentObject *object;
  WOResponse *response;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"PUT"
						  headers: [NSDictionary dictionaryWithObjectsAndKeys:
							      @"\"gcs00000000\", \"other\"", @"if-match",
							      nil]];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  object = [StubServerCoreContentObject objectWithName: @"card.vcf"
					   andContent: @"DATA"
					      inContainer: container];
  response = [object PUTAction: (WOContext *) context];
  failIf(response == nil);
  failIf([response status] != 204);
}

- (void) test_contentObjectPUTActionSaveError
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreFailingContentObject *object;
  id response;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"PUT"];
  [request setBody: @"BEGIN:VCARD\nVERSION:3.0\nUID:x\nFN:x\nEND:VCARD\n"];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  object = [StubServerCoreFailingContentObject objectWithName: @"card.vcf"
						   andContent: @"DATA"
						      inContainer: container];
  response = [object PUTAction: (WOContext *) context];
  failIf(response == nil);
  failIf(![response isKindOfClass: [NSException class]]);
  testEquals([response name], @"SaveFailed");
}

- (void) test_folderSubclassResponsibility
{
  StubServerCoreContainer *container;
  SOGoFolder *folder;
  BOOL raised;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [SOGoFolder objectWithName: @"personal"
			  inContainer: container];
  raised = NO;
  NS_DURING
    {
      [folder folderType];
    }
  NS_HANDLER
    {
      raised = YES;
      testEquals([localException name], NSInvalidArgumentException);
    }
  NS_ENDHANDLER;
  failIf(!raised);
}

- (void) test_folderSendAdvisoryTemplate
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreUser *owner;
  StubServerCoreFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  owner = [[StubServerCoreUser userWithLogin: @"bob"] retain];
  [[SOGoCache sharedCache] registerUser: owner
				withName: @"bob"];
  context = [StubServerCoreContext contextWithUser: owner
					   request: [StubServerCoreRequest requestWithMethod: @"PUT"]];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  [folder setContext: (WOContext *) context];
  [folder sendFolderAdvisoryTemplate: @"Addition"];
  [(StubServerCoreDomainDefaults *) [owner domainDefaults] setFoldersSendEmail: YES];
  [folder sendFolderAdvisoryTemplate: @"Removal"];
  [[SOGoCache sharedCache] killCache];
  [owner release];
  test(YES);
}

- (void) test_folderInterpretSoWebDAVValue
{
  StubServerCoreContainer *container;
  StubServerCoreFolder *folder;
  SOGoWebDAVValue *value;
  NSArray *result;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  value = [davElementWithContent (@"href", XMLNS_WEBDAV, @"/x/")
             asWebDAVValue];
  result = [folder _interpretWebDAVValue: value];
  failIf(result == nil);
  failIf([result count] != 1);
}

- (void) test_folderDavExpandProperty
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreRequest *request;
  StubServerCoreFolder *folder;
  WOResponse *response;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  request = [StubServerCoreRequest requestWithMethod: @"REPORT"];
  [request setDOMDocument: [NGDOMDocument documentFromString:
				   @"<expand-property xmlns='DAV:'>"
				   @"<property name='displayname' namespace='DAV:'/>"
				   @"</expand-property>"]];
  context = [StubServerCoreContext contextWithUser: nil
					   request: request];
  folder = [StubServerCoreFolder objectWithName: @"personal"
				    inContainer: container];
  [folder setContext: (WOContext *) context];
  response = [folder davExpandProperty: (WOContext *) context];
  failIf(response == nil);
  failIf([response status] != 207);
  [request setDOMDocument: [NGDOMDocument documentFromString:
				   @"<expand-property xmlns='DAV:'>"
				   @"<property name='unknown-property' namespace='DAV:'/>"
				   @"</expand-property>"]];
  response = [folder davExpandProperty: (WOContext *) context];
  failIf([response status] != 207);
}

- (void) test_gcsFolderWithSubscriptionReference
{
  StubServerCoreContainer *container;
  SOGoGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"alice"];
  folder = [SOGoGCSFolder folderWithSubscriptionReference: @"bob:Calendar/personal"
						  inContainer: container];
  failIf(folder != nil);
}

- (void) test_gcsDisplayName
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreUser *user;
  StubServerCoreGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"alice"];
  user = [StubServerCoreUser userWithLogin: @"bob"];
  context = [StubServerCoreContext contextWithUser: user
					   request: [StubServerCoreRequest requestWithMethod: @"PROPFIND"]];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  [folder setContext: (WOContext *) context];
  failIf([folder displayName] != nil);
  [[user settings] setObject: [NSMutableDictionary dictionary]
		     forKey: @"Calendar"];
  [[[user settings] objectForKey: @"Calendar"]
    setObject: [NSMutableDictionary dictionaryWithObject: @"Sub Name"
						  forKey: [folder folderReference]]
      forKey: @"FolderDisplayNames"];
  testEquals([folder displayName], @"Sub Name");
}

- (void) test_gcsDeleteEntriesWithIds
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"carol" method: @"REPORT"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  [folder setOCSPath: @"/Users/bob/Calendar/personal"];
  [folder setContext: (WOContext *) context];
  [folder deleteEntriesWithIds: [NSArray arrayWithObject: @"missing/missing.ics"]];
  test(YES);
}

- (void) test_gcsDavCollectionTag
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"carol" method: @"PROPFIND"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  [folder setOCSPath: @"/Users/bob/Calendar/personal"];
  [folder setContext: (WOContext *) context];
  testEquals([folder davCollectionTag], @"-1");
}

- (void) test_gcsUserIsSubscriber
{
  StubServerCoreContainer *container;
  StubServerCoreUser *bob;
  StubServerCoreGCSFolder *folder;
  NSMutableDictionary *moduleSettings;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"alice"];
  bob = [[StubServerCoreUser userWithLogin: @"bob"] retain];
  [[SOGoCache sharedCache] registerUser: bob
				withName: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  failIf([folder userIsSubscriber: @"bob"]);
  moduleSettings = [NSMutableDictionary dictionary];
  [moduleSettings setObject: [NSMutableArray arrayWithObject: [folder folderReference]]
		     forKey: @"SubscribedFolders"];
  [[bob settings] setObject: moduleSettings
		     forKey: @"Calendar"];
  failIf(![folder userIsSubscriber: @"bob"]);
  [[SOGoCache sharedCache] killCache];
  [bob release];
}

- (void) test_gcsAclsForUserForObjectAtPath
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreGCSFolder *folder;
  NSArray *acls;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  context = [self contextWithLogin: @"carol" method: @"PROPFIND"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  [folder setOCSPath: @"/Users/bob/Calendar/personal"];
  [folder setContext: (WOContext *) context];
  [[SOGoCache sharedCache] setACLs: [NSDictionary dictionaryWithObject: [NSArray arrayWithObject: @"ObjectViewer"]
								    forKey: @"bob"]
			   forPath: @"bob/Calendar/personal"];
  acls = [folder aclsForUser: @"bob"
	       forObjectAtPath: [NSArray arrayWithObjects: @"bob", @"Calendar", @"personal", nil]];
  failIf([acls count] != 1);
  testEquals([acls objectAtIndex: 0], @"ObjectViewer");
  [[SOGoCache sharedCache] removeValueForKey: @"bob/Calendar/personal+acl"];
}

- (void) test_gcsInitializeQuickTablesAcls
{
  StubServerCoreContainer *container;
  StubServerCoreContext *context;
  StubServerCoreUser *user;
  StubServerCoreGCSFolder *folder;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  context = [self contextWithLogin: @"bob" method: @"REPORT"];
  [folder initializeQuickTablesAclsInContext: (WOContext *) context];
  context = [self contextWithLogin: @"carol" method: @"REPORT"];
  [folder initializeQuickTablesAclsInContext: (WOContext *) context];
  user = [StubServerCoreUser userWithLogin: @"carol"];
  [user setSuperUser: YES];
  context = [StubServerCoreContext contextWithUser: user
					   request: [StubServerCoreRequest requestWithMethod: @"REPORT"]];
  [folder initializeQuickTablesAclsInContext: (WOContext *) context];
  test(YES);
}

- (void) test_gcsParseDAVRequestedProperties
{
  StubServerCoreContainer *container;
  StubServerCoreGCSFolder *folder;
  NSDictionary *fields;

  container = [StubServerCoreContainer containerWithName: @"Calendar"
						   owner: @"bob"];
  folder = [StubServerCoreGCSFolder objectWithName: @"personal"
				       inContainer: container];
  fields = [folder parseDAVRequestedProperties:
                   [[NGDOMDocument documentFromString:
                     @"<prop><getetag xmlns='DAV:'/></prop>"] documentElement]];
  failIf([fields count] != 1);
  testEquals([fields objectForKey: @"{DAV:}getetag"], @"c_version");
}

@end
