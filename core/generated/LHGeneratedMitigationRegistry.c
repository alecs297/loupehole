#include "LHGeneratedMitigationRegistry.h"

LH_INTERNAL bool LHMitigation_identity_idfv_uidevice_scoped_uuid_install(LHHookBackend *backend, LHPolicyEngine *policy);
LH_INTERNAL bool LHMitigation_system_boot_time_sysctl_synthetic_install(LHHookBackend *backend, LHPolicyEngine *policy);
LH_INTERNAL bool LHMitigation_storage_volume_creation_time_foundation_synthetic_install(LHHookBackend *backend, LHPolicyEngine *policy);

LH_INTERNAL const LHModuleDescriptor LHGeneratedModuleDescriptors[] = {
    { LHModuleID_identity_idfv_uidevice_scoped_uuid, LHMitigation_identity_idfv_uidevice_scoped_uuid_install },
    { LHModuleID_system_boot_time_sysctl_synthetic, LHMitigation_system_boot_time_sysctl_synthetic_install },
    { LHModuleID_storage_volume_creation_time_foundation_synthetic, LHMitigation_storage_volume_creation_time_foundation_synthetic_install },
};

LH_INTERNAL const size_t LHGeneratedModuleDescriptorCount = sizeof(LHGeneratedModuleDescriptors) / sizeof(LHGeneratedModuleDescriptors[0]);
