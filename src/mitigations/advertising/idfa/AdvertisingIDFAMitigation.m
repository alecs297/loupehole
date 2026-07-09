#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NSUUID *(*LHAdvertisingIdentifierOriginal)(id self, SEL selector);
typedef BOOL (*LHAdvertisingTrackingEnabledOriginal)(id self, SEL selector);

static LHAdvertisingIdentifierOriginal LHAdvertisingIdentifierOriginalImplementation;
static LHAdvertisingTrackingEnabledOriginal LHAdvertisingTrackingEnabledOriginalImplementation;

static NSUUID *LHAdvertisingIdentifierZeroReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"];
}

static BOOL LHAdvertisingTrackingEnabledReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return NO;
}

static bool LHAdvertisingHookMessage(LHHookBackend *backend, Class targetClass, const char *selectorName, void *replacement, void **original) {
    SEL selector = sel_registerName(selectorName);
    if (targetClass == Nil || selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original);
}

bool LHMitigation_advertising_idfa_adsupport_zero_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class managerClass = NSClassFromString(@"ASIdentifierManager");
    bool installed = false;
    installed = LHAdvertisingHookMessage(backend,
                                         managerClass,
                                         "advertisingIdentifier",
                                         (void *)LHAdvertisingIdentifierZeroReplacement,
                                         (void **)&LHAdvertisingIdentifierOriginalImplementation) || installed;
    installed = LHAdvertisingHookMessage(backend,
                                         managerClass,
                                         "isAdvertisingTrackingEnabled",
                                         (void *)LHAdvertisingTrackingEnabledReplacement,
                                         (void **)&LHAdvertisingTrackingEnabledOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_advertising_idfa_adsupport_zero);
    }
    return true;
}
