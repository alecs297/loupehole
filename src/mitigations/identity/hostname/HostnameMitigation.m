#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#include <dlfcn.h>
#include <errno.h>
#include <string.h>
#include <sys/sysctl.h>
#include <sys/utsname.h>
#include <unistd.h>

typedef int (*LHHostnameSysctlOriginal)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
typedef int (*LHHostnameSysctlByNameOriginal)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
typedef int (*LHGetHostnameOriginal)(char *name, size_t namelen);
typedef int (*LHUnameOriginal)(struct utsname *name);
typedef NSString *(*LHProcessHostNameOriginal)(NSProcessInfo *self, SEL selector);

static LHHostnameSysctlOriginal LHHostnameSysctlOriginalImplementation;
static LHHostnameSysctlOriginal LHPrivateHostnameSysctlOriginalImplementation;
static LHHostnameSysctlByNameOriginal LHHostnameSysctlByNameOriginalImplementation;
static LHHostnameSysctlByNameOriginal LHPrivateHostnameSysctlByNameOriginalImplementation;
static LHGetHostnameOriginal LHGetHostnameOriginalImplementation;
static LHUnameOriginal LHUnameOriginalImplementation;
static LHProcessHostNameOriginal LHProcessHostNameOriginalImplementation;

static const char *LHHostnameGenericCString(void) {
    Class deviceClass = NSClassFromString(@"UIDevice");
    UIDevice *device = nil;
    if (deviceClass != Nil && [deviceClass respondsToSelector:@selector(currentDevice)]) {
        device = [deviceClass currentDevice];
    }
    if (device != nil && [device respondsToSelector:@selector(userInterfaceIdiom)] && [device userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        return "iPad";
    }
    return "iPhone";
}

static int LHHostnameCopyOut(void *oldp, size_t *oldlenp) {
    if (oldlenp == 0) {
        errno = EFAULT;
        return -1;
    }

    const char *hostname = LHHostnameGenericCString();
    size_t required = strlen(hostname) + 1;
    if (oldp == 0) {
        *oldlenp = required;
        return 0;
    }
    if (*oldlenp < required) {
        *oldlenp = required;
        errno = ENOMEM;
        return -1;
    }

    memcpy(oldp, hostname, required);
    *oldlenp = required;
    return 0;
}

static int LHHostnameSysctlReplacement(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (newp == 0 && name != 0 && namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_HOSTNAME) {
        if (LHHostnameCopyOut(oldp, oldlenp) == 0) {
            return 0;
        }
    }

    if (LHHostnameSysctlOriginalImplementation != 0) {
        return LHHostnameSysctlOriginalImplementation(name, namelen, oldp, oldlenp, newp, newlen);
    }

    errno = ENOSYS;
    return -1;
}

static int LHPrivateHostnameSysctlReplacement(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (newp == 0 && name != 0 && namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_HOSTNAME) {
        if (LHHostnameCopyOut(oldp, oldlenp) == 0) {
            return 0;
        }
    }

    if (LHPrivateHostnameSysctlOriginalImplementation != 0) {
        return LHPrivateHostnameSysctlOriginalImplementation(name, namelen, oldp, oldlenp, newp, newlen);
    }

    errno = ENOSYS;
    return -1;
}

static int LHHostnameSysctlByNameReplacement(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (newp == 0 && name != 0 && strcmp(name, "kern.hostname") == 0) {
        if (LHHostnameCopyOut(oldp, oldlenp) == 0) {
            return 0;
        }
    }

    if (LHHostnameSysctlByNameOriginalImplementation != 0) {
        return LHHostnameSysctlByNameOriginalImplementation(name, oldp, oldlenp, newp, newlen);
    }

    errno = ENOSYS;
    return -1;
}

static int LHPrivateHostnameSysctlByNameReplacement(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (newp == 0 && name != 0 && strcmp(name, "kern.hostname") == 0) {
        if (LHHostnameCopyOut(oldp, oldlenp) == 0) {
            return 0;
        }
    }

    if (LHPrivateHostnameSysctlByNameOriginalImplementation != 0) {
        return LHPrivateHostnameSysctlByNameOriginalImplementation(name, oldp, oldlenp, newp, newlen);
    }

    errno = ENOSYS;
    return -1;
}

static int LHGetHostnameReplacement(char *name, size_t namelen) {
    if (name == 0 || namelen == 0) {
        errno = EINVAL;
        return -1;
    }

    const char *hostname = LHHostnameGenericCString();
    size_t required = strlen(hostname) + 1;
    if (namelen < required) {
        errno = ENAMETOOLONG;
        return -1;
    }

    memcpy(name, hostname, required);
    return 0;
}

static int LHUnameReplacement(struct utsname *name) {
    if (name == 0) {
        errno = EFAULT;
        return -1;
    }

    int result = 0;
    if (LHUnameOriginalImplementation != 0) {
        result = LHUnameOriginalImplementation(name);
        if (result != 0) {
            return result;
        }
    } else {
        memset(name, 0, sizeof(*name));
    }

    const char *hostname = LHHostnameGenericCString();
    if (strlen(hostname) >= sizeof(name->nodename)) {
        return result;
    }

    memset(name->nodename, 0, sizeof(name->nodename));
    memcpy(name->nodename, hostname, strlen(hostname));
    return result;
}

static NSString *LHProcessHostNameReplacement(NSProcessInfo *self, SEL selector) {
    (void)self;
    (void)selector;
    return [NSString stringWithUTF8String:LHHostnameGenericCString()];
}

static bool LHHostnameHookIfDistinct(LHHookBackend *backend, void *target, void *knownTarget, void *replacement, void **original) {
    if (target == 0 || target == knownTarget) {
        return false;
    }

    return LHHookBackendHookFunction(backend, target, replacement, original);
}

bool LHMitigation_identity_hostname_composite_generic_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    void *sysctlTarget = dlsym(RTLD_DEFAULT, "sysctl");
    void *sysctlByNameTarget = dlsym(RTLD_DEFAULT, "sysctlbyname");
    void *privateSysctlTarget = dlsym(RTLD_DEFAULT, "__sysctl");
    void *privateSysctlByNameTarget = dlsym(RTLD_DEFAULT, "__sysctlbyname");
    void *gethostnameTarget = dlsym(RTLD_DEFAULT, "gethostname");
    void *unameTarget = dlsym(RTLD_DEFAULT, "uname");
    bool installed = false;

    if (sysctlTarget != 0) {
        installed = LHHookBackendHookFunction(backend, sysctlTarget, (void *)LHHostnameSysctlReplacement, (void **)&LHHostnameSysctlOriginalImplementation) || installed;
    }
    if (sysctlByNameTarget != 0) {
        installed = LHHookBackendHookFunction(backend, sysctlByNameTarget, (void *)LHHostnameSysctlByNameReplacement, (void **)&LHHostnameSysctlByNameOriginalImplementation) || installed;
    }
    installed = LHHostnameHookIfDistinct(backend, privateSysctlTarget, sysctlTarget, (void *)LHPrivateHostnameSysctlReplacement, (void **)&LHPrivateHostnameSysctlOriginalImplementation) || installed;
    installed = LHHostnameHookIfDistinct(backend, privateSysctlByNameTarget, sysctlByNameTarget, (void *)LHPrivateHostnameSysctlByNameReplacement, (void **)&LHPrivateHostnameSysctlByNameOriginalImplementation) || installed;
    if (gethostnameTarget != 0) {
        installed = LHHookBackendHookFunction(backend, gethostnameTarget, (void *)LHGetHostnameReplacement, (void **)&LHGetHostnameOriginalImplementation) || installed;
    }
    if (unameTarget != 0) {
        installed = LHHookBackendHookFunction(backend, unameTarget, (void *)LHUnameReplacement, (void **)&LHUnameOriginalImplementation) || installed;
    }

    installed = LHHookBackendHookImportedSymbol(backend, "sysctl", (void *)LHHostnameSysctlReplacement, (void **)&LHHostnameSysctlOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend, "sysctlbyname", (void *)LHHostnameSysctlByNameReplacement, (void **)&LHHostnameSysctlByNameOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend, "__sysctl", (void *)LHPrivateHostnameSysctlReplacement, (void **)&LHPrivateHostnameSysctlOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend, "__sysctlbyname", (void *)LHPrivateHostnameSysctlByNameReplacement, (void **)&LHPrivateHostnameSysctlByNameOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend, "gethostname", (void *)LHGetHostnameReplacement, (void **)&LHGetHostnameOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend, "uname", (void *)LHUnameReplacement, (void **)&LHUnameOriginalImplementation) || installed;

    Class processInfoClass = NSClassFromString(@"NSProcessInfo");
    SEL hostNameSelector = sel_registerName("hostName");
    if (processInfoClass != Nil && hostNameSelector != 0) {
        installed = LHHookBackendHookMessage(backend, processInfoClass, hostNameSelector, (void *)LHProcessHostNameReplacement, (void **)&LHProcessHostNameOriginalImplementation) || installed;
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_identity_hostname_composite_generic);
    }

    return true;
}
