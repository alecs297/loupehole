#ifndef LH_INTERFACE_TRAFFIC_MITIGATION_H
#define LH_INTERFACE_TRAFFIC_MITIGATION_H

#include "InterfaceTrafficValues.h"
#include "LHHookBackend.h"

#include <ifaddrs.h>

void LHInterfaceInventoryRewriteEntry(struct ifaddrs *entry);
void LHInterfaceInventoryRewriteSensitiveEntryName(struct ifaddrs *entry);
void LHInterfaceTrafficBeginOriginalList(void);
void LHInterfaceTrafficEndOriginalList(void);
bool LHInterfaceTrafficShapeBuffer(LHPolicyEngine *policy, void *buffer, size_t length,
                                   int query, const LHInterfaceTrafficSnapshot *snapshot);
bool LHInterfaceInventoryInstallTrafficHooks(LHHookBackend *backend, LHPolicyEngine *policy);

#endif
