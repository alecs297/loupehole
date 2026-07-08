#include "LHPolicyEngine.h"
#include "LHConfigProvider.h"
#include "LHSeedProvider.h"

#include <string.h>

/** Initializes the policy engine, runtime config, app context, scope, and seed. */
bool LHPolicyEngineInit(LHPolicyEngine *engine) {
    if (engine == 0) {
        return false;
    }

    memset(engine, 0, sizeof(*engine));
    engine->config = LHRuntimeConfigDefault();
    if (!LHAppContextInitCurrentBundle(&engine->appContext)) {
        return false;
    }

    if (engine->config.stateProviderKind == LHStateProviderKindPackage &&
        !LHAppContextIsTargetableThirdPartyApplication(&engine->appContext)) {
        engine->config.policyEnabled = false;
        engine->initialized = true;
        return true;
    }

    if (!LHConfigProviderApplyRuntimePolicy(&engine->config, &engine->appContext)) {
        return false;
    }
    if (!engine->config.policyEnabled) {
        engine->initialized = true;
        return true;
    }

    if (!LHAppContextResolveScope(&engine->appContext, engine->config.scopeMode)) {
        return false;
    }
    if (!LHSeedProviderResolveActiveSeed(&engine->config, &engine->appContext)) {
        return false;
    }

    engine->initialized = true;
    return true;
}

/** Sets the build seed from a UUID string. */
bool LHPolicyEngineSetBuildSeed(LHPolicyEngine *engine, const char *uuid) {
    if (engine == 0) {
        return false;
    }

    LHSeed parsed = { 0 };
    if (!LHSeedParseUUID(uuid, &parsed)) {
        return false;
    }

    engine->config.buildSeed = parsed;
    return true;
}

/** Derives scoped bytes using an internal generated derivation label. */
bool LHPolicyEngineDeriveBytes(const LHPolicyEngine *engine,
                               const LHDerivationLabel *label,
                               uint8_t *output,
                               size_t outputLength) {
    if (engine == 0 || !engine->initialized || label == 0 || output == 0 || outputLength == 0) {
        return false;
    }

    return LHSeedDeriveBytes(&engine->config.buildSeed, label, &engine->appContext.scope, output, outputLength);
}

/** Loads or creates a state blob through the configured state provider. */
bool LHPolicyEngineLoadOrCreateState(const LHPolicyEngine *engine,
                                     const LHStateKey *key,
                                     uint8_t *output,
                                     size_t outputLength,
                                     LHStateGenerateBytes generate,
                                     void *generatorContext,
                                     LHStateLoadResult *result) {
    if (engine == 0 || !engine->initialized) {
        return false;
    }

    return LHStateProviderLoadOrCreate(&engine->config,
                                       &engine->appContext,
                                       key,
                                       output,
                                       outputLength,
                                       generate,
                                       generatorContext,
                                       result);
}

/** Returns whether a module ID is enabled for the initialized engine. */
bool LHPolicyEngineIsModuleEnabled(const LHPolicyEngine *engine, uint32_t moduleID) {
    if (engine == 0 || !engine->initialized) {
        return false;
    }
    return LHRuntimeConfigIsModuleEnabled(&engine->config, moduleID);
}
