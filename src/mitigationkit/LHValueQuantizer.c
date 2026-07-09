#include "LHValueQuantizer.h"

#include <math.h>

#define LH_VALUE_PI 3.14159265358979323846

/** Rounds a value down to the nearest bucket boundary. */
uint64_t LHValueQuantizeDown(uint64_t value, uint64_t bucketSize) {
    if (bucketSize == 0) {
        return value;
    }

    return value - (value % bucketSize);
}

/** Applies a seeded smooth curve to values that are already bounded to [0, 1]. */
bool LHValueMapUnitIntervalCurve(const LHSeed *seed,
                                 const LHPolicySeed *policySeed,
                                 const LHScope *scope,
                                 const uint8_t *context,
                                 size_t contextLength,
                                 double value,
                                 double primaryAmplitudeMax,
                                 double secondaryAmplitudeMax,
                                 double *output) {
    if (output == 0 ||
        !isfinite(value) ||
        value < 0.0 ||
        value > 1.0 ||
        !(primaryAmplitudeMax >= 0.0) ||
        !(secondaryAmplitudeMax >= 0.0)) {
        return false;
    }

    uint64_t profile = 0;
    if (!LHMitigationDeriveBoundedU64(seed,
                                      policySeed,
                                      scope,
                                      context,
                                      contextLength,
                                      48,
                                      &profile)) {
        return false;
    }

    double primaryScale = 0.5 + (0.25 * (double)(profile % 3));
    double secondaryScale = (double)((profile / 3) % 3) / 2.0;
    double primaryDirection = ((profile / 9) % 2) == 0 ? 1.0 : -1.0;
    double secondaryDirection = ((profile / 18) % 2) == 0 ? 1.0 : -1.0;
    double curved = value +
                    (primaryDirection * primaryAmplitudeMax * primaryScale * sin(LH_VALUE_PI * value)) +
                    (secondaryDirection * secondaryAmplitudeMax * secondaryScale * sin(2.0 * LH_VALUE_PI * value));
    if (curved < 0.0) {
        curved = 0.0;
    } else if (curved > 1.0) {
        curved = 1.0;
    }

    if (value > 0.0 && value < 1.0) {
        if (curved <= 0.0) {
            curved = 0.000001;
        } else if (curved >= 1.0) {
            curved = 0.999999;
        }
    }
    *output = curved;
    return true;
}

/** Applies a deterministic sine perturbation whose profile is scoped by seed and context. */
bool LHValueApplySeededSinePerturbation(const LHSeed *seed,
                                        const LHPolicySeed *policySeed,
                                        const LHScope *scope,
                                        const uint8_t *context,
                                        size_t contextLength,
                                        double value,
                                        double amplitudeMax,
                                        double wavelength,
                                        double *output) {
    if (output == 0 ||
        !isfinite(value) ||
        !(amplitudeMax > 0.0) ||
        !(wavelength > 0.0)) {
        return false;
    }

    uint64_t profile = 0;
    if (!LHMitigationDeriveBoundedU64(seed,
                                      policySeed,
                                      scope,
                                      context,
                                      contextLength,
                                      64,
                                      &profile)) {
        return false;
    }

    double amplitudeScale = 0.5 + (0.125 * (double)(profile % 5));
    double phase = (2.0 * LH_VALUE_PI * (double)((profile / 5) % 16)) / 16.0;
    double wave = ((2.0 * LH_VALUE_PI * value) / wavelength) + phase;
    *output = value + (amplitudeMax * amplitudeScale * sin(wave));
    return true;
}
