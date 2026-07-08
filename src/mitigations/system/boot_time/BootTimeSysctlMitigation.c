#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "BootTimeValues.h"

#include <dlfcn.h>
#include <errno.h>
#include <string.h>
#include <sys/sysctl.h>
#include <sys/time.h>

typedef int (*LHSysctlOriginal)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
typedef int (*LHSysctlByNameOriginal)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);

static LHSysctlOriginal LHSysctlOriginalImplementation;
static LHSysctlOriginal LHPrivateSysctlOriginalImplementation;
static LHSysctlByNameOriginal LHSysctlByNameOriginalImplementation;
static LHSysctlByNameOriginal LHPrivateSysctlByNameOriginalImplementation;
static LHPolicyEngine *LHBootTimePolicy;

/** Copies the synthetic boot-time timeval into a sysctl output buffer. */
static int LHBootTimeCopyOut(void *oldp, size_t *oldlenp) {
    struct timeval bootTime;
    if (!LHBootTimeCopySyntheticBootTime(LHBootTimePolicy, &bootTime)) {
        errno = ENOENT;
        return -1;
    }

    if (oldlenp == 0) {
        errno = EFAULT;
        return -1;
    }

    size_t required = sizeof(bootTime);
    if (oldp == 0) {
        *oldlenp = required;
        return 0;
    }

    if (*oldlenp < required) {
        *oldlenp = required;
        errno = ENOMEM;
        return -1;
    }

    memcpy(oldp, &bootTime, required);
    *oldlenp = required;
    return 0;
}

/** Replacement for public `sysctl` boot-time requests. */
static int LHSysctlReplacement(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (newp == 0 && name != 0 && namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_BOOTTIME) {
        if (LHBootTimeCopyOut(oldp, oldlenp) == 0) {
            return 0;
        }
    }

    if (LHSysctlOriginalImplementation != 0) {
        return LHSysctlOriginalImplementation(name, namelen, oldp, oldlenp, newp, newlen);
    }

    errno = ENOSYS;
    return -1;
}

/** Replacement for private `__sysctl` boot-time requests. */
static int LHPrivateSysctlReplacement(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (newp == 0 && name != 0 && namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_BOOTTIME) {
        if (LHBootTimeCopyOut(oldp, oldlenp) == 0) {
            return 0;
        }
    }

    if (LHPrivateSysctlOriginalImplementation != 0) {
        return LHPrivateSysctlOriginalImplementation(name, namelen, oldp, oldlenp, newp, newlen);
    }

    errno = ENOSYS;
    return -1;
}

/** Replacement for public `sysctlbyname` boot-time requests. */
static int LHSysctlByNameReplacement(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (newp == 0 && name != 0 && strcmp(name, "kern.boottime") == 0) {
        if (LHBootTimeCopyOut(oldp, oldlenp) == 0) {
            return 0;
        }
    }

    if (LHSysctlByNameOriginalImplementation != 0) {
        return LHSysctlByNameOriginalImplementation(name, oldp, oldlenp, newp, newlen);
    }

    errno = ENOSYS;
    return -1;
}

/** Replacement for private `__sysctlbyname` boot-time requests. */
static int LHPrivateSysctlByNameReplacement(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (newp == 0 && name != 0 && strcmp(name, "kern.boottime") == 0) {
        if (LHBootTimeCopyOut(oldp, oldlenp) == 0) {
            return 0;
        }
    }

    if (LHPrivateSysctlByNameOriginalImplementation != 0) {
        return LHPrivateSysctlByNameOriginalImplementation(name, oldp, oldlenp, newp, newlen);
    }

    errno = ENOSYS;
    return -1;
}

/** Hooks a private symbol only when it resolves to a distinct implementation. */
static bool LHBootTimeHookIfDistinct(LHHookBackend *backend,
                                     void *target,
                                     void *knownTarget,
                                     void *replacement,
                                     void **original) {
    if (target == 0 || target == knownTarget) {
        return false;
    }

    return LHHookBackendHookFunction(backend, target, replacement, original);
}

/** Registers an imported-symbol hook for a boot-time function. */
static bool LHBootTimeHookImportedSymbol(LHHookBackend *backend, const char *symbol, void *replacement, void **original) {
    if (symbol == 0 || replacement == 0) {
        return false;
    }

    return LHHookBackendHookImportedSymbol(backend, symbol, replacement, original);
}

/** Installs sysctl-based boot-time hooks. */
bool LHBootTimeSysctlInstall(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHBootTimePolicy = policy;

    void *sysctlTarget = dlsym(RTLD_DEFAULT, "sysctl");
    void *sysctlByNameTarget = dlsym(RTLD_DEFAULT, "sysctlbyname");
    void *privateSysctlTarget = dlsym(RTLD_DEFAULT, "__sysctl");
    void *privateSysctlByNameTarget = dlsym(RTLD_DEFAULT, "__sysctlbyname");
    bool installed = false;

    if (sysctlTarget != 0) {
        installed = LHHookBackendHookFunction(backend, sysctlTarget, (void *)LHSysctlReplacement, (void **)&LHSysctlOriginalImplementation) || installed;
    }
    if (sysctlByNameTarget != 0) {
        installed = LHHookBackendHookFunction(backend, sysctlByNameTarget, (void *)LHSysctlByNameReplacement, (void **)&LHSysctlByNameOriginalImplementation) || installed;
    }
    installed = LHBootTimeHookIfDistinct(backend,
                                         privateSysctlTarget,
                                         sysctlTarget,
                                         (void *)LHPrivateSysctlReplacement,
                                         (void **)&LHPrivateSysctlOriginalImplementation) || installed;
    installed = LHBootTimeHookIfDistinct(backend,
                                         privateSysctlByNameTarget,
                                         sysctlByNameTarget,
                                         (void *)LHPrivateSysctlByNameReplacement,
                                         (void **)&LHPrivateSysctlByNameOriginalImplementation) || installed;
    installed = LHBootTimeHookImportedSymbol(backend,
                                             "sysctl",
                                             (void *)LHSysctlReplacement,
                                             (void **)&LHSysctlOriginalImplementation) || installed;
    installed = LHBootTimeHookImportedSymbol(backend,
                                             "sysctlbyname",
                                             (void *)LHSysctlByNameReplacement,
                                             (void **)&LHSysctlByNameOriginalImplementation) || installed;
    installed = LHBootTimeHookImportedSymbol(backend,
                                             "__sysctl",
                                             (void *)LHPrivateSysctlReplacement,
                                             (void **)&LHPrivateSysctlOriginalImplementation) || installed;
    installed = LHBootTimeHookImportedSymbol(backend,
                                             "__sysctlbyname",
                                             (void *)LHPrivateSysctlByNameReplacement,
                                             (void **)&LHPrivateSysctlByNameOriginalImplementation) || installed;

    if (!installed) {
        return false;
    }

    return true;
}
