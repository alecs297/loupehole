#ifndef LH_APP_CONTEXT_H
#define LH_APP_CONTEXT_H

#include "LHBuildConfig.h"
#include "LHScope.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LHAppContext {
    LHScope scope;
} LHAppContext;

LH_INTERNAL bool LHAppContextInitCurrent(LHAppContext *context);
LH_INTERNAL bool LHAppContextInitCurrentWithScopeMode(LHAppContext *context, LHScopeMode mode);

#ifdef __cplusplus
}
#endif

#endif
