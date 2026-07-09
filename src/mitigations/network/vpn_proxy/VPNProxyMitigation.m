#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdlib.h>

typedef CFDictionaryRef (*LHCFNetworkCopySystemProxySettingsOriginal)(void);

static LHCFNetworkCopySystemProxySettingsOriginal LHCFNetworkCopySystemProxySettingsOriginalImplementation;

static bool LHNetworkProxyKeyLooksLikeVPN(CFStringRef key) {
    if (key == 0) {
        return false;
    }

    CFStringRef lowercase = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, key);
    if (lowercase == 0) {
        return false;
    }
    CFStringLowercase((CFMutableStringRef)lowercase, 0);

    bool matches = CFStringFind(lowercase, CFSTR("tap"), 0).location != kCFNotFound ||
                   CFStringFind(lowercase, CFSTR("tun"), 0).location != kCFNotFound ||
                   CFStringFind(lowercase, CFSTR("ppp"), 0).location != kCFNotFound ||
                   CFStringFind(lowercase, CFSTR("ipsec"), 0).location != kCFNotFound;
    CFRelease(lowercase);
    return matches;
}

static CFDictionaryRef LHFilterScopedProxySettings(CFDictionaryRef original) {
    if (original == 0) {
        return 0;
    }

    CFTypeRef scopedValue = CFDictionaryGetValue(original, CFSTR("__SCOPED__"));
    if (scopedValue == 0 || CFGetTypeID(scopedValue) != CFDictionaryGetTypeID()) {
        return (CFDictionaryRef)CFRetain(original);
    }

    CFDictionaryRef scoped = (CFDictionaryRef)scopedValue;
    CFMutableDictionaryRef filteredScoped = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, scoped);
    if (filteredScoped == 0) {
        return (CFDictionaryRef)CFRetain(original);
    }

    CFIndex count = CFDictionaryGetCount(scoped);
    const void **keys = 0;
    if (count > 0) {
        keys = (const void **)calloc((size_t)count, sizeof(void *));
    }
    if (count > 0 && keys == 0) {
        CFRelease(filteredScoped);
        return (CFDictionaryRef)CFRetain(original);
    }

    CFDictionaryGetKeysAndValues(scoped, keys, 0);
    bool removed = false;
    for (CFIndex index = 0; index < count; index++) {
        CFTypeRef key = keys[index];
        if (key != 0 && CFGetTypeID(key) == CFStringGetTypeID() && LHNetworkProxyKeyLooksLikeVPN((CFStringRef)key)) {
            CFDictionaryRemoveValue(filteredScoped, key);
            removed = true;
        }
    }
    free(keys);

    if (!removed) {
        CFRelease(filteredScoped);
        return (CFDictionaryRef)CFRetain(original);
    }

    CFMutableDictionaryRef filtered = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, original);
    if (filtered == 0) {
        CFRelease(filteredScoped);
        return (CFDictionaryRef)CFRetain(original);
    }

    CFDictionarySetValue(filtered, CFSTR("__SCOPED__"), filteredScoped);
    CFRelease(filteredScoped);
    return filtered;
}

static CFDictionaryRef LHCFNetworkCopySystemProxySettingsReplacement(void) {
    if (LHCFNetworkCopySystemProxySettingsOriginalImplementation == 0) {
        return 0;
    }

    CFDictionaryRef original = LHCFNetworkCopySystemProxySettingsOriginalImplementation();
    CFDictionaryRef filtered = LHFilterScopedProxySettings(original);
    if (original != 0) {
        CFRelease(original);
    }
    return filtered;
}

/** Installs CFNetwork scoped proxy filtering for token-based VPN heuristics. */
bool LHMitigation_network_vpn_proxy_cfnetwork_scoped_filter_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    void *target = dlsym(RTLD_DEFAULT, "CFNetworkCopySystemProxySettings");
    if (target == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_network_vpn_proxy_cfnetwork_scoped_filter);
    }

    if (!LHHookBackendHookFunction(backend, target, (void *)LHCFNetworkCopySystemProxySettingsReplacement, (void **)&LHCFNetworkCopySystemProxySettingsOriginalImplementation)) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_network_vpn_proxy_cfnetwork_scoped_filter);
    }

    return true;
}
