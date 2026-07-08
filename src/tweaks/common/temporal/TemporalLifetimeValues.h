#ifndef LH_TEMPORAL_LIFETIME_VALUES_H
#define LH_TEMPORAL_LIFETIME_VALUES_H

#include "LHBuildConfig.h"
#include "LHPolicyEngine.h"

#include <sys/time.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Copies the coherent synthetic boot time for the current policy engine. */
LH_INTERNAL bool LHTemporalLifetimeCopyBootTime(const LHPolicyEngine *engine, struct timeval *bootTime);
/** Copies the coherent synthetic volume creation timestamp for the current policy engine. */
LH_INTERNAL bool LHTemporalLifetimeCopyVolumeCreationTime(const LHPolicyEngine *engine, double *volumeCreationTime);

#ifdef __cplusplus
}
#endif

#endif
