#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

LH_INTERNAL bool LHBootTimeSysctlInstall(LHHookBackend *backend, LHPolicyEngine *policy);
LH_INTERNAL bool LHBootTimeProcessInfoInstall(LHHookBackend *backend, LHPolicyEngine *policy);

/** Installs every boot-time hook adapter that is available in the target process. */
bool LHMitigation_system_boot_time_composite_synthetic_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    bool installed = false;

    installed = LHBootTimeSysctlInstall(backend, policy) || installed;
    installed = LHBootTimeProcessInfoInstall(backend, policy) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_system_boot_time_composite_synthetic);
    }

    return true;
}
