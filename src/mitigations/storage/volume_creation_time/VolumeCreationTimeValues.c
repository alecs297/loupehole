#include "VolumeCreationTimeValues.h"

#include "LHMitigationValues.h"

LH_POLICY_SEED(volume_creation_date)

#define LH_SECONDS_PER_DAY 86400ULL
#define LH_DAYS_PER_YEAR 365ULL
#define LH_VOLUME_CREATION_MIN_AGE_SECONDS (30ULL * LH_SECONDS_PER_DAY)
#define LH_VOLUME_CREATION_MAX_AGE_SECONDS (2ULL * LH_DAYS_PER_YEAR * LH_SECONDS_PER_DAY)

/** Copies the synthetic volume creation timestamp owned by the storage mitigation. */
bool LHVolumeCreationTimeCopySyntheticTimestamp(const LHPolicyEngine *engine, double *volumeCreationTime) {
    if (engine == 0 || volumeCreationTime == 0) {
        return false;
    }

    return LHMitigationCopyStablePastTime(engine,
                                          &LHGeneratedPolicySeed_volume_creation_date,
                                          1,
                                          LH_VOLUME_CREATION_MIN_AGE_SECONDS,
                                          LH_VOLUME_CREATION_MAX_AGE_SECONDS,
                                          volumeCreationTime);
}
