#ifndef LH_MODULE_REGISTRY_H
#define LH_MODULE_REGISTRY_H

#include "LHBuildConfig.h"
#include "LHHookBackend.h"
#include "LHPolicyEngine.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef bool (*LHModuleInstall)(LHHookBackend *backend, LHPolicyEngine *policy);

typedef struct LHModuleDescriptor {
    uint32_t moduleID;
    LHModuleInstall install;
} LHModuleDescriptor;

/** Installs every generated mitigation descriptor that is enabled by `policy`. */
LH_INTERNAL bool LHModuleRegistryInstall(LHHookBackend *backend, LHPolicyEngine *policy);

#ifdef __cplusplus
}
#endif

#endif
