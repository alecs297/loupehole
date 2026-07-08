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

/** Initializes `context` with the current process bundle and default scope mode. */
LH_INTERNAL bool LHAppContextInitCurrent(LHAppContext *context);
/** Initializes `context` with the current process bundle without resolving scope. */
LH_INTERNAL bool LHAppContextInitCurrentBundle(LHAppContext *context);
/** Resolves `context->scope` from the selected runtime scope mode. */
LH_INTERNAL bool LHAppContextResolveScope(LHAppContext *context, LHScopeMode mode);
/** Initializes `context` and resolves scope in one call. */
LH_INTERNAL bool LHAppContextInitCurrentWithScopeMode(LHAppContext *context, LHScopeMode mode);
/** Returns whether `context` describes a third-party app that package mode may target. */
LH_INTERNAL bool LHAppContextIsTargetableThirdPartyApplication(const LHAppContext *context);

#ifdef __cplusplus
}
#endif

#endif
