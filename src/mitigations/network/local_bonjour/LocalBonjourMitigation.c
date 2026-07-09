#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include <dlfcn.h>
#include <stdbool.h>

typedef void (^LHNWBrowserBrowseResultsChangedHandler)(void *results, void *changes, bool complete);
typedef void (*LHNWBrowserSetBrowseResultsChangedHandlerOriginal)(void *browser, LHNWBrowserBrowseResultsChangedHandler handler);

static LHNWBrowserSetBrowseResultsChangedHandlerOriginal LHNWBrowserSetBrowseResultsChangedHandlerOriginalImplementation;

/** Replacement for Network.framework browse-result handlers. It preserves browser state but delivers no local-service results. */
static void LHNWBrowserSetBrowseResultsChangedHandlerReplacement(void *browser, LHNWBrowserBrowseResultsChangedHandler handler) {
    (void)handler;
    if (LHNWBrowserSetBrowseResultsChangedHandlerOriginalImplementation == 0) {
        return;
    }

    LHNWBrowserBrowseResultsChangedHandler emptyHandler = ^(void *results, void *changes, bool complete) {
        (void)results;
        (void)changes;
        (void)complete;
    };
    LHNWBrowserSetBrowseResultsChangedHandlerOriginalImplementation(browser, emptyHandler);
}

/** Installs empty-result filtering for Network.framework Bonjour/local-service browsing. */
bool LHMitigation_network_local_bonjour_nwbrowser_empty_results_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    void *target = dlsym(RTLD_DEFAULT, "nw_browser_set_browse_results_changed_handler");
    bool installed = false;
    if (target != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              target,
                                              (void *)LHNWBrowserSetBrowseResultsChangedHandlerReplacement,
                                              (void **)&LHNWBrowserSetBrowseResultsChangedHandlerOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "nw_browser_set_browse_results_changed_handler",
                                                (void *)LHNWBrowserSetBrowseResultsChangedHandlerReplacement,
                                                (void **)&LHNWBrowserSetBrowseResultsChangedHandlerOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_network_local_bonjour_nwbrowser_empty_results);
    }

    return true;
}
