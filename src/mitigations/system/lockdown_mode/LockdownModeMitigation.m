#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef BOOL (*LHUserDefaultsBoolForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *key);
typedef NSInteger (*LHUserDefaultsIntegerForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *key);
typedef id (*LHUserDefaultsObjectForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *key);

static LHUserDefaultsBoolForKeyOriginal LHLockdownBoolForKeyOriginalImplementation;
static LHUserDefaultsIntegerForKeyOriginal LHLockdownIntegerForKeyOriginalImplementation;
static LHUserDefaultsObjectForKeyOriginal LHLockdownObjectForKeyOriginalImplementation;

static BOOL LHLockdownModeKeyMatches(NSString *key) {
    return [key isKindOfClass:[NSString class]] && [key isEqualToString:@"LDMGlobalEnabled"];
}

static BOOL LHLockdownBoolForKeyReplacement(NSUserDefaults *self, SEL selector, NSString *key) {
    if (LHLockdownModeKeyMatches(key)) {
        return NO;
    }
    if (LHLockdownBoolForKeyOriginalImplementation != 0) {
        return LHLockdownBoolForKeyOriginalImplementation(self, selector, key);
    }
    return NO;
}

static NSInteger LHLockdownIntegerForKeyReplacement(NSUserDefaults *self, SEL selector, NSString *key) {
    if (LHLockdownModeKeyMatches(key)) {
        return 0;
    }
    if (LHLockdownIntegerForKeyOriginalImplementation != 0) {
        return LHLockdownIntegerForKeyOriginalImplementation(self, selector, key);
    }
    return 0;
}

static id LHLockdownObjectForKeyReplacement(NSUserDefaults *self, SEL selector, NSString *key) {
    if (LHLockdownModeKeyMatches(key)) {
        return @NO;
    }
    if (LHLockdownObjectForKeyOriginalImplementation != 0) {
        return LHLockdownObjectForKeyOriginalImplementation(self, selector, key);
    }
    return nil;
}

bool LHMitigation_system_lockdown_mode_userdefaults_common_false_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"NSUserDefaults");
    if (targetClass == Nil) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_system_lockdown_mode_userdefaults_common_false);
    }

    bool installed = false;
    SEL boolSelector = sel_registerName("boolForKey:");
    SEL integerSelector = sel_registerName("integerForKey:");
    SEL objectSelector = sel_registerName("objectForKey:");

    if (boolSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             targetClass,
                                             boolSelector,
                                             (void *)LHLockdownBoolForKeyReplacement,
                                             (void **)&LHLockdownBoolForKeyOriginalImplementation) || installed;
    }
    if (integerSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             targetClass,
                                             integerSelector,
                                             (void *)LHLockdownIntegerForKeyReplacement,
                                             (void **)&LHLockdownIntegerForKeyOriginalImplementation) || installed;
    }
    if (objectSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             targetClass,
                                             objectSelector,
                                             (void *)LHLockdownObjectForKeyReplacement,
                                             (void **)&LHLockdownObjectForKeyOriginalImplementation) || installed;
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_system_lockdown_mode_userdefaults_common_false);
    }
    return true;
}
