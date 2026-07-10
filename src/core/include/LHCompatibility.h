#ifndef LH_COMPATIBILITY_H
#define LH_COMPATIBILITY_H

#include "LHBuildConfig.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum LHCompatibilityDecision {
    LHCompatibilityDecisionPassThrough = 0,
    LHCompatibilityDecisionUsePolicy = 1
} LHCompatibilityDecision;

/** Returns the default fallback behavior when a mitigation cannot synthesize a value. */
LH_INTERNAL LHCompatibilityDecision LHCompatibilityDefaultDecision(void);

#ifdef __cplusplus
}
#endif

#endif
