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

typedef enum LHDerivationPurpose {
    LHDerivationPurposeScopedSeed = 1,
    LHDerivationPurposeOpaqueName = 2
} LHDerivationPurpose;

LH_INTERNAL bool LHSeedParseUUID(const char *uuid, LHSeed *seed);
LH_INTERNAL bool LHSeedDeriveBytes(const LHSeed *seed,
                                   LHDerivationPurpose purpose,
                                   const LHScope *scope,
                                   uint8_t *output,
                                   size_t outputLength);
LH_INTERNAL bool LHSeedDeriveOpaqueName(const LHSeed *seed,
                                        LHDerivationPurpose purpose,
                                        const LHScope *scope,
                                        char *output,
                                        size_t outputLength);

#ifdef __cplusplus
}
#endif

#endif
