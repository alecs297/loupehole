#include "LHPolicyEngine.h"

#include <string.h>
#include <time.h>

LH_DERIVATION_LABEL(temporal_lifetime, state)
LH_DERIVATION_LABEL(temporal_lifetime, boot_anchor)
LH_DERIVATION_LABEL(temporal_lifetime, volume_before_boot_offset)
LH_DERIVATION_LABEL(temporal_lifetime, profile_before_volume_offset)

#define LH_SECONDS_PER_HOUR 3600ULL
#define LH_SECONDS_PER_DAY 86400ULL
#define LH_MIN_BOOT_AGE_SECONDS (6ULL * LH_SECONDS_PER_HOUR)
#define LH_BOOT_AGE_WINDOW_SECONDS (14ULL * LH_SECONDS_PER_DAY)
#define LH_MIN_VOLUME_BEFORE_BOOT_SECONDS (7ULL * LH_SECONDS_PER_DAY)
#define LH_VOLUME_BEFORE_BOOT_WINDOW_SECONDS (180ULL * LH_SECONDS_PER_DAY)
#define LH_PROFILE_BEFORE_VOLUME_WINDOW_SECONDS (30ULL * LH_SECONDS_PER_DAY)

typedef struct LHTemporalLifetimeState {
    struct timeval bootTime;
    double volumeCreationTime;
    double profileEpoch;
} LHTemporalLifetimeState;

static uint64_t LHReadU64(const uint8_t *bytes) {
    uint64_t value = 0;
    for (size_t i = 0; i < sizeof(value); i++) {
        value |= ((uint64_t)bytes[i]) << (i * 8);
    }
    return value;
}

static LHStateKey LHTemporalStateKey(void) {
    LHStateKey key = {
        .schemaVersion = 1
    };
    key.label = LHGeneratedDerivationLabel_temporal_lifetime_state;
    return key;
}

static bool LHTemporalDeriveU64(const LHRuntimeConfig *config,
                                const LHAppContext *context,
                                const LHDerivationLabel *label,
                                uint64_t *value) {
    uint8_t bytes[8] = { 0 };
    if (value == 0 || !LHSeedDeriveBytes(&config->instanceSeed, label, &context->scope, bytes, sizeof(bytes))) {
        return false;
    }

    *value = LHReadU64(bytes);
    return true;
}

static bool LHTemporalGenerateBootTime(const LHRuntimeConfig *config,
                                       const LHAppContext *context,
                                       time_t now,
                                       struct timeval *bootTime) {
    uint64_t seedValue = 0;
    if (bootTime == 0 || !LHTemporalDeriveU64(config, context, &LHGeneratedDerivationLabel_temporal_lifetime_boot_anchor, &seedValue)) {
        return false;
    }

    uint64_t bootAge = LH_MIN_BOOT_AGE_SECONDS + (seedValue % LH_BOOT_AGE_WINDOW_SECONDS);
    bootTime->tv_sec = now - (time_t)bootAge;
    bootTime->tv_usec = 0;
    return bootTime->tv_sec > 0;
}

static bool LHTemporalGenerateVolumeCreationTime(const LHRuntimeConfig *config,
                                                 const LHAppContext *context,
                                                 time_t now,
                                                 double *volumeCreationTime) {
    struct timeval bootTime;
    uint64_t offsetSeed = 0;
    if (volumeCreationTime == 0 ||
        !LHTemporalGenerateBootTime(config, context, now, &bootTime) ||
        !LHTemporalDeriveU64(config, context, &LHGeneratedDerivationLabel_temporal_lifetime_volume_before_boot_offset, &offsetSeed)) {
        return false;
    }

    uint64_t offset = LH_MIN_VOLUME_BEFORE_BOOT_SECONDS + (offsetSeed % LH_VOLUME_BEFORE_BOOT_WINDOW_SECONDS);
    *volumeCreationTime = (double)(bootTime.tv_sec - (time_t)offset);
    return *volumeCreationTime < (double)bootTime.tv_sec;
}

static bool LHTemporalGenerateProfileEpoch(const LHRuntimeConfig *config,
                                           const LHAppContext *context,
                                           time_t now,
                                           double *profileEpoch) {
    double volumeCreationTime = 0.0;
    uint64_t offsetSeed = 0;
    if (profileEpoch == 0 ||
        !LHTemporalGenerateVolumeCreationTime(config, context, now, &volumeCreationTime) ||
        !LHTemporalDeriveU64(config, context, &LHGeneratedDerivationLabel_temporal_lifetime_profile_before_volume_offset, &offsetSeed)) {
        return false;
    }

    *profileEpoch = volumeCreationTime - (double)(offsetSeed % LH_PROFILE_BEFORE_VOLUME_WINDOW_SECONDS);
    return *profileEpoch <= volumeCreationTime;
}

static bool LHTemporalGenerateState(const LHRuntimeConfig *config,
                                    const LHAppContext *context,
                                    void *generatorContext,
                                    uint8_t *output,
                                    size_t outputLength) {
    (void)generatorContext;
    if (outputLength != sizeof(LHTemporalLifetimeState)) {
        return false;
    }

    LHTemporalLifetimeState state;
    memset(&state, 0, sizeof(state));
    time_t now = time(0);
    if (!LHTemporalGenerateBootTime(config, context, now, &state.bootTime) ||
        !LHTemporalGenerateVolumeCreationTime(config, context, now, &state.volumeCreationTime) ||
        !LHTemporalGenerateProfileEpoch(config, context, now, &state.profileEpoch)) {
        return false;
    }

    if (!(state.profileEpoch <= state.volumeCreationTime &&
          state.volumeCreationTime < (double)state.bootTime.tv_sec)) {
        return false;
    }

    memcpy(output, &state, sizeof(state));
    return true;
}

static bool LHTemporalLoadState(const LHPolicyEngine *engine, LHTemporalLifetimeState *state) {
    if (state == 0) {
        return false;
    }

    LHStateKey key = LHTemporalStateKey();
    return LHPolicyEngineLoadOrCreateState(engine,
                                           &key,
                                           (uint8_t *)state,
                                           sizeof(*state),
                                           LHTemporalGenerateState,
                                           0,
                                           0);
}

bool LHPolicyResolve_boot_time(const LHPolicyEngine *engine,
                               const LHPolicyValueRequest *request,
                               LHPolicyValueResponse *response) {
    if (request == 0 || request->output == 0 || request->expectedKind != LHPolicyValueKindTimeval) {
        return false;
    }
    if (request->outputLength < sizeof(struct timeval)) {
        return false;
    }

    LHTemporalLifetimeState state;
    if (!LHTemporalLoadState(engine, &state)) {
        return false;
    }

    memcpy(request->output, &state.bootTime, sizeof(state.bootTime));
    if (response != 0) {
        response->kind = LHPolicyValueKindTimeval;
        response->bytesWritten = sizeof(state.bootTime);
    }
    return true;
}

bool LHPolicyResolve_volume_creation_time(const LHPolicyEngine *engine,
                                          const LHPolicyValueRequest *request,
                                          LHPolicyValueResponse *response) {
    if (request == 0 || request->output == 0 || request->expectedKind != LHPolicyValueKindTimeInterval) {
        return false;
    }
    if (request->outputLength < sizeof(double)) {
        return false;
    }

    LHTemporalLifetimeState state;
    if (!LHTemporalLoadState(engine, &state)) {
        return false;
    }

    memcpy(request->output, &state.volumeCreationTime, sizeof(state.volumeCreationTime));
    if (response != 0) {
        response->kind = LHPolicyValueKindTimeInterval;
        response->bytesWritten = sizeof(state.volumeCreationTime);
    }
    return true;
}
