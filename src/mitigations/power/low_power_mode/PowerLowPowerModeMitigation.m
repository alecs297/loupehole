#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef BOOL (*LHLowPowerModeOriginal)(id self, SEL selector);

static LHLowPowerModeOriginal LHLowPowerModeOriginalImplementation;

static BOOL LHLowPowerModeReplacement(id self, SEL selector) {
    if (LHLowPowerModeOriginalImplementation != 0) {
        (void)LHLowPowerModeOriginalImplementation(self, selector);
    }
    return NO;
}

bool LHMitigation_power_low_power_mode_processinfo_normalized_false_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"NSProcessInfo");
    SEL selector = sel_registerName("isLowPowerModeEnabled");
    if (targetClass == Nil || selector == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_power_low_power_mode_processinfo_normalized_false);
    }

    if (!LHHookBackendHookMessage(backend, targetClass, selector, (void *)LHLowPowerModeReplacement, (void **)&LHLowPowerModeOriginalImplementation)) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_power_low_power_mode_processinfo_normalized_false);
    }
    return true;
}
