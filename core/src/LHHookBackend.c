#include "LHHookBackend.h"

bool LHHookBackendHookFunction(LHHookBackend *backend, void *target, void *replacement, void **original) {
    if (backend == 0 || backend->vtable == 0 || backend->vtable->hookFunction == 0) {
        return false;
    }

    return backend->vtable->hookFunction(backend, target, replacement, original);
}

bool LHHookBackendHookMessage(LHHookBackend *backend, Class targetClass, SEL selector, void *replacement, void **original) {
    if (backend == 0 || backend->vtable == 0 || backend->vtable->hookMessage == 0) {
        return false;
    }

    return backend->vtable->hookMessage(backend, targetClass, selector, replacement, original);
}

bool LHHookBackendRegisterNoOp(LHHookBackend *backend, uint32_t moduleID) {
    if (backend == 0 || backend->vtable == 0 || backend->vtable->registerNoOp == 0) {
        return false;
    }

    return backend->vtable->registerNoOp(backend, moduleID);
}
