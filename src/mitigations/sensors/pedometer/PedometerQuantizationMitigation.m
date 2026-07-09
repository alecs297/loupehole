#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"
#include "LHValueQuantizer.h"

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

static NSNumber *LHPedometerShapedNumber(NSNumber *original,
                                         const LHPolicySeed *policySeed,
                                         const char *context,
                                         double amplitudeMax,
                                         double wavelength,
                                         bool integral) {
    if (original == nil || !(amplitudeMax >= 0.0) || !(wavelength > 0.0)) {
        return original;
    }
    double value = [original doubleValue];
    if (!(value >= 0.0)) {
        return original;
    }
    double shaped = value;
    if (LHPedometerPolicy != 0 &&
        context != 0 &&
        LHValueApplySeededSinePerturbation(&LHPedometerPolicy->config.buildSeed,
                                           policySeed,
                                           &LHPedometerPolicy->appContext.scope,
                                           (const uint8_t *)context,
                                           strlen(context),
                                           value,
                                           amplitudeMax,
                                           wavelength,
                                           &shaped) &&
        shaped < 0.0) {
        shaped = 0.0;
    }
    if (integral) {
        return @((long long)llround(shaped));
    }
    return @(shaped);
}

static NSNumber *LHPedometerStepsReplacement(id self, SEL selector) {
    if (LHPedometerStepsOriginal == 0) {
        return nil;
    }
    return LHPedometerShapedNumber(LHPedometerStepsOriginal(self, selector),
                                   &LHGeneratedPolicySeed_motion_pedometer_steps,
                                   "steps",
                                   75.0,
                                   1000.0,
                                   true);
}

static NSNumber *LHPedometerDistanceReplacement(id self, SEL selector) {
    if (LHPedometerDistanceOriginal == 0) {
        return nil;
    }
    return LHPedometerShapedNumber(LHPedometerDistanceOriginal(self, selector),
                                   &LHGeneratedPolicySeed_motion_pedometer_distance,
                                   "distance",
                                   30.0,
                                   400.0,
                                   false);
}

static NSNumber *LHPedometerFloorsAscendedReplacement(id self, SEL selector) {
    if (LHPedometerFloorsAscendedOriginal == 0) {
        return nil;
    }
    return LHPedometerShapedNumber(LHPedometerFloorsAscendedOriginal(self, selector),
                                   &LHGeneratedPolicySeed_motion_pedometer_floors,
                                   "up",
                                   0.5,
                                   6.0,
                                   true);
}

static NSNumber *LHPedometerFloorsDescendedReplacement(id self, SEL selector) {
    if (LHPedometerFloorsDescendedOriginal == 0) {
        return nil;
    }
    return LHPedometerShapedNumber(LHPedometerFloorsDescendedOriginal(self, selector),
                                   &LHGeneratedPolicySeed_motion_pedometer_floors,
                                   "down",
                                   0.5,
                                   6.0,
                                   true);
}

static NSNumber *LHPedometerCurrentPaceReplacement(id self, SEL selector) {
    if (LHPedometerCurrentPaceOriginal == 0) {
        return nil;
    }
    return LHPedometerShapedNumber(LHPedometerCurrentPaceOriginal(self, selector),
                                   &LHGeneratedPolicySeed_motion_pedometer_pace,
                                   "pace",
                                   0.05,
                                   0.75,
                                   false);
}

static NSNumber *LHPedometerCurrentCadenceReplacement(id self, SEL selector) {
    if (LHPedometerCurrentCadenceOriginal == 0) {
        return nil;
    }
    return LHPedometerShapedNumber(LHPedometerCurrentCadenceOriginal(self, selector),
                                   &LHGeneratedPolicySeed_motion_pedometer_pace,
                                   "cadence",
                                   0.025,
                                   0.3,
                                   false);
}

static NSNumber *LHPedometerAverageActivePaceReplacement(id self, SEL selector) {
    if (LHPedometerAverageActivePaceOriginal == 0) {
        return nil;
    }
    return LHPedometerShapedNumber(LHPedometerAverageActivePaceOriginal(self, selector),
                                   &LHGeneratedPolicySeed_motion_pedometer_pace,
                                   "average",
                                   0.05,
                                   0.75,
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

bool LHMitigation_sensors_pedometer_coremotion_seeded_jitter_install(LHHookBackend *backend, LHPolicyEngine *policy) {
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
        return LHHookBackendRegisterNoOp(backend, LHModuleID_sensors_pedometer_coremotion_seeded_jitter);
    }
    return true;
}
