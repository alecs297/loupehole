#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#include <dlfcn.h>
#include <errno.h>
#include <string.h>
#include <sys/sysctl.h>
#include <sys/utsname.h>
#include <unistd.h>

typedef int (*LHGetHostnameOriginal)(char *name, size_t namelen);
typedef int (*LHUnameOriginal)(struct utsname *name);
typedef int (*LHSysctlOriginal)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
typedef int (*LHSysctlByNameOriginal)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
typedef NSString *(*LHHostNameOriginal)(NSProcessInfo *self, SEL selector);

static LHGetHostnameOriginal LHGetHostnameOriginalImplementation;
static LHUnameOriginal LHUnameOriginalImplementation;
static LHSysctlOriginal LHHostnameSysctlOriginalImplementation;
static LHSysctlByNameOriginal LHHostnameSysctlByNameOriginalImplementation;
static LHHostNameOriginal LHProcessInfoHostNameOriginalImplementation;

static const char *LHNetworkSyntheticHostName(void) {
    Class deviceClass = NSClassFromString(@"UIDevice");
    SEL currentDeviceSelector = sel_registerName("currentDevice");
    if (deviceClass != Nil && currentDeviceSelector != 0 && [deviceClass respondsToSelector:currentDeviceSelector]) {
        id (*messageID)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        id device = messageID((id)deviceClass, currentDeviceSelector);
        SEL idiomSelector = sel_registerName("userInterfaceIdiom");
        if (device != nil && idiomSelector != 0 && [device respondsToSelector:idiomSelector]) {
            NSInteger (*messageInteger)(id, SEL) = (NSInteger (*)(id, SEL))objc_msgSend;
            if (messageInteger(device, idiomSelector) == 1) {
                return "iPad";
            }
        }
    }
    return "iPhone";
}

static int LHCopyHostNameToBuffer(void *oldp, size_t *oldlenp) {
    const char *hostname = LHNetworkSyntheticHostName();
    size_t required = strlen(hostname) + 1;
    if (oldlenp == 0) {
        errno = EFAULT;
        return -1;
    }
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

static int LHGetHostnameReplacement(char *name, size_t namelen) {
    if (name == 0 || namelen == 0) {
        errno = EFAULT;
        return -1;
    }

    const char *hostname = LHNetworkSyntheticHostName();
    size_t hostnameLength = strlen(hostname);
    size_t copyLength = hostnameLength < (namelen - 1) ? hostnameLength : (namelen - 1);
    memcpy(name, hostname, copyLength);
    name[copyLength] = '\0';
    return 0;
}

static int LHUnameReplacement(struct utsname *name) {
    if (name == 0) {
        errno = EFAULT;
        return -1;
    }

    if (LHUnameOriginalImplementation != 0 && LHUnameOriginalImplementation(name) != 0) {
        return -1;
    }

    strlcpy(name->nodename, LHNetworkSyntheticHostName(), sizeof(name->nodename));
    return 0;
}

static int LHHostnameSysctlReplacement(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (newp == 0 && name != 0 && namelen >= 2 && name[0] == CTL_KERN && name[1] == KERN_HOSTNAME) {
        if (LHCopyHostNameToBuffer(oldp, oldlenp) == 0) {
            return 0;
        }
    }

    if (LHHostnameSysctlOriginalImplementation != 0) {
        return LHHostnameSysctlOriginalImplementation(name, namelen, oldp, oldlenp, newp, newlen);
    }

    errno = ENOSYS;
    return -1;
}

static int LHHostnameSysctlByNameReplacement(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (newp == 0 && name != 0 && strcmp(name, "kern.hostname") == 0) {
        if (LHCopyHostNameToBuffer(oldp, oldlenp) == 0) {
            return 0;
        }
    }

    if (LHHostnameSysctlByNameOriginalImplementation != 0) {
        return LHHostnameSysctlByNameOriginalImplementation(name, oldp, oldlenp, newp, newlen);
    }

    errno = ENOSYS;
    return -1;
}

static NSString *LHProcessInfoHostNameReplacement(NSProcessInfo *self, SEL selector) {
    (void)self;
    (void)selector;
    return [NSString stringWithUTF8String:LHNetworkSyntheticHostName()];
}

/** Installs a generic low-entropy hostname across common BSD/Foundation paths. */
bool LHMitigation_network_hostname_composite_generic_device_name_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    bool installed = false;
    void *gethostnameTarget = dlsym(RTLD_DEFAULT, "gethostname");
    void *unameTarget = dlsym(RTLD_DEFAULT, "uname");
    void *sysctlTarget = dlsym(RTLD_DEFAULT, "sysctl");
    void *sysctlByNameTarget = dlsym(RTLD_DEFAULT, "sysctlbyname");

    if (gethostnameTarget != 0) {
        installed = LHHookBackendHookFunction(backend, gethostnameTarget, (void *)LHGetHostnameReplacement, (void **)&LHGetHostnameOriginalImplementation) || installed;
    }
    if (unameTarget != 0) {
        installed = LHHookBackendHookFunction(backend, unameTarget, (void *)LHUnameReplacement, (void **)&LHUnameOriginalImplementation) || installed;
    }
    if (sysctlTarget != 0) {
        installed = LHHookBackendHookFunction(backend, sysctlTarget, (void *)LHHostnameSysctlReplacement, (void **)&LHHostnameSysctlOriginalImplementation) || installed;
    }
    if (sysctlByNameTarget != 0) {
        installed = LHHookBackendHookFunction(backend, sysctlByNameTarget, (void *)LHHostnameSysctlByNameReplacement, (void **)&LHHostnameSysctlByNameOriginalImplementation) || installed;
    }

    Class processInfoClass = NSClassFromString(@"NSProcessInfo");
    SEL hostNameSelector = sel_registerName("hostName");
    if (processInfoClass != Nil && hostNameSelector != 0) {
        installed = LHHookBackendHookMessage(backend, processInfoClass, hostNameSelector, (void *)LHProcessInfoHostNameReplacement, (void **)&LHProcessInfoHostNameOriginalImplementation) || installed;
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_network_hostname_composite_generic_device_name);
    }

    return true;
}
