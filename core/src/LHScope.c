#include "LHScope.h"

#include <string.h>

bool LHScopeInit(LHScope *scope, LHScopeMode mode, const uint8_t *identifier, size_t identifierLength) {
    if (scope == 0 || identifier == 0 || identifierLength == 0 || identifierLength > sizeof(scope->identifier)) {
        return false;
    }

    scope->mode = mode;
    scope->identifierLength = identifierLength;
    memcpy(scope->identifier, identifier, identifierLength);
    return true;
}

bool LHScopeInitPerAppInstall(LHScope *scope, const char *bundleIdentifier) {
    if (bundleIdentifier == 0) {
        static const uint8_t fallback[] = { 'a', 'p', 'p', '-', 'i', 'n', 's', 't', 'a', 'l', 'l' };
        return LHScopeInit(scope, LHScopeModePerAppInstall, fallback, sizeof(fallback));
    }

    return LHScopeInit(scope, LHScopeModePerAppInstall, (const uint8_t *)bundleIdentifier, strlen(bundleIdentifier));
}

bool LHScopeInitPerApp(LHScope *scope, const char *bundleIdentifier) {
    if (bundleIdentifier == 0) {
        static const uint8_t fallback[] = { 'a', 'p', 'p' };
        return LHScopeInit(scope, LHScopeModePerApp, fallback, sizeof(fallback));
    }

    return LHScopeInit(scope, LHScopeModePerApp, (const uint8_t *)bundleIdentifier, strlen(bundleIdentifier));
}

bool LHScopeInitPerVendorGroup(LHScope *scope, const char *vendorIdentifier) {
    if (vendorIdentifier == 0) {
        static const uint8_t fallback[] = { 'v', 'e', 'n', 'd', 'o', 'r' };
        return LHScopeInit(scope, LHScopeModePerVendorGroup, fallback, sizeof(fallback));
    }

    return LHScopeInit(scope, LHScopeModePerVendorGroup, (const uint8_t *)vendorIdentifier, strlen(vendorIdentifier));
}

bool LHScopeInitPerSharedAppGroup(LHScope *scope, const char *appGroupIdentifier) {
    if (appGroupIdentifier == 0) {
        static const uint8_t fallback[] = { 'g', 'r', 'o', 'u', 'p' };
        return LHScopeInit(scope, LHScopeModePerSharedAppGroup, fallback, sizeof(fallback));
    }

    return LHScopeInit(scope, LHScopeModePerSharedAppGroup, (const uint8_t *)appGroupIdentifier, strlen(appGroupIdentifier));
}

bool LHScopeInitManualLinkedGroup(LHScope *scope, const char *groupIdentifier) {
    if (groupIdentifier == 0) {
        static const uint8_t fallback[] = { 'l', 'i', 'n', 'k' };
        return LHScopeInit(scope, LHScopeModeManualLinkedGroup, fallback, sizeof(fallback));
    }

    return LHScopeInit(scope, LHScopeModeManualLinkedGroup, (const uint8_t *)groupIdentifier, strlen(groupIdentifier));
}
