#ifndef LH_PROFILE_H
#define LH_PROFILE_H

#include "LHBuildConfig.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LHProfile {
    uint32_t version;
    uint32_t stateSchemaVersion;
} LHProfile;

LH_INTERNAL const LHProfile *LHProfileDefault(void);

#ifdef __cplusplus
}
#endif

#endif
