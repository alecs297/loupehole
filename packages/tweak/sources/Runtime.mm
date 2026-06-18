#include "LHRuntime.h"

__attribute__((constructor))
static void runtime_entry(void) {
    LHRuntimeStart();
}
