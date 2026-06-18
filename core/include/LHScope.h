#ifndef LH_SCOPE_H
#define LH_SCOPE_H

#include "LHBuildConfig.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum LHScopeMode {
    LHScopeModePerApp = 0,
    LHScopeModePerVendorGroup = 1,
    LHScopeModePerSharedAppGroup = 2,
    LHScopeModeManualLinkedGroup = 3
} LHScopeMode;

typedef struct LHScope {
    LHScopeMode mode;
    uint8_t identifier[128];
    size_t identifierLength;
} LHScope;

LH_INTERNAL bool LHScopeInit(LHScope *scope, LHScopeMode mode, const uint8_t *identifier, size_t identifierLength);
LH_INTERNAL bool LHScopeInitPerApp(LHScope *scope, const char *bundleIdentifier);

#ifdef __cplusplus
}
#endif

#endif
