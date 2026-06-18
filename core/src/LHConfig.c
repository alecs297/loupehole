#include "LHConfig.h"
#include "LHGeneratedConfig.h"

#include <stdlib.h>

LHRuntimeConfig LHRuntimeConfigDefault(void) {
    LHRuntimeConfig config = {
        .scopeMode = LHScopeModePerApp,
        .stateProviderKind = LHStateProviderKindLocal
    };
    if (LHGeneratedConfigHasInstanceSeed) {
        config.instanceSeed = LHGeneratedConfigInstanceSeed;
    } else {
        arc4random_buf(config.instanceSeed.bytes, sizeof(config.instanceSeed.bytes));
    }
    return config;
}
