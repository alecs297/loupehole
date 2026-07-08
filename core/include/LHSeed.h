#ifndef LH_SEED_H
#define LH_SEED_H

#include "LHBuildConfig.h"
#include "LHScope.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LHSeed {
    uint8_t bytes[16];
} LHSeed;

typedef struct LHDerivationLabel {
    uint8_t bytes[16];
} LHDerivationLabel;

typedef struct LHPolicySeed {
    uint8_t bytes[16];
} LHPolicySeed;

#ifdef __cplusplus
#define LH_DERIVATION_LABEL(domain, name) \
    extern "C" { LH_INTERNAL extern const LHDerivationLabel LHGeneratedDerivationLabel_##domain##_##name; }
#define LH_POLICY_SEED(identifier) \
    extern "C" { LH_INTERNAL extern const LHPolicySeed LHGeneratedPolicySeed_##identifier; }
#else
#define LH_DERIVATION_LABEL(domain, name) \
    LH_INTERNAL extern const LHDerivationLabel LHGeneratedDerivationLabel_##domain##_##name;
#define LH_POLICY_SEED(identifier) \
    LH_INTERNAL extern const LHPolicySeed LHGeneratedPolicySeed_##identifier;
#endif

/** Parses a UUID string into a 16-byte seed. */
LH_INTERNAL bool LHSeedParseUUID(const char *uuid, LHSeed *seed);
/** Derives scoped bytes from `seed`, `label`, and `scope`. */
LH_INTERNAL bool LHSeedDeriveBytes(const LHSeed *seed,
                                   const LHDerivationLabel *label,
                                   const LHScope *scope,
                                   uint8_t *output,
                                   size_t outputLength);
/** Derives scoped bytes with extra context mixed into the derivation transcript. */
LH_INTERNAL bool LHSeedDeriveBytesWithContext(const LHSeed *seed,
                                              const LHDerivationLabel *label,
                                              const LHScope *scope,
                                              const uint8_t *context,
                                              size_t contextLength,
                                              uint8_t *output,
                                              size_t outputLength);
/** Formats a scoped derivation as a 32-character opaque lowercase hex name. */
LH_INTERNAL bool LHSeedDeriveOpaqueName(const LHSeed *seed,
                                        const LHDerivationLabel *label,
                                        const LHScope *scope,
                                        char *output,
                                        size_t outputLength);

#ifdef __cplusplus
}
#endif

#endif
