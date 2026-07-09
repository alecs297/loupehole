#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <math.h>
#include <string.h>

typedef CLLocationCoordinate2D (*LHLocationCoordinateOriginal)(id self, SEL selector);
typedef CLLocationDistance (*LHLocationDistanceOriginal)(id self, SEL selector);
typedef CLLocationSpeed (*LHLocationSpeedOriginal)(id self, SEL selector);
typedef CLLocationDirection (*LHLocationDirectionOriginal)(id self, SEL selector);
typedef CLFloor *(*LHLocationFloorOriginal)(id self, SEL selector);
typedef CLAccuracyAuthorization (*LHAccuracyAuthorizationOriginal)(id self, SEL selector);

LH_POLICY_SEED(location_coordinate_grid)
LH_POLICY_SEED(location_motion_context)

static LHLocationCoordinateOriginal LHLocationCoordinateOriginalImplementation;
static LHLocationDistanceOriginal LHLocationAltitudeOriginal;
static LHLocationDistanceOriginal LHLocationHorizontalAccuracyOriginal;
static LHLocationDistanceOriginal LHLocationVerticalAccuracyOriginal;
static LHLocationFloorOriginal LHLocationFloorOriginalImplementation;
static LHLocationSpeedOriginal LHLocationSpeedOriginalImplementation;
static LHLocationDirectionOriginal LHLocationCourseOriginalImplementation;
static LHAccuracyAuthorizationOriginal LHAccuracyAuthorizationOriginalImplementation;
static LHPolicyEngine *LHLocationPolicy;

static double LHLocationPhase(const LHPolicySeed *policySeed, const char *context, double step) {
    uint64_t bucket = 0;
    if (LHLocationPolicy == 0 ||
        context == 0 ||
        !LHMitigationDeriveBoundedU64(&LHLocationPolicy->config.buildSeed,
                                      policySeed,
                                      &LHLocationPolicy->appContext.scope,
                                      (const uint8_t *)context,
                                      strlen(context),
                                      4,
                                      &bucket)) {
        return 0.0;
    }
    return ((double)bucket * step) / 4.0;
}

static double LHLocationRound(double value, const LHPolicySeed *policySeed, const char *context, double step) {
    if (!(step > 0.0)) {
        return value;
    }
    double phase = LHLocationPhase(policySeed, context, step);
    return nearbyint((value - phase) / step) * step + phase;
}

static CLLocationCoordinate2D LHLocationCoordinateReplacement(id self, SEL selector) {
    CLLocationCoordinate2D coordinate = kCLLocationCoordinate2DInvalid;
    if (LHLocationCoordinateOriginalImplementation == 0) {
        return coordinate;
    }

    coordinate = LHLocationCoordinateOriginalImplementation(self, selector);
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return coordinate;
    }

    coordinate.latitude = LHLocationRound(coordinate.latitude, &LHGeneratedPolicySeed_location_coordinate_grid, "lat", 0.05);
    coordinate.longitude = LHLocationRound(coordinate.longitude, &LHGeneratedPolicySeed_location_coordinate_grid, "lon", 0.05);
    if (coordinate.latitude > 90.0) {
        coordinate.latitude = 90.0;
    } else if (coordinate.latitude < -90.0) {
        coordinate.latitude = -90.0;
    }
    while (coordinate.longitude > 180.0) {
        coordinate.longitude -= 360.0;
    }
    while (coordinate.longitude < -180.0) {
        coordinate.longitude += 360.0;
    }
    return coordinate;
}

static CLLocationDistance LHLocationAltitudeReplacement(id self, SEL selector) {
    if (LHLocationAltitudeOriginal == 0) {
        return 0.0;
    }
    return LHLocationRound(LHLocationAltitudeOriginal(self, selector), &LHGeneratedPolicySeed_location_coordinate_grid, "alt", 50.0);
}

static CLLocationDistance LHLocationHorizontalAccuracyReplacement(id self, SEL selector) {
    if (LHLocationHorizontalAccuracyOriginal == 0) {
        return -1.0;
    }
    CLLocationDistance original = LHLocationHorizontalAccuracyOriginal(self, selector);
    if (!(original >= 0.0)) {
        return original;
    }
    CLLocationDistance rounded = LHLocationRound(original, &LHGeneratedPolicySeed_location_coordinate_grid, "hacc", 1000.0);
    return rounded < 5000.0 ? 5000.0 : rounded;
}

static CLLocationDistance LHLocationVerticalAccuracyReplacement(id self, SEL selector) {
    if (LHLocationVerticalAccuracyOriginal == 0) {
        return -1.0;
    }
    CLLocationDistance original = LHLocationVerticalAccuracyOriginal(self, selector);
    if (!(original >= 0.0)) {
        return original;
    }
    CLLocationDistance rounded = LHLocationRound(original, &LHGeneratedPolicySeed_location_coordinate_grid, "vacc", 50.0);
    return rounded < 100.0 ? 100.0 : rounded;
}

static CLFloor *LHLocationFloorReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return nil;
}

static CLLocationSpeed LHLocationSpeedReplacement(id self, SEL selector) {
    if (LHLocationSpeedOriginalImplementation == 0) {
        return -1.0;
    }
    CLLocationSpeed original = LHLocationSpeedOriginalImplementation(self, selector);
    if (!(original >= 0.0)) {
        return original;
    }
    if (original < 1.0) {
        return 0.0;
    }
    return LHLocationRound(original, &LHGeneratedPolicySeed_location_motion_context, "speed", 5.0);
}

static CLLocationDirection LHLocationCourseReplacement(id self, SEL selector) {
    if (LHLocationCourseOriginalImplementation == 0) {
        return -1.0;
    }
    CLLocationDirection original = LHLocationCourseOriginalImplementation(self, selector);
    if (!(original >= 0.0)) {
        return original;
    }
    CLLocationDirection rounded = LHLocationRound(original, &LHGeneratedPolicySeed_location_motion_context, "course", 45.0);
    while (rounded >= 360.0) {
        rounded -= 360.0;
    }
    while (rounded < 0.0) {
        rounded += 360.0;
    }
    return rounded;
}

static CLAccuracyAuthorization LHAccuracyAuthorizationReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return CLAccuracyAuthorizationReducedAccuracy;
}

static bool LHLocationHookMessage(LHHookBackend *backend,
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

bool LHMitigation_location_core_location_foundation_coarse_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHLocationPolicy = policy;
    bool installed = false;

    installed = LHLocationHookMessage(backend, @"CLLocation", "coordinate", (void *)LHLocationCoordinateReplacement, (void **)&LHLocationCoordinateOriginalImplementation) || installed;
    installed = LHLocationHookMessage(backend, @"CLLocation", "altitude", (void *)LHLocationAltitudeReplacement, (void **)&LHLocationAltitudeOriginal) || installed;
    installed = LHLocationHookMessage(backend, @"CLLocation", "horizontalAccuracy", (void *)LHLocationHorizontalAccuracyReplacement, (void **)&LHLocationHorizontalAccuracyOriginal) || installed;
    installed = LHLocationHookMessage(backend, @"CLLocation", "verticalAccuracy", (void *)LHLocationVerticalAccuracyReplacement, (void **)&LHLocationVerticalAccuracyOriginal) || installed;
    installed = LHLocationHookMessage(backend, @"CLLocation", "floor", (void *)LHLocationFloorReplacement, (void **)&LHLocationFloorOriginalImplementation) || installed;
    installed = LHLocationHookMessage(backend, @"CLLocation", "speed", (void *)LHLocationSpeedReplacement, (void **)&LHLocationSpeedOriginalImplementation) || installed;
    installed = LHLocationHookMessage(backend, @"CLLocation", "course", (void *)LHLocationCourseReplacement, (void **)&LHLocationCourseOriginalImplementation) || installed;
    installed = LHLocationHookMessage(backend, @"CLLocationManager", "accuracyAuthorization", (void *)LHAccuracyAuthorizationReplacement, (void **)&LHAccuracyAuthorizationOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_location_core_location_foundation_coarse);
    }
    return true;
}
