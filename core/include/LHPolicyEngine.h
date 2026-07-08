#ifndef LH_POLICY_ENGINE_H
#define LH_POLICY_ENGINE_H

#include "LHAppContext.h"
#include "LHBuildConfig.h"
#include "LHConfig.h"
#include "LHSeed.h"
#include "LHStateProvider.h"
#include "LHTypes.h"

#include <sys/time.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LHPolicyEngine {
    LHRuntimeConfig config;
    LHAppContext appContext;
    bool initialized;
} LHPolicyEngine;

LH_INTERNAL bool LHPolicyEngineInit(LHPolicyEngine *engine);
LH_INTERNAL bool LHPolicyEngineSetBuildSeed(LHPolicyEngine *engine, const char *uuid);
LH_INTERNAL bool LHPolicyEngineDeriveBytes(const LHPolicyEngine *engine,
                                           const LHDerivationLabel *label,
                                           uint8_t *output,
                                           size_t outputLength);
LH_INTERNAL bool LHPolicyEngineLoadOrCreateState(const LHPolicyEngine *engine,
                                                 const LHStateKey *key,
                                                 uint8_t *output,
                                                 size_t outputLength,
                                                 LHStateGenerateBytes generate,
                                                 void *generatorContext,
                                                 LHStateLoadResult *result);
LH_INTERNAL bool LHPolicyEngineIsModuleEnabled(const LHPolicyEngine *engine, uint32_t moduleID);

#ifdef __cplusplus
}
#endif

#endif
