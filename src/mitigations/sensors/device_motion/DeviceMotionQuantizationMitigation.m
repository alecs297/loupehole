#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"
#include "LHValueQuantizer.h"

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

static double LHDeviceMotionPerturbValue(double value,
                                         const LHPolicySeed *policySeed,
                                         const char *context,
                                         double amplitude,
                                         double wavelength) {
    double shaped = value;
    if (LHDeviceMotionPolicy != 0 &&
        context != 0 &&
        LHValueApplySeededSinePerturbation(&LHDeviceMotionPolicy->config.buildSeed,
                                           policySeed,
                                           &LHDeviceMotionPolicy->appContext.scope,
                                           (const uint8_t *)context,
                                           strlen(context),
                                           value,
                                           amplitude,
                                           wavelength,
                                           &shaped)) {
        return shaped == -0.0 ? 0.0 : shaped;
    }
    return value;
}

static CMAcceleration LHDeviceMotionShapeAcceleration(CMAcceleration value,
                                                      const LHPolicySeed *policySeed,
                                                      const char *prefix) {
    char context[8] = { 0 };
    snprintf(context, sizeof(context), "%sx", prefix);
    value.x = LHDeviceMotionPerturbValue(value.x, policySeed, context, 0.015, 0.50);
    snprintf(context, sizeof(context), "%sy", prefix);
    value.y = LHDeviceMotionPerturbValue(value.y, policySeed, context, 0.015, 0.50);
    snprintf(context, sizeof(context), "%sz", prefix);
    value.z = LHDeviceMotionPerturbValue(value.z, policySeed, context, 0.015, 0.50);
    return value;
}

static CMRotationRate LHDeviceMotionShapeRotationRate(CMRotationRate value,
                                                      const LHPolicySeed *policySeed,
                                                      const char *prefix) {
    char context[8] = { 0 };
    snprintf(context, sizeof(context), "%sx", prefix);
    value.x = LHDeviceMotionPerturbValue(value.x, policySeed, context, 0.015, 0.50);
    snprintf(context, sizeof(context), "%sy", prefix);
    value.y = LHDeviceMotionPerturbValue(value.y, policySeed, context, 0.015, 0.50);
    snprintf(context, sizeof(context), "%sz", prefix);
    value.z = LHDeviceMotionPerturbValue(value.z, policySeed, context, 0.015, 0.50);
    return value;
}

static CMMagneticField LHDeviceMotionShapeMagneticField(CMMagneticField value,
                                                        const LHPolicySeed *policySeed,
                                                        const char *prefix) {
    char context[8] = { 0 };
    snprintf(context, sizeof(context), "%sx", prefix);
    value.x = LHDeviceMotionPerturbValue(value.x, policySeed, context, 1.5, 50.0);
    snprintf(context, sizeof(context), "%sy", prefix);
    value.y = LHDeviceMotionPerturbValue(value.y, policySeed, context, 1.5, 50.0);
    snprintf(context, sizeof(context), "%sz", prefix);
    value.z = LHDeviceMotionPerturbValue(value.z, policySeed, context, 1.5, 50.0);
    return value;
}

static CMAcceleration LHAccelerometerAccelerationReplacement(id self, SEL selector) {
    CMAcceleration value = { 0 };
    if (LHAccelerometerAccelerationOriginal != 0) {
        value = LHAccelerometerAccelerationOriginal(self, selector);
        return LHDeviceMotionShapeAcceleration(value, &LHGeneratedPolicySeed_device_motion_acceleration, "ra");
    }
    return value;
}

static CMRotationRate LHGyroRotationRateReplacement(id self, SEL selector) {
    CMRotationRate value = { 0 };
    if (LHGyroRotationRateOriginal != 0) {
        value = LHGyroRotationRateOriginal(self, selector);
        return LHDeviceMotionShapeRotationRate(value, &LHGeneratedPolicySeed_device_motion_rotation_rate, "rg");
    }
    return value;
}

static CMMagneticField LHMagnetometerFieldReplacement(id self, SEL selector) {
    CMMagneticField value = { 0 };
    if (LHMagnetometerFieldOriginal != 0) {
        value = LHMagnetometerFieldOriginal(self, selector);
        return LHDeviceMotionShapeMagneticField(value, &LHGeneratedPolicySeed_device_motion_magnetic_field, "rm");
    }
    return value;
}

static CMAcceleration LHDeviceMotionGravityReplacement(id self, SEL selector) {
    CMAcceleration value = { 0 };
    if (LHDeviceMotionGravityOriginal != 0) {
        value = LHDeviceMotionGravityOriginal(self, selector);
        return LHDeviceMotionShapeAcceleration(value, &LHGeneratedPolicySeed_device_motion_acceleration, "fg");
    }
    return value;
}

static CMAcceleration LHDeviceMotionUserAccelerationReplacement(id self, SEL selector) {
    CMAcceleration value = { 0 };
    if (LHDeviceMotionUserAccelerationOriginal != 0) {
        value = LHDeviceMotionUserAccelerationOriginal(self, selector);
        return LHDeviceMotionShapeAcceleration(value, &LHGeneratedPolicySeed_device_motion_acceleration, "fu");
    }
    return value;
}

static CMRotationRate LHDeviceMotionRotationRateReplacement(id self, SEL selector) {
    CMRotationRate value = { 0 };
    if (LHDeviceMotionRotationRateOriginal != 0) {
        value = LHDeviceMotionRotationRateOriginal(self, selector);
        return LHDeviceMotionShapeRotationRate(value, &LHGeneratedPolicySeed_device_motion_rotation_rate, "fr");
    }
    return value;
}

static CMCalibratedMagneticField LHDeviceMotionMagneticFieldReplacement(id self, SEL selector) {
    CMCalibratedMagneticField value = { 0 };
    if (LHDeviceMotionMagneticFieldOriginal != 0) {
        value = LHDeviceMotionMagneticFieldOriginal(self, selector);
        value.field = LHDeviceMotionShapeMagneticField(value.field, &LHGeneratedPolicySeed_device_motion_magnetic_field, "fm");
    }
    return value;
}

static double LHCMAttitudeRollReplacement(id self, SEL selector) {
    if (LHCMAttitudeRollOriginal == 0) {
        return 0.0;
    }
    return LHDeviceMotionPerturbValue(LHCMAttitudeRollOriginal(self, selector),
                                      &LHGeneratedPolicySeed_device_motion_attitude,
                                      "roll",
                                      0.025,
                                      0.80);
}

static double LHCMAttitudePitchReplacement(id self, SEL selector) {
    if (LHCMAttitudePitchOriginal == 0) {
        return 0.0;
    }
    return LHDeviceMotionPerturbValue(LHCMAttitudePitchOriginal(self, selector),
                                      &LHGeneratedPolicySeed_device_motion_attitude,
                                      "pitch",
                                      0.025,
                                      0.80);
}

static double LHCMAttitudeYawReplacement(id self, SEL selector) {
    if (LHCMAttitudeYawOriginal == 0) {
        return 0.0;
    }
    return LHDeviceMotionPerturbValue(LHCMAttitudeYawOriginal(self, selector),
                                      &LHGeneratedPolicySeed_device_motion_attitude,
                                      "yaw",
                                      0.05,
                                      1.60);
}

static double LHDeviceMotionHeadingReplacement(id self, SEL selector) {
    if (LHDeviceMotionHeadingOriginal == 0) {
        return -1.0;
    }
    double heading = LHDeviceMotionHeadingOriginal(self, selector);
    if (!(heading >= 0.0)) {
        return heading;
    }
    double shaped = LHDeviceMotionPerturbValue(heading,
                                               &LHGeneratedPolicySeed_device_motion_heading,
                                               "heading",
                                               4.0,
                                               90.0);
    while (shaped >= 360.0) {
        shaped -= 360.0;
    }
    while (shaped < 0.0) {
        shaped += 360.0;
    }
    return shaped;
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

bool LHMitigation_sensors_device_motion_coremotion_seeded_jitter_install(LHHookBackend *backend, LHPolicyEngine *policy) {
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
        return LHHookBackendRegisterNoOp(backend, LHModuleID_sensors_device_motion_coremotion_seeded_jitter);
    }
    return true;
}
