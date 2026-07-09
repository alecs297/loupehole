#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NSDictionary<NSString *, NSString *> *(*LHServiceRATOriginal)(id self, SEL selector);
typedef NSString *(*LHCurrentRATOriginal)(id self, SEL selector);

static LHServiceRATOriginal LHServiceRATOriginalImplementation;
static LHCurrentRATOriginal LHCurrentRATOriginalImplementation;

static NSDictionary<NSString *, NSString *> *LHTelephonyServiceRATReplacement(id self, SEL selector) {
    NSDictionary<NSString *, NSString *> *original = nil;
    if (LHServiceRATOriginalImplementation != 0) {
        original = LHServiceRATOriginalImplementation(self, selector);
    }

    if (original == nil || original.count == 0) {
        return original;
    }

    return @{ @"0000000000000000": CTRadioAccessTechnologyLTE };
}

static NSString *LHTelephonyCurrentRATReplacement(id self, SEL selector) {
    NSString *original = nil;
    if (LHCurrentRATOriginalImplementation != 0) {
        original = LHCurrentRATOriginalImplementation(self, selector);
    }
    return original == nil ? nil : CTRadioAccessTechnologyLTE;
}

static bool LHTelephonyHookMessage(LHHookBackend *backend,
                                   const char *selectorName,
                                   void *replacement,
                                   void **original) {
    Class targetClass = NSClassFromString(@"CTTelephonyNetworkInfo");
    SEL selector = sel_registerName(selectorName);
    if (targetClass == Nil || selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original);
}

bool LHMitigation_telephony_radio_access_coretelephony_single_lte_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;
    bool installed = false;

    installed = LHTelephonyHookMessage(backend, "serviceCurrentRadioAccessTechnology", (void *)LHTelephonyServiceRATReplacement, (void **)&LHServiceRATOriginalImplementation) || installed;
    installed = LHTelephonyHookMessage(backend, "currentRadioAccessTechnology", (void *)LHTelephonyCurrentRATReplacement, (void **)&LHCurrentRATOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_telephony_radio_access_coretelephony_single_lte);
    }
    return true;
}
