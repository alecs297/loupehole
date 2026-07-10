#include "LHConfig.h"
#include "LHGeneratedConfig.h"

#include <stdlib.h>

#ifndef LH_DEFAULT_STATE_PROVIDER_KIND
#define LH_DEFAULT_STATE_PROVIDER_KIND LHStateProviderKindLocal
#endif

#ifndef LH_DEFAULT_SCOPE_MODE
#define LH_DEFAULT_SCOPE_MODE LHScopeModePerAppInstall
#endif

/** Builds the default runtime configuration from generated build inputs. */
LHRuntimeConfig LHRuntimeConfigDefault(void) {
    LHRuntimeConfig config = {
        .scopeMode = LH_DEFAULT_SCOPE_MODE,
        .stateProviderKind = LH_DEFAULT_STATE_PROVIDER_KIND,
        .policyEnabled = LH_DEFAULT_STATE_PROVIDER_KIND != LHStateProviderKindPackage,
        .moduleFilterEnabled = false,
        .enabledModuleIDCount = 0
    };
    if (LHGeneratedConfigHasBuildSeed) {
        config.buildSeed = LHGeneratedConfigBuildSeed;
    } else {
        arc4random_buf(config.buildSeed.bytes, sizeof(config.buildSeed.bytes));
    }
    return config;
}

/** Returns whether a generated module ID is active under the runtime filter. */
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
