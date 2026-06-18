#ifndef LH_COHERENCE_GRAPH_H
#define LH_COHERENCE_GRAPH_H

#include "LHBuildConfig.h"
#include "LHProfile.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LHCoherenceGraph {
    const LHProfile *profile;
} LHCoherenceGraph;

LH_INTERNAL void LHCoherenceGraphInit(LHCoherenceGraph *graph, const LHProfile *profile);
LH_INTERNAL bool LHCoherenceGraphValidate(const LHCoherenceGraph *graph);

#ifdef __cplusplus
}
#endif

#endif
