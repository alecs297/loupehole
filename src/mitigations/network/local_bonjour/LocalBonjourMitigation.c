#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include <dlfcn.h>

typedef void (*LHNWBrowserStartOriginal)(void *browser, void *queue);

static LHNWBrowserStartOriginal LHNWBrowserStartOriginalImplementation;

/** Replacement for Network.framework browser starts. It leaves the browser unstated and result-free. */
static void LHNWBrowserStartReplacement(void *browser, void *queue) {
    (void)browser;
    (void)queue;
}

/** Installs strict suppression for Network.framework Bonjour/local-service browsing starts. */
bool LHMitigation_network_local_bonjour_nwbrowser_suppress_start_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    void *target = dlsym(RTLD_DEFAULT, "nw_browser_start");
    bool installed = false;
    if (target != 0) {
        installed = LHHookBackendHookFunction(backend, target, (void *)LHNWBrowserStartReplacement, (void **)&LHNWBrowserStartOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend, "nw_browser_start", (void *)LHNWBrowserStartReplacement, (void **)&LHNWBrowserStartOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_network_local_bonjour_nwbrowser_suppress_start);
    }

    return true;
}
