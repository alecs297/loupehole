#ifndef LH_APP_INSTALL_DATE_VALUES_H
#define LH_APP_INSTALL_DATE_VALUES_H

#include "LHBuildConfig.h"
#include "LHPolicyEngine.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Copies the synthetic current app-install timestamp shared by app-bundle and install-history mitigations. */
LH_INTERNAL bool LHAppInstallDateCopySyntheticTimestamp(const LHPolicyEngine *engine, double *installTime);

#ifdef __cplusplus
}
#endif

#endif
