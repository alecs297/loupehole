#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Contacts/Contacts.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef CNAuthorizationStatus (*LHContactsAuthorizationStatusOriginal)(id self, SEL selector, CNEntityType entityType);
typedef void (*LHContactsRequestAccessOriginal)(CNContactStore *self, SEL selector, CNEntityType entityType, void (^completion)(BOOL granted, NSError *error));
typedef NSArray<CNContainer *> *(*LHContactsContainersOriginal)(CNContactStore *self, SEL selector, NSPredicate *predicate, NSError **error);
typedef BOOL (*LHContactsEnumerateOriginal)(CNContactStore *self, SEL selector, CNContactFetchRequest *fetchRequest, NSError **error, void (^block)(CNContact *contact, BOOL *stop));
typedef NSArray<CNContact *> *(*LHContactsUnifiedContactsOriginal)(CNContactStore *self, SEL selector, NSPredicate *predicate, NSArray<id<CNKeyDescriptor>> *keys, NSError **error);
typedef CNContact *(*LHContactsUnifiedContactOriginal)(CNContactStore *self, SEL selector, NSString *identifier, NSArray<id<CNKeyDescriptor>> *keys, NSError **error);

static LHContactsAuthorizationStatusOriginal LHContactsAuthorizationStatusOriginalImplementation;
static LHContactsRequestAccessOriginal LHContactsRequestAccessOriginalImplementation;
static LHContactsContainersOriginal LHContactsContainersOriginalImplementation;
static LHContactsEnumerateOriginal LHContactsEnumerateOriginalImplementation;
static LHContactsUnifiedContactsOriginal LHContactsUnifiedContactsOriginalImplementation;
static LHContactsUnifiedContactOriginal LHContactsUnifiedContactOriginalImplementation;

/** Replacement for `+[CNContactStore authorizationStatusForEntityType:]`. */
static CNAuthorizationStatus LHContactsAuthorizationStatusReplacement(id self, SEL selector, CNEntityType entityType) {
    if (entityType == CNEntityTypeContacts) {
        return CNAuthorizationStatusDenied;
    }

    if (LHContactsAuthorizationStatusOriginalImplementation != 0) {
        return LHContactsAuthorizationStatusOriginalImplementation(self, selector, entityType);
    }
    return CNAuthorizationStatusNotDetermined;
}

/** Replacement for `-[CNContactStore requestAccessForEntityType:completionHandler:]`. */
static void LHContactsRequestAccessReplacement(CNContactStore *self, SEL selector, CNEntityType entityType, void (^completion)(BOOL granted, NSError *error)) {
    if (entityType == CNEntityTypeContacts) {
        if (completion != nil) {
            completion(NO, nil);
        }
        return;
    }

    if (LHContactsRequestAccessOriginalImplementation != 0) {
        LHContactsRequestAccessOriginalImplementation(self, selector, entityType, completion);
    } else if (completion != nil) {
        completion(NO, nil);
    }
}

/** Replacement for `-[CNContactStore containersMatchingPredicate:error:]`. */
static NSArray<CNContainer *> *LHContactsContainersReplacement(CNContactStore *self, SEL selector, NSPredicate *predicate, NSError **error) {
    (void)self;
    (void)selector;
    (void)predicate;
    (void)error;
    return @[];
}

/** Replacement for `-[CNContactStore enumerateContactsWithFetchRequest:error:usingBlock:]`. */
static BOOL LHContactsEnumerateReplacement(CNContactStore *self, SEL selector, CNContactFetchRequest *fetchRequest, NSError **error, void (^block)(CNContact *contact, BOOL *stop)) {
    (void)self;
    (void)selector;
    (void)fetchRequest;
    (void)error;
    (void)block;
    return YES;
}

/** Replacement for `-[CNContactStore unifiedContactsMatchingPredicate:keysToFetch:error:]`. */
static NSArray<CNContact *> *LHContactsUnifiedContactsReplacement(CNContactStore *self, SEL selector, NSPredicate *predicate, NSArray<id<CNKeyDescriptor>> *keys, NSError **error) {
    (void)self;
    (void)selector;
    (void)predicate;
    (void)keys;
    (void)error;
    return @[];
}

/** Replacement for `-[CNContactStore unifiedContactWithIdentifier:keysToFetch:error:]`. */
static CNContact *LHContactsUnifiedContactReplacement(CNContactStore *self, SEL selector, NSString *identifier, NSArray<id<CNKeyDescriptor>> *keys, NSError **error) {
    (void)self;
    (void)selector;
    (void)identifier;
    (void)keys;
    (void)error;
    return nil;
}

/** Hooks one Contacts selector and records whether it installed. */
static bool LHContactsHookMessage(LHHookBackend *backend, Class targetClass, const char *selectorName, void *replacement, void **original) {
    SEL selector = sel_registerName(selectorName);
    if (selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original);
}

/** Installs Contacts permission and inventory hooks. */
bool LHMitigation_contacts_permissioned_inventory_empty_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class storeClass = NSClassFromString(@"CNContactStore");
    if (storeClass == Nil) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_contacts_permissioned_inventory_empty);
    }

    bool installed = false;
    Class metaClass = object_getClass(storeClass);
    installed = LHContactsHookMessage(backend,
                                      metaClass,
                                      "authorizationStatusForEntityType:",
                                      (void *)LHContactsAuthorizationStatusReplacement,
                                      (void **)&LHContactsAuthorizationStatusOriginalImplementation) || installed;
    installed = LHContactsHookMessage(backend,
                                      storeClass,
                                      "requestAccessForEntityType:completionHandler:",
                                      (void *)LHContactsRequestAccessReplacement,
                                      (void **)&LHContactsRequestAccessOriginalImplementation) || installed;
    installed = LHContactsHookMessage(backend,
                                      storeClass,
                                      "containersMatchingPredicate:error:",
                                      (void *)LHContactsContainersReplacement,
                                      (void **)&LHContactsContainersOriginalImplementation) || installed;
    installed = LHContactsHookMessage(backend,
                                      storeClass,
                                      "enumerateContactsWithFetchRequest:error:usingBlock:",
                                      (void *)LHContactsEnumerateReplacement,
                                      (void **)&LHContactsEnumerateOriginalImplementation) || installed;
    installed = LHContactsHookMessage(backend,
                                      storeClass,
                                      "unifiedContactsMatchingPredicate:keysToFetch:error:",
                                      (void *)LHContactsUnifiedContactsReplacement,
                                      (void **)&LHContactsUnifiedContactsOriginalImplementation) || installed;
    installed = LHContactsHookMessage(backend,
                                      storeClass,
                                      "unifiedContactWithIdentifier:keysToFetch:error:",
                                      (void *)LHContactsUnifiedContactReplacement,
                                      (void **)&LHContactsUnifiedContactOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_contacts_permissioned_inventory_empty);
    }
    return true;
}
