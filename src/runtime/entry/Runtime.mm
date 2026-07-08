#include "LHRuntime.h"

/** Constructor entry point for the injected dylib. */
__attribute__((constructor))
static void runtime_entry(void) {
    LHRuntimeStart();
}
