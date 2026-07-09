#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NSInteger (*LHThermalStateOriginal)(id self, SEL selector);

static LHThermalStateOriginal LHThermalStateOriginalImplementation;

static NSInteger LHThermalStateReplacement(id self, SEL selector) {
    if (LHThermalStateOriginalImplementation == 0) {
        return 0;
    }

    NSInteger state = LHThermalStateOriginalImplementation(self, selector);
    if (state <= 1) {
        return 0;
    }
    return state;
}

bool LHMitigation_power_thermal_state_processinfo_nominalized_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"NSProcessInfo");
    SEL selector = sel_registerName("thermalState");
    if (targetClass == Nil || selector == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_power_thermal_state_processinfo_nominalized);
    }

    if (!LHHookBackendHookMessage(backend, targetClass, selector, (void *)LHThermalStateReplacement, (void **)&LHThermalStateOriginalImplementation)) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_power_thermal_state_processinfo_nominalized);
    }
    return true;
}
