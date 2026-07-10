#ifndef LH_RUNTIME_H
#define LH_RUNTIME_H

#include "LHBuildConfig.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Starts the runtime once for the current injected process. */
LH_INTERNAL void LHRuntimeStart(void);

#ifdef __cplusplus
}
#endif

#endif
