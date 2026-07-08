#include "LHHookBackend.h"

/** Installs a function hook using the active backend vtable. */
bool LHHookBackendHookFunction(LHHookBackend *backend, void *target, void *replacement, void **original) {
    if (backend == 0 || backend->vtable == 0 || backend->vtable->hookFunction == 0) {
        return false;
    }

    return backend->vtable->hookFunction(backend, target, replacement, original);
}

/** Installs an imported-symbol hook using the active backend vtable. */
bool LHHookBackendHookImportedSymbol(LHHookBackend *backend, const char *symbol, void *replacement, void **original) {
    if (backend == 0 || backend->vtable == 0 || backend->vtable->hookImportedSymbol == 0) {
        return false;
    }

    return backend->vtable->hookImportedSymbol(backend, symbol, replacement, original);
}

/** Installs an Objective-C method hook using the active backend vtable. */
bool LHHookBackendHookMessage(LHHookBackend *backend, Class targetClass, SEL selector, void *replacement, void **original) {
    if (backend == 0 || backend->vtable == 0 || backend->vtable->hookMessage == 0) {
        return false;
    }

    return backend->vtable->hookMessage(backend, targetClass, selector, replacement, original);
}

/** Records a no-op module installation using the active backend vtable. */
bool LHHookBackendRegisterNoOp(LHHookBackend *backend, uint32_t moduleID) {
    if (backend == 0 || backend->vtable == 0 || backend->vtable->registerNoOp == 0) {
        return false;
    }

    return backend->vtable->registerNoOp(backend, moduleID);
}
