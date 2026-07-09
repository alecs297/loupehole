#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include <dlfcn.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>

typedef void *(*LHNWBrowserCreateOriginal)(void *descriptor, void *parameters);
typedef void *(*LHNWBrowseDescriptorCreateBonjourServiceOriginal)(const char *type, const char *domain);
typedef const char *(*LHNWBrowseDescriptorGetBonjourServiceType)(void *descriptor);
typedef void (^LHNWBrowserBrowseResultsChangedHandler)(void *oldResult, void *newResult, bool batchComplete);
typedef void (*LHNWBrowserSetBrowseResultsChangedHandlerOriginal)(void *browser, LHNWBrowserBrowseResultsChangedHandler handler);

extern void *_Block_copy(const void *block);

static LHNWBrowseDescriptorCreateBonjourServiceOriginal LHNWBrowseDescriptorCreateBonjourServiceOriginalImplementation;
static LHNWBrowserCreateOriginal LHNWBrowserCreateOriginalImplementation;
static LHNWBrowserSetBrowseResultsChangedHandlerOriginal LHNWBrowserSetBrowseResultsChangedHandlerOriginalImplementation;
static LHNWBrowseDescriptorGetBonjourServiceType LHNWBrowseDescriptorGetBonjourServiceTypeImplementation;

typedef struct LHNWDescriptorProfile {
    void *descriptor;
    bool passThrough;
} LHNWDescriptorProfile;

typedef struct LHNWBrowserProfile {
    void *browser;
    bool passThrough;
} LHNWBrowserProfile;

static LHNWDescriptorProfile LHNWDescriptorProfiles[32];
static LHNWBrowserProfile LHNWBrowserProfiles[32];

static bool LHNWBrowserServiceTypeIsPermissionProbe(const char *type) {
    return type != 0 && strcmp(type, "_loupe-probe._tcp") == 0;
}

static void LHNWDescriptorRememberProfile(void *descriptor, bool passThrough) {
    if (descriptor == 0) {
        return;
    }

    for (size_t i = 0; i < sizeof(LHNWDescriptorProfiles) / sizeof(LHNWDescriptorProfiles[0]); i++) {
        if (LHNWDescriptorProfiles[i].descriptor == descriptor || LHNWDescriptorProfiles[i].descriptor == 0) {
            LHNWDescriptorProfiles[i].descriptor = descriptor;
            LHNWDescriptorProfiles[i].passThrough = passThrough;
            return;
        }
    }
}

static bool LHNWDescriptorShouldPassThrough(void *descriptor) {
    for (size_t i = 0; i < sizeof(LHNWDescriptorProfiles) / sizeof(LHNWDescriptorProfiles[0]); i++) {
        if (LHNWDescriptorProfiles[i].descriptor == descriptor) {
            return LHNWDescriptorProfiles[i].passThrough;
        }
    }
    return false;
}

static bool LHNWBrowserDescriptorIsPermissionProbe(void *descriptor) {
    if (LHNWDescriptorShouldPassThrough(descriptor)) {
        return true;
    }
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

static void *LHNWBrowseDescriptorCreateBonjourServiceReplacement(const char *type, const char *domain) {
    if (LHNWBrowseDescriptorCreateBonjourServiceOriginalImplementation == 0) {
        return 0;
    }

    void *descriptor = LHNWBrowseDescriptorCreateBonjourServiceOriginalImplementation(type, domain);
    LHNWDescriptorRememberProfile(descriptor, LHNWBrowserServiceTypeIsPermissionProbe(type));
    return descriptor;
}

static void *LHNWBrowserCreateReplacement(void *descriptor, void *parameters) {
    if (LHNWBrowserCreateOriginalImplementation == 0) {
        return 0;
    }

    void *browser = LHNWBrowserCreateOriginalImplementation(descriptor, parameters);
    LHNWBrowserRememberProfile(browser, LHNWBrowserDescriptorIsPermissionProbe(descriptor));
    return browser;
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
    };
    LHNWBrowserSetBrowseResultsChangedHandlerOriginalImplementation(browser, (LHNWBrowserBrowseResultsChangedHandler)_Block_copy(emptyHandler));
}

/** Installs empty-result filtering for Network.framework Bonjour/local-service browsing. */
bool LHMitigation_network_local_bonjour_nwbrowser_empty_results_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    LHNWBrowseDescriptorGetBonjourServiceTypeImplementation = (LHNWBrowseDescriptorGetBonjourServiceType)dlsym(RTLD_DEFAULT, "nw_browse_descriptor_get_bonjour_service_type");

    bool installed = false;

    void *descriptorTarget = dlsym(RTLD_DEFAULT, "nw_browse_descriptor_create_bonjour_service");
    if (descriptorTarget != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              descriptorTarget,
                                              (void *)LHNWBrowseDescriptorCreateBonjourServiceReplacement,
                                              (void **)&LHNWBrowseDescriptorCreateBonjourServiceOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "nw_browse_descriptor_create_bonjour_service",
                                                (void *)LHNWBrowseDescriptorCreateBonjourServiceReplacement,
                                                (void **)&LHNWBrowseDescriptorCreateBonjourServiceOriginalImplementation) || installed;

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

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_network_local_bonjour_nwbrowser_empty_results);
    }

    return true;
}
