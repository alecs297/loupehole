#ifndef LH_CONFIG_PROVIDER_H
#define LH_CONFIG_PROVIDER_H

#include "LHAppContext.h"
#include "LHBuildConfig.h"
#include "LHConfig.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

LH_INTERNAL bool LHConfigProviderApplyRuntimePolicy(LHRuntimeConfig *config, const LHAppContext *context);

#ifdef __cplusplus
}
#endif

#endif
