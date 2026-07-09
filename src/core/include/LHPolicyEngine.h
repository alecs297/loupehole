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

/** Initializes policy state, app context, runtime policy, scope, and active seed. */
LH_INTERNAL bool LHPolicyEngineInit(LHPolicyEngine *engine);
/** Overrides `engine` build seed from a UUID string for tests and diagnostics. */
LH_INTERNAL bool LHPolicyEngineSetBuildSeed(LHPolicyEngine *engine, const char *uuid);
/** Derives scoped bytes using a generated internal derivation label. */
LH_INTERNAL bool LHPolicyEngineDeriveBytes(const LHPolicyEngine *engine,
                                           const LHDerivationLabel *label,
                                           uint8_t *output,
                                           size_t outputLength);
/** Loads or creates a state blob keyed by `key` for the initialized engine context. */
LH_INTERNAL bool LHPolicyEngineLoadOrCreateState(const LHPolicyEngine *engine,
                                                 const LHStateKey *key,
                                                 uint8_t *output,
                                                 size_t outputLength,
                                                 LHStateGenerateBytes generate,
                                                 void *generatorContext,
                                                 LHStateLoadResult *result);
/** Returns whether `moduleID` is enabled for an initialized engine. */
LH_INTERNAL bool LHPolicyEngineIsModuleEnabled(const LHPolicyEngine *engine, uint32_t moduleID);

#ifdef __cplusplus
}
#endif

#endif
