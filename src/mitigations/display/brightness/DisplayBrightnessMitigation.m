#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <math.h>

typedef double (*LHDisplayBrightnessOriginal)(id self, SEL selector);

static LHDisplayBrightnessOriginal LHDisplayBrightnessOriginalImplementation;

static double LHDisplayBrightnessReplacement(id self, SEL selector) {
    if (LHDisplayBrightnessOriginalImplementation == 0) {
        return 0.0;
    }

    double brightness = LHDisplayBrightnessOriginalImplementation(self, selector);
    if (!isfinite(brightness) || brightness < 0.0 || brightness > 1.0) {
        return brightness;
    }
    return round(brightness * 10.0) / 10.0;
}

bool LHMitigation_display_brightness_uiscreen_bucketed_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"UIScreen");
    SEL selector = sel_registerName("brightness");
    if (targetClass == Nil || selector == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_display_brightness_uiscreen_bucketed);
    }

    if (!LHHookBackendHookMessage(backend, targetClass, selector, (void *)LHDisplayBrightnessReplacement, (void **)&LHDisplayBrightnessOriginalImplementation)) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_display_brightness_uiscreen_bucketed);
    }
    return true;
}
