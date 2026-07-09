#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NSDictionary<NSString *, NSString *> *(*LHServiceRATOriginal)(id self, SEL selector);
typedef NSString *(*LHCurrentRATOriginal)(id self, SEL selector);

LH_POLICY_SEED(telephony_radio_service_identifier)

static LHServiceRATOriginal LHServiceRATOriginalImplementation;
static LHCurrentRATOriginal LHCurrentRATOriginalImplementation;
static LHPolicyEngine *LHTelephonyPolicy;

static NSString *LHTelephonySyntheticServiceIdentifier(void) {
    char identifier[17] = { 0 };
    if (LHTelephonyPolicy == 0 ||
        !LHMitigationDeriveASCIIString(&LHTelephonyPolicy->config.buildSeed,
                                       &LHGeneratedPolicySeed_telephony_radio_service_identifier,
                                       &LHTelephonyPolicy->appContext.scope,
                                       "0123456789abcdef",
                                       16,
                                       identifier,
                                       sizeof(identifier))) {
        return nil;
    }
    return [NSString stringWithUTF8String:identifier];
}

static NSDictionary<NSString *, NSString *> *LHTelephonyServiceRATReplacement(id self, SEL selector) {
    NSDictionary<NSString *, NSString *> *original = nil;
    if (LHServiceRATOriginalImplementation != 0) {
        original = LHServiceRATOriginalImplementation(self, selector);
    }

    if (original == nil || original.count == 0) {
        return original;
    }

    NSString *serviceIdentifier = LHTelephonySyntheticServiceIdentifier();
    if (serviceIdentifier == nil) {
        return original;
    }
    return @{ serviceIdentifier: CTRadioAccessTechnologyLTE };
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
    LHTelephonyPolicy = policy;
    bool installed = false;

    installed = LHTelephonyHookMessage(backend, "serviceCurrentRadioAccessTechnology", (void *)LHTelephonyServiceRATReplacement, (void **)&LHServiceRATOriginalImplementation) || installed;
    installed = LHTelephonyHookMessage(backend, "currentRadioAccessTechnology", (void *)LHTelephonyCurrentRATReplacement, (void **)&LHCurrentRATOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_telephony_radio_access_coretelephony_single_lte);
    }
    return true;
}
