#ifndef LH_SCOPE_H
#define LH_SCOPE_H

#include "LHBuildConfig.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum LHScopeMode {
    LHScopeModePerAppInstall = 0,
    LHScopeModePerApp = 1,
    LHScopeModePerVendorGroup = 2,
    LHScopeModeManualLinkedGroup = 3
} LHScopeMode;

typedef struct LHScope {
    LHScopeMode mode;
    uint8_t identifier[128];
    size_t identifierLength;
} LHScope;

LH_INTERNAL bool LHScopeInit(LHScope *scope, LHScopeMode mode, const uint8_t *identifier, size_t identifierLength);
LH_INTERNAL bool LHScopeInitPerAppInstall(LHScope *scope, const char *bundleIdentifier);
LH_INTERNAL bool LHScopeInitPerApp(LHScope *scope, const char *bundleIdentifier);
LH_INTERNAL bool LHScopeInitPerVendorGroup(LHScope *scope, const char *vendorIdentifier);
LH_INTERNAL bool LHScopeInitManualLinkedGroup(LHScope *scope, const char *groupIdentifier);

#ifdef __cplusplus
}
#endif

#endif
