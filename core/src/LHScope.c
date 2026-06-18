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

bool LHScopeInitPerApp(LHScope *scope, const char *bundleIdentifier) {
    if (bundleIdentifier == 0) {
        static const uint8_t fallback[] = { 'a', 'p', 'p' };
        return LHScopeInit(scope, LHScopeModePerApp, fallback, sizeof(fallback));
    }

    return LHScopeInit(scope, LHScopeModePerApp, (const uint8_t *)bundleIdentifier, strlen(bundleIdentifier));
}
