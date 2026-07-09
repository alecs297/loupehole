#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#import <CoreMotion/CoreMotion.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <math.h>
#include <stdio.h>
#include <string.h>

typedef CMAcceleration (*LHAccelerationOriginal)(id self, SEL selector);
typedef CMRotationRate (*LHRotationRateOriginal)(id self, SEL selector);
typedef CMMagneticField (*LHMagneticFieldOriginal)(id self, SEL selector);
typedef CMCalibratedMagneticField (*LHCalibratedMagneticFieldOriginal)(id self, SEL selector);
typedef double (*LHMotionDoubleOriginal)(id self, SEL selector);

LH_POLICY_SEED(device_motion_acceleration)
LH_POLICY_SEED(device_motion_rotation_rate)
LH_POLICY_SEED(device_motion_magnetic_field)
LH_POLICY_SEED(device_motion_attitude)
LH_POLICY_SEED(device_motion_heading)

static LHAccelerationOriginal LHAccelerometerAccelerationOriginal;
static LHRotationRateOriginal LHGyroRotationRateOriginal;
static LHMagneticFieldOriginal LHMagnetometerFieldOriginal;
static LHAccelerationOriginal LHDeviceMotionGravityOriginal;
static LHAccelerationOriginal LHDeviceMotionUserAccelerationOriginal;
static LHRotationRateOriginal LHDeviceMotionRotationRateOriginal;
static LHCalibratedMagneticFieldOriginal LHDeviceMotionMagneticFieldOriginal;
static LHMotionDoubleOriginal LHCMAttitudeRollOriginal;
static LHMotionDoubleOriginal LHCMAttitudePitchOriginal;
static LHMotionDoubleOriginal LHCMAttitudeYawOriginal;
static LHMotionDoubleOriginal LHDeviceMotionHeadingOriginal;
static LHPolicyEngine *LHDeviceMotionPolicy;

static double LHDeviceMotionRound(double value, double step, double phase) {
    if (!(step > 0.0)) {
        return value;
    }
    double shifted = (value - phase) / step;
    double rounded = nearbyint(shifted) * step + phase;
    if (rounded == -0.0) {
        return 0.0;
    }
    return rounded;
}

static double LHDeviceMotionPhase(const LHPolicySeed *policySeed, const char *context, double step) {
    uint64_t bucket = 0;
    if (LHDeviceMotionPolicy == 0 ||
        context == 0 ||
        !LHMitigationDeriveBoundedU64(&LHDeviceMotionPolicy->config.buildSeed,
                                      policySeed,
                                      &LHDeviceMotionPolicy->appContext.scope,
                                      (const uint8_t *)context,
                                      strlen(context),
                                      4,
                                      &bucket)) {
        return 0.0;
    }
    return ((double)bucket * step) / 4.0;
}

static CMAcceleration LHDeviceMotionQuantizeAcceleration(CMAcceleration value,
                                                         const LHPolicySeed *policySeed,
                                                         const char *prefix,
                                                         double step) {
    char context[8] = { 0 };
    snprintf(context, sizeof(context), "%sx", prefix);
    value.x = LHDeviceMotionRound(value.x, step, LHDeviceMotionPhase(policySeed, context, step));
    snprintf(context, sizeof(context), "%sy", prefix);
    value.y = LHDeviceMotionRound(value.y, step, LHDeviceMotionPhase(policySeed, context, step));
    snprintf(context, sizeof(context), "%sz", prefix);
    value.z = LHDeviceMotionRound(value.z, step, LHDeviceMotionPhase(policySeed, context, step));
    return value;
}

static CMRotationRate LHDeviceMotionQuantizeRotationRate(CMRotationRate value,
                                                         const LHPolicySeed *policySeed,
                                                         const char *prefix,
                                                         double step) {
    char context[8] = { 0 };
    snprintf(context, sizeof(context), "%sx", prefix);
    value.x = LHDeviceMotionRound(value.x, step, LHDeviceMotionPhase(policySeed, context, step));
    snprintf(context, sizeof(context), "%sy", prefix);
    value.y = LHDeviceMotionRound(value.y, step, LHDeviceMotionPhase(policySeed, context, step));
    snprintf(context, sizeof(context), "%sz", prefix);
    value.z = LHDeviceMotionRound(value.z, step, LHDeviceMotionPhase(policySeed, context, step));
    return value;
}

static CMMagneticField LHDeviceMotionQuantizeMagneticField(CMMagneticField value,
                                                           const LHPolicySeed *policySeed,
                                                           const char *prefix,
                                                           double step) {
    char context[8] = { 0 };
    snprintf(context, sizeof(context), "%sx", prefix);
    value.x = LHDeviceMotionRound(value.x, step, LHDeviceMotionPhase(policySeed, context, step));
    snprintf(context, sizeof(context), "%sy", prefix);
    value.y = LHDeviceMotionRound(value.y, step, LHDeviceMotionPhase(policySeed, context, step));
    snprintf(context, sizeof(context), "%sz", prefix);
    value.z = LHDeviceMotionRound(value.z, step, LHDeviceMotionPhase(policySeed, context, step));
    return value;
}

static CMAcceleration LHAccelerometerAccelerationReplacement(id self, SEL selector) {
    CMAcceleration value = { 0 };
    if (LHAccelerometerAccelerationOriginal != 0) {
        value = LHAccelerometerAccelerationOriginal(self, selector);
        return LHDeviceMotionQuantizeAcceleration(value, &LHGeneratedPolicySeed_device_motion_acceleration, "ra", 0.05);
    }
    return value;
}

static CMRotationRate LHGyroRotationRateReplacement(id self, SEL selector) {
    CMRotationRate value = { 0 };
    if (LHGyroRotationRateOriginal != 0) {
        value = LHGyroRotationRateOriginal(self, selector);
        return LHDeviceMotionQuantizeRotationRate(value, &LHGeneratedPolicySeed_device_motion_rotation_rate, "rg", 0.05);
    }
    return value;
}

static CMMagneticField LHMagnetometerFieldReplacement(id self, SEL selector) {
    CMMagneticField value = { 0 };
    if (LHMagnetometerFieldOriginal != 0) {
        value = LHMagnetometerFieldOriginal(self, selector);
        return LHDeviceMotionQuantizeMagneticField(value, &LHGeneratedPolicySeed_device_motion_magnetic_field, "rm", 5.0);
    }
    return value;
}

static CMAcceleration LHDeviceMotionGravityReplacement(id self, SEL selector) {
    CMAcceleration value = { 0 };
    if (LHDeviceMotionGravityOriginal != 0) {
        value = LHDeviceMotionGravityOriginal(self, selector);
        return LHDeviceMotionQuantizeAcceleration(value, &LHGeneratedPolicySeed_device_motion_acceleration, "fg", 0.05);
    }
    return value;
}

static CMAcceleration LHDeviceMotionUserAccelerationReplacement(id self, SEL selector) {
    CMAcceleration value = { 0 };
    if (LHDeviceMotionUserAccelerationOriginal != 0) {
        value = LHDeviceMotionUserAccelerationOriginal(self, selector);
        return LHDeviceMotionQuantizeAcceleration(value, &LHGeneratedPolicySeed_device_motion_acceleration, "fu", 0.05);
    }
    return value;
}

static CMRotationRate LHDeviceMotionRotationRateReplacement(id self, SEL selector) {
    CMRotationRate value = { 0 };
    if (LHDeviceMotionRotationRateOriginal != 0) {
        value = LHDeviceMotionRotationRateOriginal(self, selector);
        return LHDeviceMotionQuantizeRotationRate(value, &LHGeneratedPolicySeed_device_motion_rotation_rate, "fr", 0.05);
    }
    return value;
}

static CMCalibratedMagneticField LHDeviceMotionMagneticFieldReplacement(id self, SEL selector) {
    CMCalibratedMagneticField value = { 0 };
    if (LHDeviceMotionMagneticFieldOriginal != 0) {
        value = LHDeviceMotionMagneticFieldOriginal(self, selector);
        value.field = LHDeviceMotionQuantizeMagneticField(value.field, &LHGeneratedPolicySeed_device_motion_magnetic_field, "fm", 5.0);
    }
    return value;
}

static double LHCMAttitudeRollReplacement(id self, SEL selector) {
    if (LHCMAttitudeRollOriginal == 0) {
        return 0.0;
    }
    return LHDeviceMotionRound(LHCMAttitudeRollOriginal(self, selector),
                               0.08726646259971647,
                               LHDeviceMotionPhase(&LHGeneratedPolicySeed_device_motion_attitude, "roll", 0.08726646259971647));
}

static double LHCMAttitudePitchReplacement(id self, SEL selector) {
    if (LHCMAttitudePitchOriginal == 0) {
        return 0.0;
    }
    return LHDeviceMotionRound(LHCMAttitudePitchOriginal(self, selector),
                               0.08726646259971647,
                               LHDeviceMotionPhase(&LHGeneratedPolicySeed_device_motion_attitude, "pitch", 0.08726646259971647));
}

static double LHCMAttitudeYawReplacement(id self, SEL selector) {
    if (LHCMAttitudeYawOriginal == 0) {
        return 0.0;
    }
    return LHDeviceMotionRound(LHCMAttitudeYawOriginal(self, selector),
                               0.17453292519943295,
                               LHDeviceMotionPhase(&LHGeneratedPolicySeed_device_motion_attitude, "yaw", 0.17453292519943295));
}

static double LHDeviceMotionHeadingReplacement(id self, SEL selector) {
    if (LHDeviceMotionHeadingOriginal == 0) {
        return -1.0;
    }
    double heading = LHDeviceMotionHeadingOriginal(self, selector);
    if (!(heading >= 0.0)) {
        return heading;
    }
    double rounded = LHDeviceMotionRound(heading,
                                         15.0,
                                         LHDeviceMotionPhase(&LHGeneratedPolicySeed_device_motion_heading, "heading", 15.0));
    while (rounded >= 360.0) {
        rounded -= 360.0;
    }
    while (rounded < 0.0) {
        rounded += 360.0;
    }
    return rounded;
}

static bool LHDeviceMotionHookMessage(LHHookBackend *backend,
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

bool LHMitigation_sensors_device_motion_coremotion_quantized_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHDeviceMotionPolicy = policy;
    bool installed = false;

    installed = LHDeviceMotionHookMessage(backend, @"CMAccelerometerData", "acceleration", (void *)LHAccelerometerAccelerationReplacement, (void **)&LHAccelerometerAccelerationOriginal) || installed;
    installed = LHDeviceMotionHookMessage(backend, @"CMGyroData", "rotationRate", (void *)LHGyroRotationRateReplacement, (void **)&LHGyroRotationRateOriginal) || installed;
    installed = LHDeviceMotionHookMessage(backend, @"CMMagnetometerData", "magneticField", (void *)LHMagnetometerFieldReplacement, (void **)&LHMagnetometerFieldOriginal) || installed;
    installed = LHDeviceMotionHookMessage(backend, @"CMDeviceMotion", "gravity", (void *)LHDeviceMotionGravityReplacement, (void **)&LHDeviceMotionGravityOriginal) || installed;
    installed = LHDeviceMotionHookMessage(backend, @"CMDeviceMotion", "userAcceleration", (void *)LHDeviceMotionUserAccelerationReplacement, (void **)&LHDeviceMotionUserAccelerationOriginal) || installed;
    installed = LHDeviceMotionHookMessage(backend, @"CMDeviceMotion", "rotationRate", (void *)LHDeviceMotionRotationRateReplacement, (void **)&LHDeviceMotionRotationRateOriginal) || installed;
    installed = LHDeviceMotionHookMessage(backend, @"CMDeviceMotion", "magneticField", (void *)LHDeviceMotionMagneticFieldReplacement, (void **)&LHDeviceMotionMagneticFieldOriginal) || installed;
    installed = LHDeviceMotionHookMessage(backend, @"CMAttitude", "roll", (void *)LHCMAttitudeRollReplacement, (void **)&LHCMAttitudeRollOriginal) || installed;
    installed = LHDeviceMotionHookMessage(backend, @"CMAttitude", "pitch", (void *)LHCMAttitudePitchReplacement, (void **)&LHCMAttitudePitchOriginal) || installed;
    installed = LHDeviceMotionHookMessage(backend, @"CMAttitude", "yaw", (void *)LHCMAttitudeYawReplacement, (void **)&LHCMAttitudeYawOriginal) || installed;
    installed = LHDeviceMotionHookMessage(backend, @"CMDeviceMotion", "heading", (void *)LHDeviceMotionHeadingReplacement, (void **)&LHDeviceMotionHeadingOriginal) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_sensors_device_motion_coremotion_quantized);
    }
    return true;
}
