#ifndef LH_TWEAK_VALUES_H
#define LH_TWEAK_VALUES_H

#include "LHBuildConfig.h"
#include "LHScope.h"
#include "LHSeed.h"
#include "LHStateProvider.h"
#include "LHTypes.h"

#include <sys/time.h>

#ifdef __cplusplus
extern "C" {
#endif

LH_INTERNAL bool LHTweakDeriveBytes(const LHSeed *seed,
                                    const LHPolicySeed *policySeed,
                                    const LHScope *scope,
                                    const uint8_t *context,
                                    size_t contextLength,
                                    uint8_t *output,
                                    size_t outputLength);
LH_INTERNAL bool LHTweakDeriveU64(const LHSeed *seed,
                                  const LHPolicySeed *policySeed,
                                  const LHScope *scope,
                                  const uint8_t *context,
                                  size_t contextLength,
                                  uint64_t *output);
LH_INTERNAL bool LHTweakDeriveBoundedU64(const LHSeed *seed,
                                         const LHPolicySeed *policySeed,
                                         const LHScope *scope,
                                         const uint8_t *context,
                                         size_t contextLength,
                                         uint64_t upperBound,
                                         uint64_t *output);
LH_INTERNAL bool LHTweakDeriveUUIDString(const LHSeed *seed,
                                         const LHPolicySeed *policySeed,
                                         const LHScope *scope,
                                         char *output,
                                         size_t outputLength);
LH_INTERNAL bool LHTweakDeriveASCIIString(const LHSeed *seed,
                                          const LHPolicySeed *policySeed,
                                          const LHScope *scope,
                                          const char *alphabet,
                                          size_t length,
                                          char *output,
                                          size_t outputLength);
LH_INTERNAL bool LHTweakDeriveTimeIntervalBetween(const LHSeed *seed,
                                                  const LHPolicySeed *policySeed,
                                                  const LHScope *scope,
                                                  double lowerInclusive,
                                                  double upperExclusive,
                                                  double *output);
LH_INTERNAL LHStateKey LHTweakStateKeyFromPolicySeed(const LHPolicySeed *policySeed, uint32_t schemaVersion);

#ifdef __cplusplus
}
#endif

#endif
