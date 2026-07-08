#import "LHRuntime.h"

#include "LHHookBackend.h"
#include "LHModuleRegistry.h"
#include "LHPolicyEngine.h"

#import <stdatomic.h>

void LHRuntimeStart(void) {
    static atomic_bool started = false;
    bool expected = false;
    if (!atomic_compare_exchange_strong(&started, &expected, true)) {
        return;
    }

    static LHPolicyEngine policy;
    if (!LHPolicyEngineInit(&policy)) {
        return;
    }

    LHHookBackend backend = LHHookBackendCreateTheos();
    (void)LHModuleRegistryInstall(&backend, &policy);
}
