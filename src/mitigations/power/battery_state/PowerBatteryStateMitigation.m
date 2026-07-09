#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <math.h>

typedef float (*LHBatteryLevelOriginal)(id self, SEL selector);
typedef NSInteger (*LHBatteryStateOriginal)(id self, SEL selector);

static LHBatteryLevelOriginal LHBatteryLevelOriginalImplementation;
static LHBatteryStateOriginal LHBatteryStateOriginalImplementation;

static float LHBatteryLevelReplacement(id self, SEL selector) {
    if (LHBatteryLevelOriginalImplementation == 0) {
        return -1.0f;
    }

    float level = LHBatteryLevelOriginalImplementation(self, selector);
    if (!isfinite(level) || level < 0.0f || level > 1.0f) {
        return level;
    }
    return roundf(level * 10.0f) / 10.0f;
}

static NSInteger LHBatteryStateReplacement(id self, SEL selector) {
    if (LHBatteryStateOriginalImplementation != 0) {
        return LHBatteryStateOriginalImplementation(self, selector);
    }
    return 0;
}

bool LHMitigation_power_battery_uidevice_bucketed_level_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"UIDevice");
    if (targetClass == Nil) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_power_battery_uidevice_bucketed_level);
    }

    bool installed = false;
    SEL levelSelector = sel_registerName("batteryLevel");
    SEL stateSelector = sel_registerName("batteryState");
    if (levelSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             targetClass,
                                             levelSelector,
                                             (void *)LHBatteryLevelReplacement,
                                             (void **)&LHBatteryLevelOriginalImplementation) || installed;
    }
    if (stateSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             targetClass,
                                             stateSelector,
                                             (void *)LHBatteryStateReplacement,
                                             (void **)&LHBatteryStateOriginalImplementation) || installed;
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_power_battery_uidevice_bucketed_level);
    }
    return true;
}
