#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

bool LHMitigation_storage_volume_creation_time_foundation_synthetic_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;
    return LHHookBackendRegisterNoOp(backend, LHModuleID_storage_volume_creation_time_foundation_synthetic);
}
