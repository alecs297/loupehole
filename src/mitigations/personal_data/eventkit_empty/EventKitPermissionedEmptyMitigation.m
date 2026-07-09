#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <EventKit/EventKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef EKAuthorizationStatus (*LHEventKitAuthorizationStatusOriginal)(id self, SEL selector, EKEntityType entityType);
typedef void (*LHEventKitRequestAccessOriginal)(EKEventStore *self, SEL selector, EKEntityType entityType, void (^completion)(BOOL granted, NSError *error));
typedef void (*LHEventKitRequestFullAccessOriginal)(EKEventStore *self, SEL selector, void (^completion)(BOOL granted, NSError *error));
typedef NSArray<EKCalendar *> *(*LHEventKitCalendarsOriginal)(EKEventStore *self, SEL selector, EKEntityType entityType);
typedef NSPredicate *(*LHEventKitEventPredicateOriginal)(EKEventStore *self, SEL selector, NSDate *startDate, NSDate *endDate, NSArray<EKCalendar *> *calendars);
typedef NSArray<EKEvent *> *(*LHEventKitEventsMatchingOriginal)(EKEventStore *self, SEL selector, NSPredicate *predicate);
typedef void (*LHEventKitEnumerateEventsOriginal)(EKEventStore *self, SEL selector, NSPredicate *predicate, void (^block)(EKEvent *event, BOOL *stop));
typedef NSPredicate *(*LHEventKitReminderPredicateOriginal)(EKEventStore *self, SEL selector, NSDate *startDate, NSDate *endDate, NSArray<EKCalendar *> *calendars);
typedef void (*LHEventKitFetchRemindersOriginal)(EKEventStore *self, SEL selector, NSPredicate *predicate, void (^completion)(NSArray<EKReminder *> *reminders));

static LHEventKitAuthorizationStatusOriginal LHEventKitAuthorizationStatusOriginalImplementation;
static LHEventKitRequestAccessOriginal LHEventKitRequestAccessOriginalImplementation;
static LHEventKitRequestFullAccessOriginal LHEventKitRequestFullAccessToEventsOriginalImplementation;
static LHEventKitRequestFullAccessOriginal LHEventKitRequestWriteOnlyAccessToEventsOriginalImplementation;
static LHEventKitRequestFullAccessOriginal LHEventKitRequestFullAccessToRemindersOriginalImplementation;
static LHEventKitCalendarsOriginal LHEventKitCalendarsOriginalImplementation;
static LHEventKitEventPredicateOriginal LHEventKitEventPredicateOriginalImplementation;
static LHEventKitEventsMatchingOriginal LHEventKitEventsMatchingOriginalImplementation;
static LHEventKitEnumerateEventsOriginal LHEventKitEnumerateEventsOriginalImplementation;
static LHEventKitReminderPredicateOriginal LHEventKitReminderPredicateOriginalImplementation;
static LHEventKitFetchRemindersOriginal LHEventKitFetchRemindersOriginalImplementation;

/** Returns whether the EventKit entity belongs to this personal-data mitigation. */
static bool LHEventKitOwnsEntityType(EKEntityType entityType) {
    return entityType == EKEntityTypeEvent || entityType == EKEntityTypeReminder;
}

/** Replacement for `+[EKEventStore authorizationStatusForEntityType:]`. */
static EKAuthorizationStatus LHEventKitAuthorizationStatusReplacement(id self, SEL selector, EKEntityType entityType) {
    if (LHEventKitOwnsEntityType(entityType)) {
        return EKAuthorizationStatusAuthorized;
    }

    if (LHEventKitAuthorizationStatusOriginalImplementation != 0) {
        return LHEventKitAuthorizationStatusOriginalImplementation(self, selector, entityType);
    }
    return EKAuthorizationStatusNotDetermined;
}

/** Replacement for deprecated `-[EKEventStore requestAccessToEntityType:completion:]`. */
static void LHEventKitRequestAccessReplacement(EKEventStore *self, SEL selector, EKEntityType entityType, void (^completion)(BOOL granted, NSError *error)) {
    if (LHEventKitOwnsEntityType(entityType)) {
        if (completion != nil) {
            completion(YES, nil);
        }
        return;
    }

    if (LHEventKitRequestAccessOriginalImplementation != 0) {
        LHEventKitRequestAccessOriginalImplementation(self, selector, entityType, completion);
    } else if (completion != nil) {
        completion(NO, nil);
    }
}

/** Completion-only success for newer full/write-only EventKit access APIs. */
static void LHEventKitRequestFullAccessReplacement(EKEventStore *self, SEL selector, void (^completion)(BOOL granted, NSError *error)) {
    (void)self;
    (void)selector;
    if (completion != nil) {
        completion(YES, nil);
    }
}

/** Replacement for `-[EKEventStore calendarsForEntityType:]`. */
static NSArray<EKCalendar *> *LHEventKitCalendarsReplacement(EKEventStore *self, SEL selector, EKEntityType entityType) {
    if (LHEventKitOwnsEntityType(entityType)) {
        return @[];
    }

    if (LHEventKitCalendarsOriginalImplementation != 0) {
        return LHEventKitCalendarsOriginalImplementation(self, selector, entityType);
    }
    return @[];
}

/** Replacement for `-[EKEventStore predicateForEventsWithStartDate:endDate:calendars:]`. */
static NSPredicate *LHEventKitEventPredicateReplacement(EKEventStore *self, SEL selector, NSDate *startDate, NSDate *endDate, NSArray<EKCalendar *> *calendars) {
    if (calendars == nil || [calendars count] == 0) {
        return [NSPredicate predicateWithValue:NO];
    }

    if (LHEventKitEventPredicateOriginalImplementation != 0) {
        return LHEventKitEventPredicateOriginalImplementation(self, selector, startDate, endDate, calendars);
    }
    return [NSPredicate predicateWithValue:NO];
}

/** Replacement for `-[EKEventStore eventsMatchingPredicate:]`. */
static NSArray<EKEvent *> *LHEventKitEventsMatchingReplacement(EKEventStore *self, SEL selector, NSPredicate *predicate) {
    (void)self;
    (void)selector;
    (void)predicate;
    return @[];
}

/** Replacement for `-[EKEventStore enumerateEventsMatchingPredicate:usingBlock:]`. */
static void LHEventKitEnumerateEventsReplacement(EKEventStore *self, SEL selector, NSPredicate *predicate, void (^block)(EKEvent *event, BOOL *stop)) {
    (void)self;
    (void)selector;
    (void)predicate;
    (void)block;
}

/** Replacement for `-[EKEventStore predicateForIncompleteRemindersWithDueDateStarting:ending:calendars:]`. */
static NSPredicate *LHEventKitReminderPredicateReplacement(EKEventStore *self, SEL selector, NSDate *startDate, NSDate *endDate, NSArray<EKCalendar *> *calendars) {
    if (calendars == nil || [calendars count] == 0) {
        return [NSPredicate predicateWithValue:NO];
    }

    if (LHEventKitReminderPredicateOriginalImplementation != 0) {
        return LHEventKitReminderPredicateOriginalImplementation(self, selector, startDate, endDate, calendars);
    }
    return [NSPredicate predicateWithValue:NO];
}

/** Replacement for `-[EKEventStore fetchRemindersMatchingPredicate:completion:]`. */
static void LHEventKitFetchRemindersReplacement(EKEventStore *self, SEL selector, NSPredicate *predicate, void (^completion)(NSArray<EKReminder *> *reminders)) {
    (void)self;
    (void)selector;
    (void)predicate;
    if (completion != nil) {
        completion(@[]);
    }
}

/** Hooks one EventKit selector and records whether it installed. */
static bool LHEventKitHookMessage(LHHookBackend *backend, Class targetClass, const char *selectorName, void *replacement, void **original) {
    SEL selector = sel_registerName(selectorName);
    if (selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original);
}

/** Installs Calendar and Reminders empty-inventory hooks. */
bool LHMitigation_personal_data_eventkit_inventory_empty_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class storeClass = NSClassFromString(@"EKEventStore");
    if (storeClass == Nil) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_personal_data_eventkit_inventory_empty);
    }

    bool installed = false;
    Class metaClass = object_getClass(storeClass);
    installed = LHEventKitHookMessage(backend,
                                      metaClass,
                                      "authorizationStatusForEntityType:",
                                      (void *)LHEventKitAuthorizationStatusReplacement,
                                      (void **)&LHEventKitAuthorizationStatusOriginalImplementation) || installed;
    installed = LHEventKitHookMessage(backend,
                                      storeClass,
                                      "requestAccessToEntityType:completion:",
                                      (void *)LHEventKitRequestAccessReplacement,
                                      (void **)&LHEventKitRequestAccessOriginalImplementation) || installed;
    installed = LHEventKitHookMessage(backend,
                                      storeClass,
                                      "requestFullAccessToEventsWithCompletion:",
                                      (void *)LHEventKitRequestFullAccessReplacement,
                                      (void **)&LHEventKitRequestFullAccessToEventsOriginalImplementation) || installed;
    installed = LHEventKitHookMessage(backend,
                                      storeClass,
                                      "requestWriteOnlyAccessToEventsWithCompletion:",
                                      (void *)LHEventKitRequestFullAccessReplacement,
                                      (void **)&LHEventKitRequestWriteOnlyAccessToEventsOriginalImplementation) || installed;
    installed = LHEventKitHookMessage(backend,
                                      storeClass,
                                      "requestFullAccessToRemindersWithCompletion:",
                                      (void *)LHEventKitRequestFullAccessReplacement,
                                      (void **)&LHEventKitRequestFullAccessToRemindersOriginalImplementation) || installed;
    installed = LHEventKitHookMessage(backend,
                                      storeClass,
                                      "calendarsForEntityType:",
                                      (void *)LHEventKitCalendarsReplacement,
                                      (void **)&LHEventKitCalendarsOriginalImplementation) || installed;
    installed = LHEventKitHookMessage(backend,
                                      storeClass,
                                      "predicateForEventsWithStartDate:endDate:calendars:",
                                      (void *)LHEventKitEventPredicateReplacement,
                                      (void **)&LHEventKitEventPredicateOriginalImplementation) || installed;
    installed = LHEventKitHookMessage(backend,
                                      storeClass,
                                      "eventsMatchingPredicate:",
                                      (void *)LHEventKitEventsMatchingReplacement,
                                      (void **)&LHEventKitEventsMatchingOriginalImplementation) || installed;
    installed = LHEventKitHookMessage(backend,
                                      storeClass,
                                      "enumerateEventsMatchingPredicate:usingBlock:",
                                      (void *)LHEventKitEnumerateEventsReplacement,
                                      (void **)&LHEventKitEnumerateEventsOriginalImplementation) || installed;
    installed = LHEventKitHookMessage(backend,
                                      storeClass,
                                      "predicateForIncompleteRemindersWithDueDateStarting:ending:calendars:",
                                      (void *)LHEventKitReminderPredicateReplacement,
                                      (void **)&LHEventKitReminderPredicateOriginalImplementation) || installed;
    installed = LHEventKitHookMessage(backend,
                                      storeClass,
                                      "fetchRemindersMatchingPredicate:completion:",
                                      (void *)LHEventKitFetchRemindersReplacement,
                                      (void **)&LHEventKitFetchRemindersOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_personal_data_eventkit_inventory_empty);
    }
    return true;
}
