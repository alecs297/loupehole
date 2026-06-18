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

typedef struct LHRuntimeConfig {
    LHScopeMode scopeMode;
    LHStateProviderKind stateProviderKind;
    LHSeed instanceSeed;
} LHRuntimeConfig;

LH_INTERNAL LHRuntimeConfig LHRuntimeConfigDefault(void);

#ifdef __cplusplus
}
#endif

#endif
