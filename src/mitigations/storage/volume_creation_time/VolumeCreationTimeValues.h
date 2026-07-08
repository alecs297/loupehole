#ifndef LH_VOLUME_CREATION_TIME_VALUES_H
#define LH_VOLUME_CREATION_TIME_VALUES_H

#include "LHBuildConfig.h"
#include "LHPolicyEngine.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Copies the synthetic volume creation timestamp owned by the storage mitigation. */
LH_INTERNAL bool LHVolumeCreationTimeCopySyntheticTimestamp(const LHPolicyEngine *engine, double *volumeCreationTime);

#ifdef __cplusplus
}
#endif

#endif
