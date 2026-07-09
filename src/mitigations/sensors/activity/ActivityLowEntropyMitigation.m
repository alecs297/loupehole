#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#import <CoreMotion/CoreMotion.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef BOOL (*LHActivityBoolOriginal)(id self, SEL selector);
typedef CMMotionActivityConfidence (*LHActivityConfidenceOriginal)(id self, SEL selector);

LH_POLICY_SEED(motion_activity_confidence)

static LHActivityBoolOriginal LHActivityUnknownOriginal;
static LHActivityBoolOriginal LHActivityStationaryOriginal;
static LHActivityBoolOriginal LHActivityWalkingOriginal;
static LHActivityBoolOriginal LHActivityRunningOriginal;
static LHActivityBoolOriginal LHActivityAutomotiveOriginal;
static LHActivityBoolOriginal LHActivityCyclingOriginal;
static LHActivityConfidenceOriginal LHActivityConfidenceOriginalImplementation;
static LHPolicyEngine *LHActivityPolicy;

static BOOL LHActivityBoolReplacement(id self, SEL selector, LHActivityBoolOriginal original) {
    if (original == 0) {
        return NO;
    }
    return original(self, selector);
}

static CMMotionActivityConfidence LHActivityShapeConfidence(CMMotionActivityConfidence original) {
    if (original <= CMMotionActivityConfidenceLow) {
        return CMMotionActivityConfidenceLow;
    }

    uint64_t value = 0;
    uint8_t context[] = {'c', (uint8_t)original};
    if (LHActivityPolicy != 0 &&
        !LHMitigationDeriveBoundedU64(&LHActivityPolicy->config.buildSeed,
                                      &LHGeneratedPolicySeed_motion_activity_confidence,
                                      &LHActivityPolicy->appContext.scope,
                                      context,
                                      sizeof(context),
                                      3,
                                      &value)) {
        value = 0;
    }

    if (original == CMMotionActivityConfidenceHigh) {
        return value == 0 ? CMMotionActivityConfidenceMedium : CMMotionActivityConfidenceLow;
    }
    return value == 0 ? CMMotionActivityConfidenceMedium : CMMotionActivityConfidenceLow;
}

static BOOL LHActivityUnknownReplacement(id self, SEL selector) {
    return LHActivityBoolReplacement(self, selector, LHActivityUnknownOriginal);
}

static BOOL LHActivityStationaryReplacement(id self, SEL selector) {
    return LHActivityBoolReplacement(self, selector, LHActivityStationaryOriginal);
}

static BOOL LHActivityWalkingReplacement(id self, SEL selector) {
    return LHActivityBoolReplacement(self, selector, LHActivityWalkingOriginal);
}

static BOOL LHActivityRunningReplacement(id self, SEL selector) {
    return LHActivityBoolReplacement(self, selector, LHActivityRunningOriginal);
}

static BOOL LHActivityAutomotiveReplacement(id self, SEL selector) {
    return LHActivityBoolReplacement(self, selector, LHActivityAutomotiveOriginal);
}

static BOOL LHActivityCyclingReplacement(id self, SEL selector) {
    return LHActivityBoolReplacement(self, selector, LHActivityCyclingOriginal);
}

static CMMotionActivityConfidence LHActivityConfidenceReplacement(id self, SEL selector) {
    if (LHActivityConfidenceOriginalImplementation == 0) {
        return CMMotionActivityConfidenceLow;
    }
    return LHActivityShapeConfidence(LHActivityConfidenceOriginalImplementation(self, selector));
}

static bool LHActivityHookMessage(LHHookBackend *backend,
                                  const char *selectorName,
                                  void *replacement,
                                  void **original) {
    Class targetClass = NSClassFromString(@"CMMotionActivity");
    SEL selector = sel_registerName(selectorName);
    if (targetClass == Nil || selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original);
}

bool LHMitigation_sensors_activity_coremotion_confidence_shaped_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHActivityPolicy = policy;
    bool installed = false;

    installed = LHActivityHookMessage(backend, "unknown", (void *)LHActivityUnknownReplacement, (void **)&LHActivityUnknownOriginal) || installed;
    installed = LHActivityHookMessage(backend, "stationary", (void *)LHActivityStationaryReplacement, (void **)&LHActivityStationaryOriginal) || installed;
    installed = LHActivityHookMessage(backend, "walking", (void *)LHActivityWalkingReplacement, (void **)&LHActivityWalkingOriginal) || installed;
    installed = LHActivityHookMessage(backend, "running", (void *)LHActivityRunningReplacement, (void **)&LHActivityRunningOriginal) || installed;
    installed = LHActivityHookMessage(backend, "automotive", (void *)LHActivityAutomotiveReplacement, (void **)&LHActivityAutomotiveOriginal) || installed;
    installed = LHActivityHookMessage(backend, "cycling", (void *)LHActivityCyclingReplacement, (void **)&LHActivityCyclingOriginal) || installed;
    installed = LHActivityHookMessage(backend, "confidence", (void *)LHActivityConfidenceReplacement, (void **)&LHActivityConfidenceOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_sensors_activity_coremotion_confidence_shaped);
    }
    return true;
}
