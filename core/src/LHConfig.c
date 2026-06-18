#include "LHConfig.h"
#include "LHGeneratedConfig.h"

#include <stdlib.h>

#ifndef LH_DEFAULT_STATE_PROVIDER_KIND
#define LH_DEFAULT_STATE_PROVIDER_KIND LHStateProviderKindLocal
#endif

LHRuntimeConfig LHRuntimeConfigDefault(void) {
    LHRuntimeConfig config = {
        .scopeMode = LHScopeModePerApp,
        .stateProviderKind = LH_DEFAULT_STATE_PROVIDER_KIND
    };
    if (LHGeneratedConfigHasInstanceSeed) {
        config.instanceSeed = LHGeneratedConfigInstanceSeed;
    } else {
        arc4random_buf(config.instanceSeed.bytes, sizeof(config.instanceSeed.bytes));
    }
    return config;
}
