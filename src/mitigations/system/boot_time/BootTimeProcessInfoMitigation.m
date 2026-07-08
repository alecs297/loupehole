#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "BootTimeValues.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NSTimeInterval (*LHSystemUptimeOriginal)(NSProcessInfo *self, SEL selector);

static LHSystemUptimeOriginal LHSystemUptimeOriginalImplementation;
static LHPolicyEngine *LHProcessInfoBootTimePolicy;

/** Replacement for `-[NSProcessInfo systemUptime]`. */
static NSTimeInterval LHSystemUptimeReplacement(NSProcessInfo *self, SEL selector) {
    struct timeval bootTime;
    if (LHBootTimeCopySyntheticBootTime(LHProcessInfoBootTimePolicy, &bootTime)) {
        NSTimeInterval bootTimestamp = (NSTimeInterval)bootTime.tv_sec + ((NSTimeInterval)bootTime.tv_usec / 1000000.0);
        NSTimeInterval uptime = [[NSDate date] timeIntervalSince1970] - bootTimestamp;
        if (uptime >= 0.0) {
            return uptime;
        }
    }

    if (LHSystemUptimeOriginalImplementation != 0) {
        return LHSystemUptimeOriginalImplementation(self, selector);
    }

    return 0.0;
}

/** Installs the NSProcessInfo uptime hook. */
bool LHBootTimeProcessInfoInstall(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHProcessInfoBootTimePolicy = policy;

    Class targetClass = NSClassFromString(@"NSProcessInfo");
    SEL selector = sel_registerName("systemUptime");
    if (targetClass == Nil || selector == 0) {
        return false;
    }

    return LHHookBackendHookMessage(backend, targetClass, selector, (void *)LHSystemUptimeReplacement, (void **)&LHSystemUptimeOriginalImplementation);
}
