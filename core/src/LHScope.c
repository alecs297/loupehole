#include "LHScope.h"

#include <stdlib.h>
#include <string.h>

static bool LHScopeInitRandomIdentifier(LHScope *scope, LHScopeMode mode) {
    static const uint8_t alphabet[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    enum { kFallbackLength = 32 };

    if (scope == 0) {
        return false;
    }

    scope->mode = mode;
    scope->identifierLength = kFallbackLength;
    memset(scope->identifier, 0, sizeof(scope->identifier));
    for (size_t index = 0; index < kFallbackLength; index++) {
        scope->identifier[index] = alphabet[arc4random_uniform((uint32_t)(sizeof(alphabet) - 1))];
    }
    return true;
}

bool LHScopeInit(LHScope *scope, LHScopeMode mode, const uint8_t *identifier, size_t identifierLength) {
    if (scope == 0) {
        return false;
    }
    if (identifier == 0 || identifierLength == 0 || identifierLength > sizeof(scope->identifier)) {
        return LHScopeInitRandomIdentifier(scope, mode);
    }

    scope->mode = mode;
    scope->identifierLength = identifierLength;
    memset(scope->identifier, 0, sizeof(scope->identifier));
    memcpy(scope->identifier, identifier, identifierLength);
    return true;
}

bool LHScopeInitPerAppInstall(LHScope *scope, const char *bundleIdentifier) {
    return LHScopeInit(scope,
                       LHScopeModePerAppInstall,
                       (const uint8_t *)bundleIdentifier,
                       bundleIdentifier == 0 ? 0 : strlen(bundleIdentifier));
}

bool LHScopeInitPerApp(LHScope *scope, const char *bundleIdentifier) {
    return LHScopeInit(scope,
                       LHScopeModePerApp,
                       (const uint8_t *)bundleIdentifier,
                       bundleIdentifier == 0 ? 0 : strlen(bundleIdentifier));
}

bool LHScopeInitPerVendorGroup(LHScope *scope, const char *vendorIdentifier) {
    return LHScopeInit(scope,
                       LHScopeModePerVendorGroup,
                       (const uint8_t *)vendorIdentifier,
                       vendorIdentifier == 0 ? 0 : strlen(vendorIdentifier));
}

bool LHScopeInitManualLinkedGroup(LHScope *scope, const char *groupIdentifier) {
    static const uint8_t staticIdentifier[] = { 0 };
    (void)groupIdentifier;
    return LHScopeInit(scope,
                       LHScopeModeManualLinkedGroup,
                       staticIdentifier,
                       sizeof(staticIdentifier));
}
