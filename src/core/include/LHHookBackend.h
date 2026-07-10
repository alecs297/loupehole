#ifndef LH_HOOK_BACKEND_H
#define LH_HOOK_BACKEND_H

#include "LHBuildConfig.h"
#include "LHTypes.h"

#ifdef __OBJC__
@class NSObject;
typedef struct objc_class *Class;
typedef struct objc_object *id;
typedef struct objc_selector *SEL;
#else
typedef struct objc_class *Class;
typedef struct objc_object *id;
typedef struct objc_selector *SEL;
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LHHookBackend LHHookBackend;

typedef bool (*LHHookFunctionInstaller)(LHHookBackend *backend, void *target, void *replacement, void **original);
typedef bool (*LHHookImportedSymbolInstaller)(LHHookBackend *backend, const char *symbol, void *replacement, void **original);
typedef bool (*LHHookMessageInstaller)(LHHookBackend *backend, Class targetClass, SEL selector, void *replacement, void **original);
typedef bool (*LHHookNoOpRegistrar)(LHHookBackend *backend, uint32_t moduleID);

typedef struct LHHookBackendVTable {
    LHHookFunctionInstaller hookFunction;
    LHHookImportedSymbolInstaller hookImportedSymbol;
    LHHookMessageInstaller hookMessage;
    LHHookNoOpRegistrar registerNoOp;
} LHHookBackendVTable;

struct LHHookBackend {
    const LHHookBackendVTable *vtable;
    void *context;
};

/** Installs a direct function hook through `backend`. */
LH_INTERNAL bool LHHookBackendHookFunction(LHHookBackend *backend, void *target, void *replacement, void **original);
/** Rebinds imported symbols matching `symbol` through `backend`. */
LH_INTERNAL bool LHHookBackendHookImportedSymbol(LHHookBackend *backend, const char *symbol, void *replacement, void **original);
/** Installs an Objective-C method hook through `backend`. */
LH_INTERNAL bool LHHookBackendHookMessage(LHHookBackend *backend, Class targetClass, SEL selector, void *replacement, void **original);
/** Records that `moduleID` intentionally installed no hooks. */
LH_INTERNAL bool LHHookBackendRegisterNoOp(LHHookBackend *backend, uint32_t moduleID);
/** Creates the Theos/MobileSubstrate hook backend. */
LH_INTERNAL LHHookBackend LHHookBackendCreateTheos(void);

#ifdef __cplusplus
}
#endif

#endif
