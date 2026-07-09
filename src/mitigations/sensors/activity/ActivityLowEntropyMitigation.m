#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#import <CoreMotion/CoreMotion.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef BOOL (*LHActivityBoolOriginal)(id self, SEL selector);
typedef CMMotionActivityConfidence (*LHActivityConfidenceOriginal)(id self, SEL selector);

LH_POLICY_SEED(motion_activity_profile)

static LHActivityBoolOriginal LHActivityUnknownOriginal;
static LHActivityBoolOriginal LHActivityStationaryOriginal;
static LHActivityBoolOriginal LHActivityWalkingOriginal;
static LHActivityBoolOriginal LHActivityRunningOriginal;
static LHActivityBoolOriginal LHActivityAutomotiveOriginal;
static LHActivityBoolOriginal LHActivityCyclingOriginal;
static LHActivityConfidenceOriginal LHActivityConfidenceOriginalImplementation;
static LHPolicyEngine *LHActivityPolicy;

static bool LHActivityUseUnknownProfile(void) {
    uint64_t value = 0;
    if (LHActivityPolicy == 0 ||
        !LHMitigationDeriveBoundedU64(&LHActivityPolicy->config.buildSeed,
                                      &LHGeneratedPolicySeed_motion_activity_profile,
                                      &LHActivityPolicy->appContext.scope,
                                      0,
                                      0,
                                      10,
                                      &value)) {
        return false;
    }
    return value == 0;
}

static BOOL LHActivityUnknownReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return LHActivityUseUnknownProfile() ? YES : NO;
}

static BOOL LHActivityStationaryReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return LHActivityUseUnknownProfile() ? NO : YES;
}

static BOOL LHActivityFalseReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return NO;
}

static CMMotionActivityConfidence LHActivityConfidenceReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return CMMotionActivityConfidenceLow;
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

bool LHMitigation_sensors_activity_coremotion_low_entropy_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHActivityPolicy = policy;
    bool installed = false;

    installed = LHActivityHookMessage(backend, "unknown", (void *)LHActivityUnknownReplacement, (void **)&LHActivityUnknownOriginal) || installed;
    installed = LHActivityHookMessage(backend, "stationary", (void *)LHActivityStationaryReplacement, (void **)&LHActivityStationaryOriginal) || installed;
    installed = LHActivityHookMessage(backend, "walking", (void *)LHActivityFalseReplacement, (void **)&LHActivityWalkingOriginal) || installed;
    installed = LHActivityHookMessage(backend, "running", (void *)LHActivityFalseReplacement, (void **)&LHActivityRunningOriginal) || installed;
    installed = LHActivityHookMessage(backend, "automotive", (void *)LHActivityFalseReplacement, (void **)&LHActivityAutomotiveOriginal) || installed;
    installed = LHActivityHookMessage(backend, "cycling", (void *)LHActivityFalseReplacement, (void **)&LHActivityCyclingOriginal) || installed;
    installed = LHActivityHookMessage(backend, "confidence", (void *)LHActivityConfidenceReplacement, (void **)&LHActivityConfidenceOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_sensors_activity_coremotion_low_entropy);
    }
    return true;
}
