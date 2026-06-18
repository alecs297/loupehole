#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

bool LHMitigation_system_boot_time_process_info_synthetic_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;
    return LHHookBackendRegisterNoOp(backend, LHModuleID_system_boot_time_process_info_synthetic);
}
