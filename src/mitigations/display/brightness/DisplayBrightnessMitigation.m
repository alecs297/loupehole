#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHValueQuantizer.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <math.h>

typedef double (*LHDisplayBrightnessOriginal)(id self, SEL selector);

static LHDisplayBrightnessOriginal LHDisplayBrightnessOriginalImplementation;
static LHPolicyEngine *LHDisplayBrightnessPolicy;

LH_POLICY_SEED(display_brightness_curve)

static double LHDisplayBrightnessReplacement(id self, SEL selector) {
    if (LHDisplayBrightnessOriginalImplementation == 0) {
        return 0.0;
    }

    double brightness = LHDisplayBrightnessOriginalImplementation(self, selector);
    if (!isfinite(brightness) || brightness < 0.0 || brightness > 1.0) {
        return brightness;
    }
    double shaped = brightness;
    if (LHDisplayBrightnessPolicy != 0 &&
        LHValueMapUnitIntervalCurve(&LHDisplayBrightnessPolicy->config.buildSeed,
                                    &LHGeneratedPolicySeed_display_brightness_curve,
                                    &LHDisplayBrightnessPolicy->appContext.scope,
                                    (const uint8_t *)"brightness",
                                    sizeof("brightness") - 1,
                                    brightness,
                                    0.045,
                                    0.015,
                                    &shaped)) {
        return shaped;
    }
    return brightness;
}

bool LHMitigation_display_brightness_uiscreen_curved_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHDisplayBrightnessPolicy = policy;

    Class targetClass = NSClassFromString(@"UIScreen");
    SEL selector = sel_registerName("brightness");
    if (targetClass == Nil || selector == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_display_brightness_uiscreen_curved);
    }

    if (!LHHookBackendHookMessage(backend, targetClass, selector, (void *)LHDisplayBrightnessReplacement, (void **)&LHDisplayBrightnessOriginalImplementation)) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_display_brightness_uiscreen_curved);
    }
    return true;
}
