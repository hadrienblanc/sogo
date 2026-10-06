# GNUstep makefile

debug=yes

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../../Version

TEST_TOOL = sogo-tests
$(TEST_TOOL)_INSTALL_DIR = $(SOGO_ADMIN_TOOLS)
$(TEST_TOOL)_OBJC_FILES += \
	sogo-tests.m \
	\
	SOGoTest.m \
	SOGoTestRunner.m \
	SOGoDraftObjectTestCase.m \
	SaxXMLReaderFactory+SOGoTests.m \
	../../SoObjects/Mailer/NSString+Mail.m \
	../../SoObjects/Mailer/NSData+Mail.m \
	../../SoObjects/SOGo/NSArray+Utilities.m \
	../../SoObjects/SOGo/NSDictionary+Utilities.m \
	../../SoObjects/SOGo/NSNull+Utilities.m \
	../../SoObjects/SOGo/NSNumber+Utilities.m \
	../../SoObjects/SOGo/NSObject+Utilities.m \
	\
	TestContainerUtilities.m \
	\
	TestVersit.m \
	TestNGCardsCore.m \
	TestiCalCalendarInvitationUpdate.m \
	TestiCalTimeZonePeriod.m \
	TestiCalTimeZoneFallback.m \
	TestiCalTimeZoneSystemFallback.m \
	TestiCalRecurrenceCalculator.m \
	TestiCalRecurrenceCalculatorInclusiveUntilDate.m \
	TestiCalRepeatableEntityObject+SOGo.m \
	TestiCalRecurrenceRule+SOGo.m \
	TestiCalRepeatableEntityObjectExceptionDates.m \
	TestiCalRepeatableEntityObjectRecurrenceDates.m \
	TestiCalRepeatableEntityObjectInvitation.m \
	TestiCalEvent+SOGo.m \
	TestiCalEntityObjectQuickRecordDates.m \
	TestiCalEvent+ActiveSync.m \
	TestiCalToDo+ActiveSync.m \
	TestiCalPerson+SOGo.m \
	TestiCalEntityObjectAttachUrls.m \
	TestiCalEntityObjectAttributes.m \
	TestiCalEntityObjectDescriptionAltRep.m \
	TestiCalEntityObjectResetCreationMetadata.m \
	TestiCalEntityObjectVersionCompare.m \
	TestNSCalendarDateClamping.m \
	TestGCSChannelManager.m \
	\
	TestSBJsonParser.m \
	\
	TestNGMimeAddressHeaderFieldGenerator.m \
	TestNGMimeHeaderFieldGenerator.m \
	TestNGMimeMessageGenerator.m \
	TestNGMimeType.m \
	TestNGMimeTypeUnknownParameters.m \
	TestNGMimeBodyPart+SOGo.m \
	\
	TestNGNetUtlilities.m \
	TestNSData+Crypto.m \
	TestNSString+Crypto.m \
	TestNSString+URLEscaping.m \
	TestNSString+Utilities.m \
	TestNSString+Imap4LabelName.m \
	TestNSData+Mail.m \
	TestNSString+ActiveSync.m \
	TestNGDOMElement+ActiveSync.m \
	TestNSString+Mail.m \
	TestNSStringMailHelpers.m \
	TestNSDataMail.m \
 	TestNSCalendarDateSOGo.m \
	TestNSStringMailFilename.m \
	TestNGCardsGeo.m \
	TestSOGoAppointmentObjectParticipationStatus.m \
	TestNSArray+Utilities.m \
	TestNSArray+SyncCache.m \
	TestNSString+CKEditorUserAgentOverride.m \
	TestNSURL+misc.m \
	TestNSURL+GCS.m \
	TestNGMailAddressParser.m \
	TestNGImap4ConnectionDelimiter.m \
	TestNGInternetSocketAddress.m \
	\
	TestRTFHandler.m \
	TestSOGoHTMLSanitizer.m \
	TestSOGoFreeBusyObject.m \
	../../SoObjects/Contacts/NGVCard+SOGo.m \
	../../SoObjects/Contacts/NSDictionary+LDIF.m \
	../../SoObjects/Contacts/NSString+LDIF.m \
	../../SoObjects/SOGo/SOGoDateFormatter.m \
	TestContactsLDIF.m \
	TestServerCore.m \
	TestLDAPSourceUserAddressBooks.m \
	TestLDAPSourceEncryption.m \
	TestNSDictionary+Utilities.m \
	TestLDAPSourceUserSearchFilter.m \
	TestNGVList.m \
	TestNGVList+SOGo.m \
	TestSOGoDraftObject.m \
	TestSOGoDraftObjectIDNFrom.m \
	TestSOGoDraftObjectQuoteSpecials.m \
	TestSOGoDraftsFolder.m \
	TestSOGoMailFolder.m \
	TestSOGoMailFolderSortOrder.m \
	TestSOGoMailForward.m \
	TestSOGoMailReply.m \
	TestSOGoMailerAccountSelection.m \
	TestSOGoSieveClientLifecycle.m \
	TestSOGoSieveManager.m \
	TestSOGoUserDefaults.m \
	TestSOGoUserManagerSources.m \
	TestSOGoUserManagerEmailQualification.m \
	TestSOGoUserFolderCalendarUserAddressSet.m \
	TestSOGoProxyAuthenticator.m \
	TestSQLSourcePasswordCheck.m \
	TestSQLSourceLookupContactEntries.m \
	TestSOGoUserProfile.m \
	TestSOGoWebDAVAclManager.m \
	TestSOGoFolderSubscriptionRoles.m \
	TestSOGoGCSFolderDelete.m \
	TestSOGoGCSFolderWebDAVSync.m \
	TestSOGoAppointmentFolderNewEventsAsFree.m \
	TestSOGoAppointmentObjectConflictWindow.m \
	TestSOGoAppointmentObjectStoreErrors.m \
	TestSOGoCalendarComponentCopy.m \
	TestSOGoCalendarComponentICalAttachment.m \
	TestSOGoContactSourceFolder.m \
	TestNGVCard+SOGo.m \
	TestSOGoCacheACLs.m \
	TestSOGoCacheLifecycle.m \
	TestUIxListEditor.m \
	TestUIxContactFolderActionsMobileconfig.m \
	TestUIxMailRenderingContext.m \
	TestUIxMailEditorReplyTo.m \
	TestUIxMailListActionsChanges.m \
	TestUIxJSONPreferences.m \
	TestMailerUnseenCountReset.m \
	TestMailerSortListLocalization.m \
	TestMailerIMAP4ConnectionFallback.m \
	TestExpandButtonAccessibility.m \
	TestWORequest+SOGo.m \
	TestApacheAliasDirectives.m \
	\
	../../UI/MailPartViewers/UIxMailRenderingContext.m \
	../../UI/MailerUI/WOContext+UIxMailer.m \
	../../UI/MailerUI/UIxMailFormatter.m \
	../../UI/MailerUI/UIxEnvelopeAddressFormatter.m \
	../../UI/SOGoUI/SOGoDirectAction.m \
	../../UI/MailPartViewers/UIxMailSizeFormatter.m \
	../../UI/MailerUI/UIxMailListActions.m \
	../../UI/MailerUI/UIxMailEditor.m \
	../../UI/Contacts/UIxListEditor.m \
	../../UI/Contacts/UIxContactFolderActions.m \
	../../UI/SOGoUI/UIxComponent.m \
	../../UI/PreferencesUI/UIxJSONPreferences.m \
	../../UI/PreferencesUI/PreferencesUIProduct.m \
	../../ActiveSync/iCalEvent+ActiveSync.m \
	../../ActiveSync/iCalToDo+ActiveSync.m \
	../../ActiveSync/NSArray+SyncCache.m \
	../../ActiveSync/NGDOMElement+ActiveSync.m \
	../../ActiveSync/SOGoSyncCacheObject.m \
	../../ActiveSync/NSString+ActiveSync.m \
	../../ActiveSync/NSDate+ActiveSync.m \
	\
    # I don't know how to link against -l:SOGoBackend \
	     undefined reference to `__objc_class_name_SOGoMailFolder'

TEST_TOOL_NAME = $(TEST_TOOL)

$(TEST_TOOL)_CPPFLAGS += \
	-Wall -D_GNU_SOURCE -I../../ -I../../SOPE/ -I../../SoObjects/ -I../../UI/ -I../../UI/MailPartViewers -I../../ActiveSync -I../../SoObjects/Contacts $(shell xml2-config --cflags)

ADDITIONAL_LIB_DIRS += \
	-L../../SoObjects/SOGo/SOGo.framework/Versions/Current/sogo -L../../SOPE/NGCards/obj -L../../SOPE/GDLContentStore/obj -lSOGo -lNGObjWeb -lDOM -lNGMime -lNGCards -lGDLContentStore -lNGExtensions -lSBJson -lobjc \
	-L../../SoObjects/Appointments/Appointments.SOGo -l:Appointments \
	-L../../SoObjects/Contacts/Contacts.SOGo -l:Contacts \
	-L/usr/local/lib  -lSaxObjC -lNGStreams -lEOControl \
	-Wl,-rpath,../../SoObjects/SOGo/SOGo.framework/Versions/Current/sogo -Wl,-rpath,../../SOPE/NGCards/obj -Wl,-rpath,../../SOPE/GDLContentStore/obj -Wl,-rpath,../../SoObjects/Appointments/Appointments.SOGo -Wl,-rpath,../../SoObjects/Contacts/Contacts.SOGo
ADDITIONAL_LDFLAGS += -Wl,--no-as-needed -Wl,--unresolved-symbols=ignore-in-object-files

ifeq ($(HAS_LIBRARY_sodium), yes)
ADDITIONAL_CPPFLAGS += -DHAVE_SODIUM=1 `pkg-config --cflags libsodium`
endif


-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/test-tool.make

before-all::
	$(MAKE) -C ../../SoObjects/Appointments --no-print-directory all
	$(MAKE) -C ../../SoObjects/Contacts --no-print-directory all
	$(MAKE) -C ../../SoObjects/Mailer --no-print-directory all

-include GNUmakefile.postamble

check :: $(TEST_TOOL)
	./obj/sogo-tests
