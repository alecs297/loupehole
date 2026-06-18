#include "LHPolicyEngine.h"
#include "LHGeneratedPolicyValueRegistry.h"
#include "LHSeedProvider.h"

#include <string.h>

bool LHPolicyEngineInit(LHPolicyEngine *engine) {
    if (engine == 0) {
        return false;
    }

    memset(engine, 0, sizeof(*engine));
    engine->config = LHRuntimeConfigDefault();
    if (!LHAppContextInitCurrentWithScopeMode(&engine->appContext, engine->config.scopeMode)) {
        return false;
    }
    if (!LHSeedProviderResolveActiveSeed(&engine->config, &engine->appContext)) {
        return false;
    }

    engine->profile = LHProfileDefault();
    if (engine->profile == 0 || engine->profile->version == 0) {
        return false;
    }

    engine->initialized = true;
    return true;
}

bool LHPolicyEngineSetInstanceSeed(LHPolicyEngine *engine, const char *uuid) {
    if (engine == 0) {
        return false;
    }

    LHSeed parsed = { 0 };
    if (!LHSeedParseUUID(uuid, &parsed)) {
        return false;
    }

    engine->config.instanceSeed = parsed;
    return true;
}

bool LHPolicyEngineDeriveBytes(const LHPolicyEngine *engine,
                               const LHDerivationLabel *label,
                               uint8_t *output,
                               size_t outputLength) {
    if (engine == 0 || !engine->initialized || label == 0 || output == 0 || outputLength == 0) {
        return false;
    }

    return LHSeedDeriveBytes(&engine->config.instanceSeed, label, &engine->appContext.scope, output, outputLength);
}

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

bool LHPolicyEngineCopyValue(const LHPolicyEngine *engine,
                             const LHPolicyValueRequest *request,
                             LHPolicyValueResponse *response) {
    if (engine == 0 || request == 0 || !engine->initialized) {
        return false;
    }

    if (response != 0) {
        memset(response, 0, sizeof(*response));
    }

    for (size_t i = 0; i < LHGeneratedPolicyValueDescriptorCount; i++) {
        const LHPolicyValueDescriptor *descriptor = &LHGeneratedPolicyValueDescriptors[i];
        if (descriptor->valueID != request->valueID) {
            continue;
        }
        if (descriptor->kind != request->expectedKind || descriptor->resolver == 0) {
            return false;
        }
        return descriptor->resolver(engine, request, response);
    }

    return false;
}
