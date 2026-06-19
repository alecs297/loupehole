#ifndef LH_CONFIG_H
#define LH_CONFIG_H

#include "LHBuildConfig.h"
#include "LHScope.h"
#include "LHSeed.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum LHStateProviderKind {
    LHStateProviderKindEmbedded = 0,
    LHStateProviderKindLocal = 1,
    LHStateProviderKindPackage = 2
} LHStateProviderKind;

typedef enum LHPolicyMode {
    LHPolicyModeOff = 0,
    LHPolicyModeCompatibility = 1,
    LHPolicyModeStandard = 2,
    LHPolicyModeStrict = 3
} LHPolicyMode;

enum {
    LHRuntimeConfigMaxEnabledModules = 1024
};

typedef struct LHRuntimeConfig {
    LHScopeMode scopeMode;
    LHStateProviderKind stateProviderKind;
    LHPolicyMode policyMode;
    bool policyEnabled;
    bool moduleFilterEnabled;
    uint32_t enabledModuleIDs[LHRuntimeConfigMaxEnabledModules];
    size_t enabledModuleIDCount;
    LHSeed instanceSeed;
} LHRuntimeConfig;

LH_INTERNAL LHRuntimeConfig LHRuntimeConfigDefault(void);
LH_INTERNAL bool LHRuntimeConfigIsModuleEnabled(const LHRuntimeConfig *config, uint32_t moduleID);

#ifdef __cplusplus
}
#endif

#endif
