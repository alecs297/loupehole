#include "LHHookBackend.h"

#include <dlfcn.h>

typedef void (*MSHookFunctionType)(void *target, void *replacement, void **original);
typedef void (*MSHookMessageExType)(Class targetClass, SEL selector, void *replacement, void **original);

typedef struct LHTheosBackendContext {
    MSHookFunctionType hookFunction;
    MSHookMessageExType hookMessage;
    uint32_t registeredNoOpCount;
} LHTheosBackendContext;

static LHTheosBackendContext LHTheosBackendSharedContext(void) {
    LHTheosBackendContext context = { 0 };
    context.hookFunction = (MSHookFunctionType)dlsym(RTLD_DEFAULT, "MSHookFunction");
    context.hookMessage = (MSHookMessageExType)dlsym(RTLD_DEFAULT, "MSHookMessageEx");
    return context;
}

static bool LHTheosHookFunction(LHHookBackend *backend, void *target, void *replacement, void **original) {
    LHTheosBackendContext *context = (LHTheosBackendContext *)backend->context;
    if (context == 0 || context->hookFunction == 0 || target == 0 || replacement == 0) {
        return false;
    }

    context->hookFunction(target, replacement, original);
    return true;
}

static bool LHTheosHookMessage(LHHookBackend *backend, Class targetClass, SEL selector, void *replacement, void **original) {
    LHTheosBackendContext *context = (LHTheosBackendContext *)backend->context;
    if (context == 0 || context->hookMessage == 0 || targetClass == 0 || selector == 0 || replacement == 0) {
        return false;
    }

    context->hookMessage(targetClass, selector, replacement, original);
    return true;
}

static bool LHTheosRegisterNoOp(LHHookBackend *backend, uint32_t moduleID) {
    LHTheosBackendContext *context = (LHTheosBackendContext *)backend->context;
    if (context == 0 || moduleID == 0) {
        return false;
    }

    context->registeredNoOpCount++;
    return true;
}

LHHookBackend LHHookBackendCreateTheos(void) {
    static LHTheosBackendContext context;
    static bool initialized;
    if (!initialized) {
        context = LHTheosBackendSharedContext();
        initialized = true;
    }

    static const LHHookBackendVTable vtable = {
        .hookFunction = LHTheosHookFunction,
        .hookMessage = LHTheosHookMessage,
        .registerNoOp = LHTheosRegisterNoOp
    };

    LHHookBackend backend = {
        .vtable = &vtable,
        .context = &context
    };
    return backend;
}
