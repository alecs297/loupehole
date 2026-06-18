#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

bool LHMitigation_identity_idfv_uidevice_scoped_uuid_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;
    return LHHookBackendRegisterNoOp(backend, LHModuleID_identity_idfv_uidevice_scoped_uuid);
}
