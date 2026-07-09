#ifndef LH_SEED_PROVIDER_H
#define LH_SEED_PROVIDER_H

#include "LHAppContext.h"
#include "LHConfig.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Resolves the practical and active seed for `config` under `context`. */
LH_INTERNAL bool LHSeedProviderResolveActiveSeed(LHRuntimeConfig *config, const LHAppContext *context);

#ifdef __cplusplus
}
#endif

#endif
