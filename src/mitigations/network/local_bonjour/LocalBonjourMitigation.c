#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include <dlfcn.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>

typedef void *(*LHNWBrowserCreateOriginal)(void *descriptor, void *parameters);
typedef const char *(*LHNWBrowseDescriptorGetBonjourServiceType)(void *descriptor);
typedef void (*LHNWBrowserStartOriginal)(void *browser);
typedef void (^LHNWBrowserBrowseResultsChangedHandler)(void *oldResult, void *newResult, bool batchComplete);
typedef void (*LHNWBrowserSetBrowseResultsChangedHandlerOriginal)(void *browser, LHNWBrowserBrowseResultsChangedHandler handler);
typedef void (^LHNWBrowserStateChangedHandler)(int state, void *error);
typedef void (*LHNWBrowserSetStateChangedHandlerOriginal)(void *browser, LHNWBrowserStateChangedHandler handler);

static LHNWBrowserCreateOriginal LHNWBrowserCreateOriginalImplementation;
static LHNWBrowserStartOriginal LHNWBrowserStartOriginalImplementation;
static LHNWBrowserSetBrowseResultsChangedHandlerOriginal LHNWBrowserSetBrowseResultsChangedHandlerOriginalImplementation;
static LHNWBrowserSetStateChangedHandlerOriginal LHNWBrowserSetStateChangedHandlerOriginalImplementation;
static LHNWBrowseDescriptorGetBonjourServiceType LHNWBrowseDescriptorGetBonjourServiceTypeImplementation;

typedef struct LHNWBrowserProfile {
    void *browser;
    bool passThrough;
} LHNWBrowserProfile;

static LHNWBrowserProfile LHNWBrowserProfiles[32];

static bool LHNWBrowserServiceTypeIsPermissionProbe(const char *type) {
    return type != 0 && strcmp(type, "_loupe-probe._tcp") == 0;
}

static bool LHNWBrowserDescriptorIsPermissionProbe(void *descriptor) {
    if (descriptor == 0 || LHNWBrowseDescriptorGetBonjourServiceTypeImplementation == 0) {
        return false;
    }

    const char *type = LHNWBrowseDescriptorGetBonjourServiceTypeImplementation(descriptor);
    return LHNWBrowserServiceTypeIsPermissionProbe(type);
}

static void LHNWBrowserRememberProfile(void *browser, bool passThrough) {
    if (browser == 0) {
        return;
    }

    for (size_t i = 0; i < sizeof(LHNWBrowserProfiles) / sizeof(LHNWBrowserProfiles[0]); i++) {
        if (LHNWBrowserProfiles[i].browser == browser || LHNWBrowserProfiles[i].browser == 0) {
            LHNWBrowserProfiles[i].browser = browser;
            LHNWBrowserProfiles[i].passThrough = passThrough;
            return;
        }
    }
}

static bool LHNWBrowserShouldPassThrough(void *browser) {
    for (size_t i = 0; i < sizeof(LHNWBrowserProfiles) / sizeof(LHNWBrowserProfiles[0]); i++) {
        if (LHNWBrowserProfiles[i].browser == browser) {
            return LHNWBrowserProfiles[i].passThrough;
        }
    }
    return false;
}

static void *LHNWBrowserCreateReplacement(void *descriptor, void *parameters) {
    if (LHNWBrowserCreateOriginalImplementation == 0) {
        return 0;
    }

    void *browser = LHNWBrowserCreateOriginalImplementation(descriptor, parameters);
    LHNWBrowserRememberProfile(browser, LHNWBrowserDescriptorIsPermissionProbe(descriptor));
    return browser;
}

static void LHNWBrowserStartReplacement(void *browser) {
    if (LHNWBrowserStartOriginalImplementation != 0) {
        LHNWBrowserStartOriginalImplementation(browser);
    }
}

/** Replacement for Network.framework browse-result handlers. It preserves browser state but delivers no local-service results. */
static void LHNWBrowserSetBrowseResultsChangedHandlerReplacement(void *browser, LHNWBrowserBrowseResultsChangedHandler handler) {
    if (LHNWBrowserSetBrowseResultsChangedHandlerOriginalImplementation == 0) {
        return;
    }
    if (handler == 0 || LHNWBrowserShouldPassThrough(browser)) {
        LHNWBrowserSetBrowseResultsChangedHandlerOriginalImplementation(browser, handler);
        return;
    }

    LHNWBrowserBrowseResultsChangedHandler emptyHandler = ^(void *oldResult, void *newResult, bool batchComplete) {
        (void)oldResult;
        (void)newResult;
        (void)batchComplete;
        handler(0, 0, true);
    };
    LHNWBrowserSetBrowseResultsChangedHandlerOriginalImplementation(browser, emptyHandler);
}

/** Replacement for Network.framework browser state handlers. Inventory browsers should not surface denial/error shapes. */
static void LHNWBrowserSetStateChangedHandlerReplacement(void *browser, LHNWBrowserStateChangedHandler handler) {
    if (LHNWBrowserSetStateChangedHandlerOriginalImplementation == 0) {
        return;
    }
    if (handler == 0 || LHNWBrowserShouldPassThrough(browser)) {
        LHNWBrowserSetStateChangedHandlerOriginalImplementation(browser, handler);
        return;
    }

    LHNWBrowserStateChangedHandler shapedHandler = ^(int state, void *error) {
        if (state == 2 || state == 3 || state == 4) {
            handler(1, 0);
            return;
        }
        handler(state, error);
    };
    LHNWBrowserSetStateChangedHandlerOriginalImplementation(browser, shapedHandler);
}

/** Installs empty-result filtering for Network.framework Bonjour/local-service browsing. */
bool LHMitigation_network_local_bonjour_nwbrowser_empty_results_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    LHNWBrowseDescriptorGetBonjourServiceTypeImplementation = (LHNWBrowseDescriptorGetBonjourServiceType)dlsym(RTLD_DEFAULT, "nw_browse_descriptor_get_bonjour_service_type");

    bool installed = false;

    void *createTarget = dlsym(RTLD_DEFAULT, "nw_browser_create");
    if (createTarget != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              createTarget,
                                              (void *)LHNWBrowserCreateReplacement,
                                              (void **)&LHNWBrowserCreateOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "nw_browser_create",
                                                (void *)LHNWBrowserCreateReplacement,
                                                (void **)&LHNWBrowserCreateOriginalImplementation) || installed;

    void *startTarget = dlsym(RTLD_DEFAULT, "nw_browser_start");
    if (startTarget != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              startTarget,
                                              (void *)LHNWBrowserStartReplacement,
                                              (void **)&LHNWBrowserStartOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "nw_browser_start",
                                                (void *)LHNWBrowserStartReplacement,
                                                (void **)&LHNWBrowserStartOriginalImplementation) || installed;

    void *resultHandlerTarget = dlsym(RTLD_DEFAULT, "nw_browser_set_browse_results_changed_handler");
    if (resultHandlerTarget != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              resultHandlerTarget,
                                              (void *)LHNWBrowserSetBrowseResultsChangedHandlerReplacement,
                                              (void **)&LHNWBrowserSetBrowseResultsChangedHandlerOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "nw_browser_set_browse_results_changed_handler",
                                                (void *)LHNWBrowserSetBrowseResultsChangedHandlerReplacement,
                                                (void **)&LHNWBrowserSetBrowseResultsChangedHandlerOriginalImplementation) || installed;

    void *stateHandlerTarget = dlsym(RTLD_DEFAULT, "nw_browser_set_state_changed_handler");
    if (stateHandlerTarget != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              stateHandlerTarget,
                                              (void *)LHNWBrowserSetStateChangedHandlerReplacement,
                                              (void **)&LHNWBrowserSetStateChangedHandlerOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "nw_browser_set_state_changed_handler",
                                                (void *)LHNWBrowserSetStateChangedHandlerReplacement,
                                                (void **)&LHNWBrowserSetStateChangedHandlerOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_network_local_bonjour_nwbrowser_empty_results);
    }

    return true;
}
