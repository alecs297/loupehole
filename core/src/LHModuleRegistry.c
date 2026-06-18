#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

bool LHModuleRegistryInstall(LHHookBackend *backend, LHPolicyEngine *policy) {
    if (backend == 0 || policy == 0) {
        return false;
    }

    for (size_t i = 0; i < LHGeneratedModuleDescriptorCount; i++) {
        if (!LHGeneratedModuleDescriptors[i].install(backend, policy)) {
            return false;
        }
    }

    return true;
}
