#ifndef LH_INTERFACE_TRAFFIC_VALUES_H
#define LH_INTERFACE_TRAFFIC_VALUES_H

#include "LHPolicyEngine.h"

#include <net/if.h>
#include <net/if_var.h>
#include <stdint.h>
#include <sys/time.h>

typedef struct LHInterfaceTrafficSnapshot {
    uint64_t elapsedMicroseconds;
    time_t bootSeconds;
} LHInterfaceTrafficSnapshot;

typedef struct LHInterfaceTrafficValues {
    uint64_t inboundBytes;
    uint64_t outboundBytes;
    uint64_t inboundPackets;
    uint64_t outboundPackets;
    uint32_t inboundErrors;
    uint32_t outboundErrors;
    uint32_t inputDrops;
    uint32_t unsupportedPackets;
} LHInterfaceTrafficValues;

bool LHInterfaceTrafficCopySnapshot(LHInterfaceTrafficSnapshot *snapshot);
bool LHInterfaceTrafficCopyValues(LHPolicyEngine *policy, const char *name,
                                  const LHInterfaceTrafficSnapshot *snapshot,
                                  LHInterfaceTrafficValues *values);
void LHInterfaceTrafficApply32(struct if_data *data, const char *name,
                               const LHInterfaceTrafficSnapshot *snapshot,
                               const LHInterfaceTrafficValues *values);
void LHInterfaceTrafficApply64(struct if_data64 *data, const char *name,
                               const LHInterfaceTrafficSnapshot *snapshot,
                               const LHInterfaceTrafficValues *values);

#endif
