#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#import <CoreMotion/CoreMotion.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <math.h>
#include <string.h>

typedef NSNumber *(*LHPedometerNumberOriginal)(id self, SEL selector);

LH_POLICY_SEED(motion_pedometer_steps)
LH_POLICY_SEED(motion_pedometer_distance)
LH_POLICY_SEED(motion_pedometer_floors)
LH_POLICY_SEED(motion_pedometer_pace)

static LHPedometerNumberOriginal LHPedometerStepsOriginal;
static LHPedometerNumberOriginal LHPedometerDistanceOriginal;
static LHPedometerNumberOriginal LHPedometerFloorsAscendedOriginal;
static LHPedometerNumberOriginal LHPedometerFloorsDescendedOriginal;
static LHPedometerNumberOriginal LHPedometerCurrentPaceOriginal;
static LHPedometerNumberOriginal LHPedometerCurrentCadenceOriginal;
static LHPedometerNumberOriginal LHPedometerAverageActivePaceOriginal;
static LHPolicyEngine *LHPedometerPolicy;

static double LHPedometerPhase(const LHPolicySeed *policySeed, const char *context, double step) {
    uint64_t bucket = 0;
    if (LHPedometerPolicy == 0 ||
        context == 0 ||
        !LHMitigationDeriveBoundedU64(&LHPedometerPolicy->config.buildSeed,
                                      policySeed,
                                      &LHPedometerPolicy->appContext.scope,
                                      (const uint8_t *)context,
                                      strlen(context),
                                      4,
                                      &bucket)) {
        return 0.0;
    }
    return ((double)bucket * step) / 4.0;
}

static NSNumber *LHPedometerQuantizedNumber(NSNumber *original,
                                            const LHPolicySeed *policySeed,
                                            const char *context,
                                            double step,
                                            bool integral) {
    if (original == nil || !(step > 0.0)) {
        return original;
    }
    double value = [original doubleValue];
    if (!(value >= 0.0)) {
        return original;
    }
    double phase = LHPedometerPhase(policySeed, context, step);
    double rounded = nearbyint((value - phase) / step) * step + phase;
    if (rounded < 0.0) {
        rounded = 0.0;
    }
    if (integral) {
        return @((long long)llround(rounded));
    }
    return @(rounded);
}

static NSNumber *LHPedometerStepsReplacement(id self, SEL selector) {
    if (LHPedometerStepsOriginal == 0) {
        return nil;
    }
    return LHPedometerQuantizedNumber(LHPedometerStepsOriginal(self, selector),
                                      &LHGeneratedPolicySeed_motion_pedometer_steps,
                                      "steps",
                                      250.0,
                                      true);
}

static NSNumber *LHPedometerDistanceReplacement(id self, SEL selector) {
    if (LHPedometerDistanceOriginal == 0) {
        return nil;
    }
    return LHPedometerQuantizedNumber(LHPedometerDistanceOriginal(self, selector),
                                      &LHGeneratedPolicySeed_motion_pedometer_distance,
                                      "distance",
                                      100.0,
                                      false);
}

static NSNumber *LHPedometerFloorsAscendedReplacement(id self, SEL selector) {
    if (LHPedometerFloorsAscendedOriginal == 0) {
        return nil;
    }
    return LHPedometerQuantizedNumber(LHPedometerFloorsAscendedOriginal(self, selector),
                                      &LHGeneratedPolicySeed_motion_pedometer_floors,
                                      "up",
                                      5.0,
                                      true);
}

static NSNumber *LHPedometerFloorsDescendedReplacement(id self, SEL selector) {
    if (LHPedometerFloorsDescendedOriginal == 0) {
        return nil;
    }
    return LHPedometerQuantizedNumber(LHPedometerFloorsDescendedOriginal(self, selector),
                                      &LHGeneratedPolicySeed_motion_pedometer_floors,
                                      "down",
                                      5.0,
                                      true);
}

static NSNumber *LHPedometerCurrentPaceReplacement(id self, SEL selector) {
    if (LHPedometerCurrentPaceOriginal == 0) {
        return nil;
    }
    return LHPedometerQuantizedNumber(LHPedometerCurrentPaceOriginal(self, selector),
                                      &LHGeneratedPolicySeed_motion_pedometer_pace,
                                      "pace",
                                      0.25,
                                      false);
}

static NSNumber *LHPedometerCurrentCadenceReplacement(id self, SEL selector) {
    if (LHPedometerCurrentCadenceOriginal == 0) {
        return nil;
    }
    return LHPedometerQuantizedNumber(LHPedometerCurrentCadenceOriginal(self, selector),
                                      &LHGeneratedPolicySeed_motion_pedometer_pace,
                                      "cadence",
                                      0.1,
                                      false);
}

static NSNumber *LHPedometerAverageActivePaceReplacement(id self, SEL selector) {
    if (LHPedometerAverageActivePaceOriginal == 0) {
        return nil;
    }
    return LHPedometerQuantizedNumber(LHPedometerAverageActivePaceOriginal(self, selector),
                                      &LHGeneratedPolicySeed_motion_pedometer_pace,
                                      "average",
                                      0.25,
                                      false);
}

static bool LHPedometerHookMessage(LHHookBackend *backend,
                                   const char *selectorName,
                                   void *replacement,
                                   void **original) {
    Class targetClass = NSClassFromString(@"CMPedometerData");
    SEL selector = sel_registerName(selectorName);
    if (targetClass == Nil || selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original);
}

bool LHMitigation_sensors_pedometer_coremotion_quantized_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHPedometerPolicy = policy;
    bool installed = false;

    installed = LHPedometerHookMessage(backend, "numberOfSteps", (void *)LHPedometerStepsReplacement, (void **)&LHPedometerStepsOriginal) || installed;
    installed = LHPedometerHookMessage(backend, "distance", (void *)LHPedometerDistanceReplacement, (void **)&LHPedometerDistanceOriginal) || installed;
    installed = LHPedometerHookMessage(backend, "floorsAscended", (void *)LHPedometerFloorsAscendedReplacement, (void **)&LHPedometerFloorsAscendedOriginal) || installed;
    installed = LHPedometerHookMessage(backend, "floorsDescended", (void *)LHPedometerFloorsDescendedReplacement, (void **)&LHPedometerFloorsDescendedOriginal) || installed;
    installed = LHPedometerHookMessage(backend, "currentPace", (void *)LHPedometerCurrentPaceReplacement, (void **)&LHPedometerCurrentPaceOriginal) || installed;
    installed = LHPedometerHookMessage(backend, "currentCadence", (void *)LHPedometerCurrentCadenceReplacement, (void **)&LHPedometerCurrentCadenceOriginal) || installed;
    installed = LHPedometerHookMessage(backend, "averageActivePace", (void *)LHPedometerAverageActivePaceReplacement, (void **)&LHPedometerAverageActivePaceOriginal) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_sensors_pedometer_coremotion_quantized);
    }
    return true;
}
