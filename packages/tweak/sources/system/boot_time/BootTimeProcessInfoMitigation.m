#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "common/temporal/TemporalLifetimeValues.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NSTimeInterval (*LHSystemUptimeOriginal)(NSProcessInfo *self, SEL selector);

static LHSystemUptimeOriginal LHSystemUptimeOriginalImplementation;
static LHPolicyEngine *LHProcessInfoBootTimePolicy;

static NSTimeInterval LHSystemUptimeReplacement(NSProcessInfo *self, SEL selector) {
    struct timeval bootTime;
    if (LHTemporalLifetimeCopyBootTime(LHProcessInfoBootTimePolicy, &bootTime)) {
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

bool LHBootTimeProcessInfoInstall(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHProcessInfoBootTimePolicy = policy;

    Class targetClass = NSClassFromString(@"NSProcessInfo");
    SEL selector = sel_registerName("systemUptime");
    if (targetClass == Nil || selector == 0) {
        return false;
    }

    return LHHookBackendHookMessage(backend, targetClass, selector, (void *)LHSystemUptimeReplacement, (void **)&LHSystemUptimeOriginalImplementation);
}
