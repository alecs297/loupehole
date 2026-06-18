#ifndef LH_STATE_PROVIDER_H
#define LH_STATE_PROVIDER_H

#include "LHAppContext.h"
#include "LHBuildConfig.h"
#include "LHConfig.h"
#include "LHSeed.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LHStateKey {
    LHDerivationLabel label;
    uint32_t schemaVersion;
} LHStateKey;

typedef struct LHStateLoadResult {
    bool local;
    bool created;
} LHStateLoadResult;

typedef bool (*LHStateGenerateBytes)(const LHRuntimeConfig *config,
                                     const LHAppContext *context,
                                     void *generatorContext,
                                     uint8_t *output,
                                     size_t outputLength);

LH_INTERNAL bool LHStateProviderLoadOrCreate(const LHRuntimeConfig *config,
                                             const LHAppContext *context,
                                             const LHStateKey *key,
                                             uint8_t *output,
                                             size_t outputLength,
                                             LHStateGenerateBytes generate,
                                             void *generatorContext,
                                             LHStateLoadResult *result);

#ifdef __cplusplus
}
#endif

#endif
