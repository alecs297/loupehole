#include "LHCoherenceGraph.h"

void LHCoherenceGraphInit(LHCoherenceGraph *graph, const LHProfile *profile) {
    if (graph == 0) {
        return;
    }

    graph->profile = profile;
}

bool LHCoherenceGraphValidate(const LHCoherenceGraph *graph) {
    return graph != 0 && graph->profile != 0 && graph->profile->version != 0;
}
