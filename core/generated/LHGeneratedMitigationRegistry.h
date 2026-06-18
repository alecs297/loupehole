#ifndef LH_GENERATED_MITIGATION_REGISTRY_H
#define LH_GENERATED_MITIGATION_REGISTRY_H

#include "LHModuleRegistry.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum LHGeneratedModuleID {
    LHModuleID_identity_idfv_uidevice_scoped_uuid = 1,
    LHModuleID_system_boot_time_sysctl_synthetic = 2,
    LHModuleID_storage_volume_creation_time_foundation_synthetic = 3,
} LHGeneratedModuleID;

LH_INTERNAL extern const LHModuleDescriptor LHGeneratedModuleDescriptors[];
LH_INTERNAL extern const size_t LHGeneratedModuleDescriptorCount;

#ifdef __cplusplus
}
#endif

#endif
