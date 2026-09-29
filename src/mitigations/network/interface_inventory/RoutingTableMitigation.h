#ifndef LH_ROUTING_TABLE_MITIGATION_H
#define LH_ROUTING_TABLE_MITIGATION_H

#include "LHHookBackend.h"
#include "LHPolicyEngine.h"

#ifdef __cplusplus
extern "C" {
#endif

LH_INTERNAL bool LHInterfaceInventoryInstallRoutingHooks(LHHookBackend *backend,
                                                         LHPolicyEngine *policy);

#ifdef __cplusplus
}
#endif

#endif
