#ifndef LH_POLICY_ENGINE_H
#define LH_POLICY_ENGINE_H

#include "LHAppContext.h"
#include "LHBuildConfig.h"
#include "LHCoherenceGraph.h"
#include "LHProfile.h"
#include "LHSeed.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LHPolicyEngine {
    LHSeed instanceSeed;
    LHAppContext appContext;
    LHCoherenceGraph graph;
    bool hasInstanceSeed;
} LHPolicyEngine;

LH_INTERNAL bool LHPolicyEngineInit(LHPolicyEngine *engine);
LH_INTERNAL bool LHPolicyEngineSetInstanceSeed(LHPolicyEngine *engine, const char *uuid);
LH_INTERNAL bool LHPolicyEngineDeriveScopedSeed(const LHPolicyEngine *engine, uint8_t *output, size_t outputLength);

#ifdef __cplusplus
}
#endif

#endif
