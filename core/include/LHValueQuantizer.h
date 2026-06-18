#ifndef LH_VALUE_QUANTIZER_H
#define LH_VALUE_QUANTIZER_H

#include "LHBuildConfig.h"
#include "LHTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

LH_INTERNAL uint64_t LHValueQuantizeDown(uint64_t value, uint64_t bucketSize);

#ifdef __cplusplus
}
#endif

#endif
