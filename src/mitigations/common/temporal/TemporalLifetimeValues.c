#include "common/temporal/TemporalLifetimeValues.h"

#include "LHMitigationValues.h"

#include <string.h>
#include <time.h>

LH_POLICY_SEED(temporal_lifetime, state, "temporal_lifetime_state")
LH_POLICY_SEED(temporal_lifetime, boot_time, "boot_time")
LH_POLICY_SEED(temporal_lifetime, volume_creation_date, "volume_creation_date")

#define LH_SECONDS_PER_HOUR 3600ULL
#define LH_SECONDS_PER_DAY 86400ULL
#define LH_MIN_BOOT_AGE_SECONDS (6ULL * LH_SECONDS_PER_HOUR)
#define LH_BOOT_AGE_WINDOW_SECONDS (14ULL * LH_SECONDS_PER_DAY)
#define LH_MIN_VOLUME_BEFORE_BOOT_SECONDS (7ULL * LH_SECONDS_PER_DAY)
#define LH_VOLUME_BEFORE_BOOT_WINDOW_SECONDS (180ULL * LH_SECONDS_PER_DAY)

typedef struct LHTemporalLifetimeState {
    struct timeval bootTime;
    double volumeCreationTime;
} LHTemporalLifetimeState;

/** Generates the boot time from practical and policy seed material. */
static bool LHTemporalGenerateBootTime(const LHRuntimeConfig *config,
                                       const LHAppContext *context,
                                       time_t now,
                                       struct timeval *bootTime) {
    uint64_t seedValue = 0;
    if (bootTime == 0 ||
        !LHMitigationDeriveU64(&config->buildSeed,
                          &LHGeneratedPolicySeed_temporal_lifetime_boot_time,
                          &context->scope,
                          0,
                          0,
                          &seedValue)) {
        return false;
    }

    uint64_t bootAge = LH_MIN_BOOT_AGE_SECONDS + (seedValue % LH_BOOT_AGE_WINDOW_SECONDS);
    bootTime->tv_sec = now - (time_t)bootAge;
    bootTime->tv_usec = 0;
    return bootTime->tv_sec > 0;
}

/** Generates a volume creation timestamp that remains older than boot time. */
static bool LHTemporalGenerateVolumeCreationTime(const LHRuntimeConfig *config,
                                                 const LHAppContext *context,
                                                 time_t now,
                                                 double *volumeCreationTime) {
    struct timeval bootTime;
    uint64_t offsetSeed = 0;
    if (volumeCreationTime == 0 ||
        !LHTemporalGenerateBootTime(config, context, now, &bootTime) ||
        !LHMitigationDeriveU64(&config->buildSeed,
                          &LHGeneratedPolicySeed_temporal_lifetime_volume_creation_date,
                          &context->scope,
                          0,
                          0,
                          &offsetSeed)) {
        return false;
    }

    uint64_t offset = LH_MIN_VOLUME_BEFORE_BOOT_SECONDS + (offsetSeed % LH_VOLUME_BEFORE_BOOT_WINDOW_SECONDS);
    *volumeCreationTime = (double)(bootTime.tv_sec - (time_t)offset);
    return *volumeCreationTime < (double)bootTime.tv_sec;
}

/** Generates the persisted temporal-lifetime state blob. */
static bool LHTemporalGenerateState(const LHRuntimeConfig *config,
                                    const LHAppContext *context,
                                    void *generatorContext,
                                    uint8_t *output,
                                    size_t outputLength) {
    (void)generatorContext;
    if (config == 0 || context == 0 || output == 0 || outputLength != sizeof(LHTemporalLifetimeState)) {
        return false;
    }

    LHTemporalLifetimeState state;
    memset(&state, 0, sizeof(state));
    time_t now = time(0);
    if (!LHTemporalGenerateBootTime(config, context, now, &state.bootTime) ||
        !LHTemporalGenerateVolumeCreationTime(config, context, now, &state.volumeCreationTime)) {
        return false;
    }

    if (!(state.volumeCreationTime < (double)state.bootTime.tv_sec)) {
        return false;
    }

    memcpy(output, &state, sizeof(state));
    return true;
}

/** Loads or creates the shared temporal-lifetime state. */
static bool LHTemporalLoadState(const LHPolicyEngine *engine, LHTemporalLifetimeState *state) {
    if (state == 0) {
        return false;
    }

    LHStateKey key = LHMitigationStateKeyFromPolicySeed(&LHGeneratedPolicySeed_temporal_lifetime_state, 1);
    return LHPolicyEngineLoadOrCreateState(engine,
                                           &key,
                                           (uint8_t *)state,
                                           sizeof(*state),
                                           LHTemporalGenerateState,
                                           0,
                                           0);
}

/** Copies the coherent synthetic boot time from temporal lifetime state. */
bool LHTemporalLifetimeCopyBootTime(const LHPolicyEngine *engine, struct timeval *bootTime) {
    if (bootTime == 0) {
        return false;
    }

    LHTemporalLifetimeState state;
    if (!LHTemporalLoadState(engine, &state)) {
        return false;
    }

    *bootTime = state.bootTime;
    return true;
}

/** Copies the coherent synthetic volume creation timestamp from temporal lifetime state. */
bool LHTemporalLifetimeCopyVolumeCreationTime(const LHPolicyEngine *engine, double *volumeCreationTime) {
    if (volumeCreationTime == 0) {
        return false;
    }

    LHTemporalLifetimeState state;
    if (!LHTemporalLoadState(engine, &state)) {
        return false;
    }

    *volumeCreationTime = state.volumeCreationTime;
    return true;
}
