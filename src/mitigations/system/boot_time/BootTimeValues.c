#include "BootTimeValues.h"

#include "LHMitigationValues.h"

#include <string.h>
#include <time.h>

LH_POLICY_SEED(boot_time_state)
LH_POLICY_SEED(boot_time)
LH_POLICY_SEED(volume_creation_date)

#define LH_SECONDS_PER_HOUR 3600ULL
#define LH_SECONDS_PER_DAY 86400ULL
#define LH_MIN_BOOT_AGE_SECONDS (6ULL * LH_SECONDS_PER_HOUR)
#define LH_BOOT_LOOKBACK_SECONDS (14ULL * LH_SECONDS_PER_DAY)
#define LH_MIN_BOOT_AFTER_VOLUME_SECONDS (7ULL * LH_SECONDS_PER_DAY)
#define LH_VOLUME_CREATION_EARLIEST_UNIX 1577836800.0
#define LH_VOLUME_CREATION_LATEST_UNIX 1735689600.0

typedef struct LHBootTimeState {
    struct timeval bootTime;
} LHBootTimeState;

/** Derives the volume-creation baseline used to keep boot time coherent. */
static bool LHBootTimeCopyVolumeCreationBaseline(const LHRuntimeConfig *config,
                                                 const LHAppContext *context,
                                                 double *volumeCreationTime) {
    if (config == 0 || context == 0 || volumeCreationTime == 0) {
        return false;
    }

    return LHMitigationDeriveTimeIntervalBetween(&config->buildSeed,
                                                 &LHGeneratedPolicySeed_volume_creation_date,
                                                 &context->scope,
                                                 LH_VOLUME_CREATION_EARLIEST_UNIX,
                                                 LH_VOLUME_CREATION_LATEST_UNIX,
                                                 volumeCreationTime);
}

/** Generates the persisted boot-time state blob. */
static bool LHBootTimeGenerateState(const LHRuntimeConfig *config,
                                    const LHAppContext *context,
                                    void *generatorContext,
                                    uint8_t *output,
                                    size_t outputLength) {
    (void)generatorContext;
    if (config == 0 || context == 0 || output == 0 || outputLength != sizeof(LHBootTimeState)) {
        return false;
    }

    time_t now = time(0);
    double volumeCreationTime = 0.0;
    if (now <= 0 || !LHBootTimeCopyVolumeCreationBaseline(config, context, &volumeCreationTime)) {
        return false;
    }

    double lowerBound = (double)now - (double)LH_BOOT_LOOKBACK_SECONDS;
    double volumeBound = volumeCreationTime + (double)LH_MIN_BOOT_AFTER_VOLUME_SECONDS;
    if (lowerBound < volumeBound) {
        lowerBound = volumeBound;
    }

    double upperBound = (double)now - (double)LH_MIN_BOOT_AGE_SECONDS;
    double bootTimestamp = 0.0;
    if (!LHMitigationDeriveTimeIntervalBetween(&config->buildSeed,
                                               &LHGeneratedPolicySeed_boot_time,
                                               &context->scope,
                                               lowerBound,
                                               upperBound,
                                               &bootTimestamp)) {
        return false;
    }

    LHBootTimeState state;
    memset(&state, 0, sizeof(state));
    state.bootTime.tv_sec = (time_t)bootTimestamp;
    state.bootTime.tv_usec = 0;
    if (!((double)state.bootTime.tv_sec > volumeCreationTime && state.bootTime.tv_sec < now)) {
        return false;
    }

    memcpy(output, &state, sizeof(state));
    return true;
}

/** Loads or creates the boot-time mitigation state. */
static bool LHBootTimeLoadState(const LHPolicyEngine *engine, LHBootTimeState *state) {
    if (state == 0) {
        return false;
    }

    LHStateKey key = LHMitigationStateKeyFromPolicySeed(&LHGeneratedPolicySeed_boot_time_state, 1);
    return LHPolicyEngineLoadOrCreateState(engine,
                                           &key,
                                           (uint8_t *)state,
                                           sizeof(*state),
                                           LHBootTimeGenerateState,
                                           0,
                                           0);
}

/** Copies the synthetic boot time owned by the boot-time mitigation. */
bool LHBootTimeCopySyntheticBootTime(const LHPolicyEngine *engine, struct timeval *bootTime) {
    if (bootTime == 0) {
        return false;
    }

    LHBootTimeState state;
    if (!LHBootTimeLoadState(engine, &state)) {
        return false;
    }

    *bootTime = state.bootTime;
    return true;
}
