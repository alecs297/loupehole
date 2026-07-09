#ifndef LH_VALUE_QUANTIZER_H
#define LH_VALUE_QUANTIZER_H

#include "LHBuildConfig.h"
#include "LHMitigationValues.h"
#include "LHTypes.h"

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Rounds `value` down to the nearest `bucketSize` multiple. */
LH_INTERNAL uint64_t LHValueQuantizeDown(uint64_t value, uint64_t bucketSize);
/** Applies a low-cardinality scoped nonlinear curve to a unit interval value. */
LH_INTERNAL bool LHValueMapUnitIntervalCurve(const LHSeed *seed,
                                             const LHPolicySeed *policySeed,
                                             const LHScope *scope,
                                             const uint8_t *context,
                                             size_t contextLength,
                                             double value,
                                             double primaryAmplitudeMax,
                                             double secondaryAmplitudeMax,
                                             double *output);
/** Applies a low-cardinality scoped continuous perturbation to a scalar value. */
LH_INTERNAL bool LHValueApplySeededSinePerturbation(const LHSeed *seed,
                                                    const LHPolicySeed *policySeed,
                                                    const LHScope *scope,
                                                    const uint8_t *context,
                                                    size_t contextLength,
                                                    double value,
                                                    double amplitudeMax,
                                                    double wavelength,
                                                    double *output);

#ifdef __cplusplus
}
#endif

#endif
