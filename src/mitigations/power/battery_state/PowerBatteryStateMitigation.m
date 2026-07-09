#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <math.h>

typedef float (*LHBatteryLevelOriginal)(id self, SEL selector);
typedef NSInteger (*LHBatteryStateOriginal)(id self, SEL selector);

static LHBatteryLevelOriginal LHBatteryLevelOriginalImplementation;
static LHBatteryStateOriginal LHBatteryStateOriginalImplementation;
static LHPolicyEngine *LHBatteryPolicy;

LH_POLICY_SEED(battery_level_curve)

static bool LHBatteryCurveParameters(double *primaryAmplitude,
                                     double *secondaryAmplitude,
                                     double *primaryDirection,
                                     double *secondaryDirection) {
    if (LHBatteryPolicy == 0 ||
        primaryAmplitude == 0 ||
        secondaryAmplitude == 0 ||
        primaryDirection == 0 ||
        secondaryDirection == 0) {
        return false;
    }

    uint64_t profile = 0;
    if (!LHMitigationDeriveBoundedU64(&LHBatteryPolicy->config.buildSeed,
                                      &LHGeneratedPolicySeed_battery_level_curve,
                                      &LHBatteryPolicy->appContext.scope,
                                      0,
                                      0,
                                      48,
                                      &profile)) {
        return false;
    }

    *primaryAmplitude = 0.04 + (0.01 * (double)(profile % 3));
    *secondaryAmplitude = 0.01 * (double)((profile / 3) % 3);
    *primaryDirection = ((profile / 9) % 2) == 0 ? 1.0 : -1.0;
    *secondaryDirection = ((profile / 18) % 2) == 0 ? 1.0 : -1.0;
    return true;
}

static float LHBatteryCurvedLevel(float level) {
    double primaryAmplitude = 0.0;
    double secondaryAmplitude = 0.0;
    double primaryDirection = 1.0;
    double secondaryDirection = 1.0;
    if (!LHBatteryCurveParameters(&primaryAmplitude, &secondaryAmplitude, &primaryDirection, &secondaryDirection)) {
        return level;
    }

    static const double pi = 3.14159265358979323846;
    double x = (double)level;
    double curved = x +
                    (primaryDirection * primaryAmplitude * sin(pi * x)) +
                    (secondaryDirection * secondaryAmplitude * sin(2.0 * pi * x));
    if (curved < 0.0) {
        curved = 0.0;
    } else if (curved > 1.0) {
        curved = 1.0;
    }

    double rounded = round(curved * 100.0) / 100.0;
    if (level > 0.0f && level < 1.0f) {
        if (rounded <= 0.0) {
            rounded = 0.01;
        } else if (rounded >= 1.0) {
            rounded = 0.99;
        }
    }
    return (float)rounded;
}

static float LHBatteryLevelReplacement(id self, SEL selector) {
    if (LHBatteryLevelOriginalImplementation == 0) {
        return -1.0f;
    }

    float level = LHBatteryLevelOriginalImplementation(self, selector);
    if (!isfinite(level) || level < 0.0f || level > 1.0f) {
        return level;
    }
    return LHBatteryCurvedLevel(level);
}

static NSInteger LHBatteryStateReplacement(id self, SEL selector) {
    if (LHBatteryStateOriginalImplementation != 0) {
        return LHBatteryStateOriginalImplementation(self, selector);
    }
    return 0;
}

bool LHMitigation_power_battery_uidevice_curved_level_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHBatteryPolicy = policy;

    Class targetClass = NSClassFromString(@"UIDevice");
    if (targetClass == Nil) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_power_battery_uidevice_curved_level);
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
        return LHHookBackendRegisterNoOp(backend, LHModuleID_power_battery_uidevice_curved_level);
    }
    return true;
}
