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
    char bundleIdentifier[128];
    size_t bundleIdentifierLength;
    bool systemBundle;
    bool targetableApplication;
} LHAppContext;

LH_INTERNAL bool LHAppContextInitCurrent(LHAppContext *context);
LH_INTERNAL bool LHAppContextInitCurrentBundle(LHAppContext *context);
LH_INTERNAL bool LHAppContextResolveScope(LHAppContext *context, LHScopeMode mode);
LH_INTERNAL bool LHAppContextInitCurrentWithScopeMode(LHAppContext *context, LHScopeMode mode);
LH_INTERNAL bool LHAppContextIsTargetableThirdPartyApplication(const LHAppContext *context);

#ifdef __cplusplus
}
#endif

#endif
