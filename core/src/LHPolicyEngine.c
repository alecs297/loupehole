#include "LHPolicyEngine.h"

#include <string.h>

bool LHPolicyEngineInit(LHPolicyEngine *engine) {
    if (engine == 0) {
        return false;
    }

    memset(engine, 0, sizeof(*engine));
    if (!LHAppContextInitCurrent(&engine->appContext)) {
        return false;
    }

    LHCoherenceGraphInit(&engine->graph, LHProfileDefault());
    return LHCoherenceGraphValidate(&engine->graph);
}

bool LHPolicyEngineSetInstanceSeed(LHPolicyEngine *engine, const char *uuid) {
    if (engine == 0) {
        return false;
    }

    LHSeed parsed = { 0 };
    if (!LHSeedParseUUID(uuid, &parsed)) {
        return false;
    }

    engine->instanceSeed = parsed;
    engine->hasInstanceSeed = true;
    return true;
}

bool LHPolicyEngineDeriveScopedSeed(const LHPolicyEngine *engine, uint8_t *output, size_t outputLength) {
    if (engine == 0 || !engine->hasInstanceSeed) {
        return false;
    }

    return LHSeedDeriveBytes(&engine->instanceSeed, LHDerivationPurposeScopedSeed, &engine->appContext.scope, output, outputLength);
}
