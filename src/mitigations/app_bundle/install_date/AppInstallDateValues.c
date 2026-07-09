#include "AppInstallDateValues.h"

#include "LHMitigationValues.h"

#include <time.h>

LH_POLICY_SEED(app_install_date)
LH_POLICY_SEED(volume_creation_date)

#define LH_SECONDS_PER_HOUR 3600ULL
#define LH_SECONDS_PER_DAY 86400ULL
#define LH_DAYS_PER_YEAR 365ULL
#define LH_APP_INSTALL_LOOKBACK_SECONDS (90ULL * LH_SECONDS_PER_DAY)
#define LH_APP_INSTALL_MIN_AGE_SECONDS LH_SECONDS_PER_HOUR
#define LH_APP_INSTALL_MIN_AFTER_VOLUME_SECONDS LH_SECONDS_PER_DAY
#define LH_VOLUME_CREATION_MIN_AGE_SECONDS (30ULL * LH_SECONDS_PER_DAY)
#define LH_VOLUME_CREATION_MAX_AGE_SECONDS (2ULL * LH_DAYS_PER_YEAR * LH_SECONDS_PER_DAY)

static bool LHAppInstallDateCopyVolumeCreationBaseline(const LHPolicyEngine *engine, double *volumeCreationTime) {
    return LHMitigationCopyStablePastTime(engine,
                                          &LHGeneratedPolicySeed_volume_creation_date,
                                          1,
                                          LH_VOLUME_CREATION_MIN_AGE_SECONDS,
                                          LH_VOLUME_CREATION_MAX_AGE_SECONDS,
                                          volumeCreationTime);
}

/** Copies a stable app-install timestamp after the synthetic volume baseline and before now. */
bool LHAppInstallDateCopySyntheticTimestamp(const LHPolicyEngine *engine, double *installTime) {
    if (engine == 0 || installTime == 0) {
        return false;
    }

    time_t now = time(0);
    double volumeCreationTime = 0.0;
    if (now <= 0 || !LHAppInstallDateCopyVolumeCreationBaseline(engine, &volumeCreationTime)) {
        return false;
    }

    double lowerBound = (double)now - (double)LH_APP_INSTALL_LOOKBACK_SECONDS;
    double volumeBound = volumeCreationTime + (double)LH_APP_INSTALL_MIN_AFTER_VOLUME_SECONDS;
    if (lowerBound < volumeBound) {
        lowerBound = volumeBound;
    }

    double upperBound = (double)now - (double)LH_APP_INSTALL_MIN_AGE_SECONDS;
    if (!(upperBound > lowerBound)) {
        return false;
    }

    return LHMitigationCopyStableTimeIntervalBetween(engine,
                                                     &LHGeneratedPolicySeed_app_install_date,
                                                     1,
                                                     lowerBound,
                                                     upperBound,
                                                     installTime);
}
