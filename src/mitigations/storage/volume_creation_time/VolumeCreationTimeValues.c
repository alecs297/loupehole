#include "VolumeCreationTimeValues.h"

#include "LHMitigationValues.h"

LH_POLICY_SEED(volume_creation_date)

#define LH_VOLUME_CREATION_EARLIEST_UNIX 1577836800.0
#define LH_VOLUME_CREATION_LATEST_UNIX 1735689600.0

/** Copies the synthetic volume creation timestamp owned by the storage mitigation. */
bool LHVolumeCreationTimeCopySyntheticTimestamp(const LHPolicyEngine *engine, double *volumeCreationTime) {
    if (engine == 0 || volumeCreationTime == 0) {
        return false;
    }

    return LHMitigationDeriveTimeIntervalBetween(&engine->config.buildSeed,
                                                 &LHGeneratedPolicySeed_volume_creation_date,
                                                 &engine->appContext.scope,
                                                 LH_VOLUME_CREATION_EARLIEST_UNIX,
                                                 LH_VOLUME_CREATION_LATEST_UNIX,
                                                 volumeCreationTime);
}
