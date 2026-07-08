#include "BootTimeValues.h"

#include "LHMitigationValues.h"

#include <time.h>

LH_POLICY_SEED(boot_time)
LH_POLICY_SEED(volume_creation_date)

#define LH_SECONDS_PER_HOUR 3600ULL
#define LH_SECONDS_PER_DAY 86400ULL
#define LH_DAYS_PER_YEAR 365ULL
#define LH_MIN_BOOT_AGE_SECONDS (6ULL * LH_SECONDS_PER_HOUR)
#define LH_BOOT_LOOKBACK_SECONDS (14ULL * LH_SECONDS_PER_DAY)
#define LH_MIN_BOOT_AFTER_VOLUME_SECONDS (7ULL * LH_SECONDS_PER_DAY)
#define LH_VOLUME_CREATION_MIN_AGE_SECONDS (30ULL * LH_SECONDS_PER_DAY)
#define LH_VOLUME_CREATION_MAX_AGE_SECONDS (2ULL * LH_DAYS_PER_YEAR * LH_SECONDS_PER_DAY)

/** Derives the volume-creation baseline used to keep boot time coherent. */
static bool LHBootTimeCopyVolumeCreationBaseline(const LHPolicyEngine *engine,
                                                 double *volumeCreationTime) {
    return LHMitigationCopyStablePastTime(engine,
                                          &LHGeneratedPolicySeed_volume_creation_date,
                                          1,
                                          LH_VOLUME_CREATION_MIN_AGE_SECONDS,
                                          LH_VOLUME_CREATION_MAX_AGE_SECONDS,
                                          volumeCreationTime);
}

/** Copies the synthetic boot time owned by the boot-time mitigation. */
bool LHBootTimeCopySyntheticBootTime(const LHPolicyEngine *engine, struct timeval *bootTime) {
    if (engine == 0 || bootTime == 0) {
        return false;
    }

    time_t now = time(0);
    double volumeCreationTime = 0.0;
    if (now <= 0 || !LHBootTimeCopyVolumeCreationBaseline(engine, &volumeCreationTime)) {
        return false;
    }

    double lowerBound = (double)now - (double)LH_BOOT_LOOKBACK_SECONDS;
    double volumeBound = volumeCreationTime + (double)LH_MIN_BOOT_AFTER_VOLUME_SECONDS;
    if (lowerBound < volumeBound) {
        lowerBound = volumeBound;
    }

    double upperBound = (double)now - (double)LH_MIN_BOOT_AGE_SECONDS;
    double bootTimestamp = 0.0;
    if (!LHMitigationCopyStableTimeIntervalBetween(engine,
                                                   &LHGeneratedPolicySeed_boot_time,
                                                   1,
                                                   lowerBound,
                                                   upperBound,
                                                   &bootTimestamp)) {
        return false;
    }

    bootTime->tv_sec = (time_t)bootTimestamp;
    bootTime->tv_usec = 0;
    return (double)bootTime->tv_sec > volumeCreationTime && bootTime->tv_sec < now;
}
