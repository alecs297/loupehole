#include "LHConfig.h"
#include "LHGeneratedConfig.h"

#include <stdlib.h>

#ifndef LH_DEFAULT_STATE_PROVIDER_KIND
#define LH_DEFAULT_STATE_PROVIDER_KIND LHStateProviderKindLocal
#endif

LHRuntimeConfig LHRuntimeConfigDefault(void) {
    LHRuntimeConfig config = {
        .scopeMode = LHScopeModePerAppInstall,
        .stateProviderKind = LH_DEFAULT_STATE_PROVIDER_KIND,
        .policyEnabled = LH_DEFAULT_STATE_PROVIDER_KIND != LHStateProviderKindPackage,
        .moduleFilterEnabled = false,
        .enabledModuleIDCount = 0
    };
    if (LHGeneratedConfigHasInstanceSeed) {
        config.instanceSeed = LHGeneratedConfigInstanceSeed;
    } else {
        arc4random_buf(config.instanceSeed.bytes, sizeof(config.instanceSeed.bytes));
    }
    return config;
}

bool LHRuntimeConfigIsModuleEnabled(const LHRuntimeConfig *config, uint32_t moduleID) {
    if (config == 0 || !config->policyEnabled || moduleID == 0) {
        return false;
    }
    if (!config->moduleFilterEnabled) {
        return true;
    }

    for (size_t i = 0; i < config->enabledModuleIDCount; i++) {
        if (config->enabledModuleIDs[i] == moduleID) {
            return true;
        }
    }
    return false;
}
