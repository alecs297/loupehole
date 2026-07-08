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

/** Derives tweak-owned bytes from a practical seed, policy seed, scope, and optional context. */
LH_INTERNAL bool LHTweakDeriveBytes(const LHSeed *seed,
                                    const LHPolicySeed *policySeed,
                                    const LHScope *scope,
                                    const uint8_t *context,
                                    size_t contextLength,
                                    uint8_t *output,
                                    size_t outputLength);
/** Derives one little-endian `uint64_t` from a practical seed and policy seed. */
LH_INTERNAL bool LHTweakDeriveU64(const LHSeed *seed,
                                  const LHPolicySeed *policySeed,
                                  const LHScope *scope,
                                  const uint8_t *context,
                                  size_t contextLength,
                                  uint64_t *output);
/** Derives a value in `[0, upperBound)` using deterministic reduction. */
LH_INTERNAL bool LHTweakDeriveBoundedU64(const LHSeed *seed,
                                         const LHPolicySeed *policySeed,
                                         const LHScope *scope,
                                         const uint8_t *context,
                                         size_t contextLength,
                                         uint64_t upperBound,
                                         uint64_t *output);
/** Derives a deterministic RFC 4122 version 4 UUID string. */
LH_INTERNAL bool LHTweakDeriveUUIDString(const LHSeed *seed,
                                         const LHPolicySeed *policySeed,
                                         const LHScope *scope,
                                         char *output,
                                         size_t outputLength);
/** Derives an ASCII string of `length` characters from `alphabet`. */
LH_INTERNAL bool LHTweakDeriveASCIIString(const LHSeed *seed,
                                          const LHPolicySeed *policySeed,
                                          const LHScope *scope,
                                          const char *alphabet,
                                          size_t length,
                                          char *output,
                                          size_t outputLength);
/** Derives a timestamp in `[lowerInclusive, upperExclusive)`. */
LH_INTERNAL bool LHTweakDeriveTimeIntervalBetween(const LHSeed *seed,
                                                  const LHPolicySeed *policySeed,
                                                  const LHScope *scope,
                                                  double lowerInclusive,
                                                  double upperExclusive,
                                                  double *output);
/** Converts a policy seed into a state key label for tweak-owned persisted state. */
LH_INTERNAL LHStateKey LHTweakStateKeyFromPolicySeed(const LHPolicySeed *policySeed, uint32_t schemaVersion);

#ifdef __cplusplus
}
#endif

#endif
