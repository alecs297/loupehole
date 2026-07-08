#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

/** Installs all generated mitigation descriptors allowed by the active policy. */
bool LHModuleRegistryInstall(LHHookBackend *backend, LHPolicyEngine *policy) {
    if (backend == 0 || policy == 0) {
        return false;
    }

    for (size_t i = 0; i < LHGeneratedModuleDescriptorCount; i++) {
        if (!LHPolicyEngineIsModuleEnabled(policy, LHGeneratedModuleDescriptors[i].moduleID)) {
            (void)LHHookBackendRegisterNoOp(backend, LHGeneratedModuleDescriptors[i].moduleID);
            continue;
        }
        if (!LHGeneratedModuleDescriptors[i].install(backend, policy)) {
            return false;
        }
    }

    return true;
}
