#include <assert.h>
#include <ifaddrs.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/sysctl.h>

#include "../../../runtime/hooks/LHHookBackendTheos.c"

typedef int (*LHFixtureFunction)(int);
extern int lh_fixture_value(int value);
extern LHFixtureFunction lh_fixture_set_head(LHFixtureFunction head);

static LHFixtureFunction LHDirectAOriginal;
static LHFixtureFunction LHDirectBOriginal;
static LHFixtureFunction LHImportAOriginal;
static LHFixtureFunction LHImportBOriginal;
static int (*LHGetifaddrsOriginal)(struct ifaddrs **);
static unsigned LHGetifaddrsCount;
typedef int (*LHSysctlFunction)(int *, u_int, void *, size_t *, void *, size_t);
static LHSysctlFunction LHSysctlAOriginal;
static LHSysctlFunction LHSysctlBOriginal;
static unsigned LHSysctlCounts[2];
static unsigned LHTrace[4];
static void *LHFixtureTarget;
static bool LHDirectHooks;

static int LHDirectA(int value) { LHTrace[0]++; return LHDirectAOriginal(value) + 10; }
static int LHDirectB(int value) { LHTrace[1]++; return LHDirectBOriginal(value) + 100; }
static int LHImportA(int value) { LHTrace[2]++; return LHImportAOriginal(value) + 1000; }
static int LHImportB(int value) { LHTrace[3]++; return LHImportBOriginal(value) + 10000; }

static int LHGetifaddrs(struct ifaddrs **addresses) {
    LHGetifaddrsCount++;
    return LHGetifaddrsOriginal(addresses);
}

static int LHSysctlA(int *mib, u_int count, void *old, size_t *oldSize, void *new, size_t newSize) {
    LHSysctlCounts[0]++;
    return LHSysctlAOriginal(mib, count, old, oldSize, new, newSize);
}

static int LHSysctlB(int *mib, u_int count, void *old, size_t *oldSize, void *new, size_t newSize) {
    LHSysctlCounts[1]++;
    return LHSysctlBOriginal(mib, count, old, oldSize, new, newSize);
}

static void LHMockHookFunction(void *target, void *replacement, void **original) {
    assert(target == LHFixtureTarget);
    *original = (void *)lh_fixture_set_head((LHFixtureFunction)replacement);
}

typedef struct LHFixtureClient {
    int (*call)(int);
    int (*pointerCall)(int);
    int (*getifaddrs)(void);
    int (*sysctl)(void);
} LHFixtureClient;

static LHFixtureClient LHLoadClient(const char *directory, const char *name) {
    char path[4096];
    assert(snprintf(path, sizeof(path), "%s/%s.dylib", directory, name) > 0);
    void *handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL);
    if (handle == 0) { fprintf(stderr, "%s\n", dlerror()); abort(); }
    LHFixtureClient client = {
        .call = (int (*)(int))dlsym(handle, "lh_fixture_call"),
        .pointerCall = (int (*)(int))dlsym(handle, "lh_fixture_pointer_call"),
        .getifaddrs = (int (*)(void))dlsym(handle, "lh_fixture_getifaddrs"),
        .sysctl = (int (*)(void))dlsym(handle, "lh_fixture_sysctl")
    };
    assert(client.call != 0 && client.pointerCall != 0 && client.getifaddrs != 0 && client.sysctl != 0);
    return client;
}

static void LHCheckClient(LHFixtureClient client, int expected) {
    unsigned trace[4];
    memcpy(trace, LHTrace, sizeof(trace));
    assert(client.call(1) == expected);
    assert(client.pointerCall(1) == expected);
    for (size_t i = 0; i < 4; i++) assert(LHTrace[i] == trace[i] + (i >= 2 || LHDirectHooks ? 2 : 0));
    unsigned calls = LHGetifaddrsCount;
    assert(client.getifaddrs() == 0);
    assert(LHGetifaddrsCount == calls + 1);
    unsigned sysctlCalls[] = { LHSysctlCounts[0], LHSysctlCounts[1] };
    assert(client.sysctl() == 0);
    assert(LHSysctlCounts[0] == sysctlCalls[0] + 1);
    assert(LHSysctlCounts[1] == sysctlCalls[1] + 1);
}

int main(int argc, char **argv) {
    assert(argc == 2 || argc == 3);
    LHDirectHooks = argc == 2;
    LHFixtureTarget = dlsym(RTLD_DEFAULT, "lh_fixture_value");
    assert(LHFixtureTarget != 0);
    LHFixtureClient classic = LHLoadClient(argv[1], "classic-existing");
    LHFixtureClient chained = LHLoadClient(argv[1], "chained-existing");
    /* Classic lazy stub has never run when registration happens. */
    assert(chained.call(1) == 1);
    LHTheosBackendContext context = { .hookFunction = LHMockHookFunction };
    LHHookBackend backend = { .context = &context };
    if (LHDirectHooks) {
        assert(LHTheosHookFunction(&backend, LHFixtureTarget, (void *)LHDirectA, (void **)&LHDirectAOriginal));
        void *trampolineA = (void *)LHDirectAOriginal;
        assert(LHTheosHookImportedSymbol(&backend, "lh_fixture_value", (void *)LHDirectA, (void **)&LHDirectAOriginal));
        assert((void *)LHDirectAOriginal == trampolineA);
    }
    assert(LHTheosHookImportedSymbol(&backend, "lh_fixture_value", (void *)LHImportA, (void **)&LHImportAOriginal));
    assert((void *)LHImportAOriginal == LHFixtureTarget);
    /* A later direct hook must preserve the already installed import-only adapter. */
    if (LHDirectHooks) {
        assert(LHTheosHookFunction(&backend, LHFixtureTarget, (void *)LHDirectB, (void **)&LHDirectBOriginal));
        void *trampolineB = (void *)LHDirectBOriginal;
        assert(LHTheosHookImportedSymbol(&backend, "lh_fixture_value", (void *)LHDirectB, (void **)&LHDirectBOriginal));
        assert((void *)LHDirectBOriginal == trampolineB);
        assert(LHTheosHookFunction(&backend, LHFixtureTarget, (void *)LHDirectA, (void **)&LHDirectAOriginal));
        assert((void *)LHDirectAOriginal != (void *)LHDirectA);
    }
    assert(LHTheosHookImportedSymbol(&backend, "lh_fixture_value", (void *)LHImportB, (void **)&LHImportBOriginal));
    assert((void *)LHImportBOriginal == (void *)LHImportA);
    assert(LHTheosHookImportedSymbol(&backend, "getifaddrs", (void *)LHGetifaddrs, (void **)&LHGetifaddrsOriginal));
    assert(LHTheosHookImportedSymbol(&backend, "sysctl", (void *)LHSysctlA, (void **)&LHSysctlAOriginal));
    assert(LHTheosHookImportedSymbol(&backend, "sysctl", (void *)LHSysctlB, (void **)&LHSysctlBOriginal));
    assert((void *)LHSysctlBOriginal == (void *)LHSysctlA);
    assert(!LHTheosHookImportedSymbol(&backend, "lh_fixture_missing", (void *)LHImportA, 0));
    void *unimported = 0;
    assert(!LHTheosHookImportedSymbol(&backend, "lh_fixture_unused", (void *)LHImportA, &unimported));
    int expected = LHDirectHooks ? 11111 : 11001;
    LHCheckClient(classic, expected);
    LHCheckClient(chained, expected);
    LHCheckClient(LHLoadClient(argv[1], "classic-late"), expected);
    LHCheckClient(LHLoadClient(argv[1], "chained-late"), expected);
    /* Repeated registration neither rewrites originals nor moves an old adapter to the head. */
    assert(LHTheosHookImportedSymbol(&backend, "lh_fixture_value", (void *)LHImportA, (void **)&LHImportAOriginal));
    assert((void *)LHImportAOriginal == LHFixtureTarget);
    LHCheckClient(classic, expected);
    LHCheckClient(chained, expected);
    assert(!LHTheosHookImportedSymbol(&backend, "", (void *)LHImportA, 0));
    assert(!LHTheosHookImportedSymbol(&backend, "lh_fixture_value", LHFixtureTarget, 0));
    atomic_store(&LHImportedSymbolBindingCount, 128);
    void *capacityOriginal = 0;
    assert(!LHTheosHookImportedSymbol(&backend, "lh_fixture_unused", (void *)LHImportB, &capacityOriginal));
    assert(capacityOriginal == 0);
    puts("Live classic/chained imports, lazy first call, late images, getifaddrs, stacked sysctl, and direct/import composition passed.");
    return 0;
}
