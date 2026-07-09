#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"
#include "LHValueQuantizer.h"

#import <CoreMotion/CoreMotion.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <string.h>

typedef NSNumber *(*LHAltitudeNumberOriginal)(id self, SEL selector);
typedef double (*LHAbsoluteAltitudeDoubleOriginal)(id self, SEL selector);

LH_POLICY_SEED(motion_altimeter_pressure)
LH_POLICY_SEED(motion_altimeter_altitude)

static LHAltitudeNumberOriginal LHRelativeAltitudeOriginal;
static LHAltitudeNumberOriginal LHPressureOriginal;
static LHAbsoluteAltitudeDoubleOriginal LHAbsoluteAltitudeOriginal;
static LHAbsoluteAltitudeDoubleOriginal LHAbsoluteAccuracyOriginal;
static LHAbsoluteAltitudeDoubleOriginal LHAbsolutePrecisionOriginal;
static LHPolicyEngine *LHAltimeterPolicy;

static double LHAltimeterShape(double value,
                               const LHPolicySeed *policySeed,
                               const char *context,
                               double amplitudeMax,
                               double wavelength) {
    double shaped = value;
    if (LHAltimeterPolicy != 0 &&
        context != 0 &&
        LHValueApplySeededSinePerturbation(&LHAltimeterPolicy->config.buildSeed,
                                           policySeed,
                                           &LHAltimeterPolicy->appContext.scope,
                                           (const uint8_t *)context,
                                           strlen(context),
                                           value,
                                           amplitudeMax,
                                           wavelength,
                                           &shaped)) {
        return shaped;
    }
    return value;
}

static NSNumber *LHRelativeAltitudeReplacement(id self, SEL selector) {
    if (LHRelativeAltitudeOriginal == 0) {
        return nil;
    }
    NSNumber *original = LHRelativeAltitudeOriginal(self, selector);
    if (original == nil) {
        return nil;
    }
    return @(LHAltimeterShape([original doubleValue], &LHGeneratedPolicySeed_motion_altimeter_altitude, "relative", 1.5, 20.0));
}

static NSNumber *LHPressureReplacement(id self, SEL selector) {
    if (LHPressureOriginal == 0) {
        return nil;
    }
    NSNumber *original = LHPressureOriginal(self, selector);
    if (original == nil) {
        return nil;
    }
    return @(LHAltimeterShape([original doubleValue], &LHGeneratedPolicySeed_motion_altimeter_pressure, "pressure", 0.15, 2.0));
}

static double LHAbsoluteAltitudeReplacement(id self, SEL selector) {
    if (LHAbsoluteAltitudeOriginal == 0) {
        return 0.0;
    }
    return LHAltimeterShape(LHAbsoluteAltitudeOriginal(self, selector), &LHGeneratedPolicySeed_motion_altimeter_altitude, "absolute", 8.0, 120.0);
}

static double LHAbsoluteAccuracyReplacement(id self, SEL selector) {
    if (LHAbsoluteAccuracyOriginal == 0) {
        return -1.0;
    }
    double original = LHAbsoluteAccuracyOriginal(self, selector);
    if (!(original >= 0.0)) {
        return original;
    }
    double shaped = LHAltimeterShape(original, &LHGeneratedPolicySeed_motion_altimeter_altitude, "accuracy", 8.0, 80.0);
    return shaped < 50.0 ? 50.0 : shaped;
}

static double LHAbsolutePrecisionReplacement(id self, SEL selector) {
    if (LHAbsolutePrecisionOriginal == 0) {
        return -1.0;
    }
    double original = LHAbsolutePrecisionOriginal(self, selector);
    if (!(original >= 0.0)) {
        return original;
    }
    double shaped = LHAltimeterShape(original, &LHGeneratedPolicySeed_motion_altimeter_altitude, "precision", 3.0, 40.0);
    return shaped < 10.0 ? 10.0 : shaped;
}

static bool LHAltimeterHookMessage(LHHookBackend *backend,
                                   NSString *className,
                                   const char *selectorName,
                                   void *replacement,
                                   void **original) {
    Class targetClass = NSClassFromString(className);
    SEL selector = sel_registerName(selectorName);
    if (targetClass == Nil || selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original);
}

bool LHMitigation_sensors_altimeter_coremotion_seeded_jitter_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHAltimeterPolicy = policy;
    bool installed = false;

    installed = LHAltimeterHookMessage(backend, @"CMAltitudeData", "relativeAltitude", (void *)LHRelativeAltitudeReplacement, (void **)&LHRelativeAltitudeOriginal) || installed;
    installed = LHAltimeterHookMessage(backend, @"CMAltitudeData", "pressure", (void *)LHPressureReplacement, (void **)&LHPressureOriginal) || installed;
    installed = LHAltimeterHookMessage(backend, @"CMAbsoluteAltitudeData", "altitude", (void *)LHAbsoluteAltitudeReplacement, (void **)&LHAbsoluteAltitudeOriginal) || installed;
    installed = LHAltimeterHookMessage(backend, @"CMAbsoluteAltitudeData", "accuracy", (void *)LHAbsoluteAccuracyReplacement, (void **)&LHAbsoluteAccuracyOriginal) || installed;
    installed = LHAltimeterHookMessage(backend, @"CMAbsoluteAltitudeData", "precision", (void *)LHAbsolutePrecisionReplacement, (void **)&LHAbsolutePrecisionOriginal) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_sensors_altimeter_coremotion_seeded_jitter);
    }
    return true;
}
