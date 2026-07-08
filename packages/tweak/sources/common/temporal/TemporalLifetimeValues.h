#ifndef LH_TEMPORAL_LIFETIME_VALUES_H
#define LH_TEMPORAL_LIFETIME_VALUES_H

#include "LHBuildConfig.h"
#include "LHPolicyEngine.h"

#include <sys/time.h>

#ifdef __cplusplus
extern "C" {
#endif

LH_INTERNAL bool LHTemporalLifetimeCopyBootTime(const LHPolicyEngine *engine, struct timeval *bootTime);
LH_INTERNAL bool LHTemporalLifetimeCopyVolumeCreationTime(const LHPolicyEngine *engine, double *volumeCreationTime);

#ifdef __cplusplus
}
#endif

#endif
