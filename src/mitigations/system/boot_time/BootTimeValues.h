#ifndef LH_BOOT_TIME_VALUES_H
#define LH_BOOT_TIME_VALUES_H

#include "LHBuildConfig.h"
#include "LHPolicyEngine.h"

#include <sys/time.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Copies the synthetic boot time owned by the boot-time mitigation. */
LH_INTERNAL bool LHBootTimeCopySyntheticBootTime(const LHPolicyEngine *engine, struct timeval *bootTime);

#ifdef __cplusplus
}
#endif

#endif
