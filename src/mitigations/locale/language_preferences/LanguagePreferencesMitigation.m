#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NSArray<NSString *> *(*LHPreferredLanguagesOriginal)(id self, SEL selector);
typedef id (*LHUserDefaultsObjectForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *key);
typedef NSArray *(*LHUserDefaultsArrayForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *key);
typedef NSArray<NSString *> *(*LHUserDefaultsStringArrayForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *key);

static LHPreferredLanguagesOriginal LHPreferredLanguagesOriginalImplementation;
static LHUserDefaultsObjectForKeyOriginal LHPreferredLanguagesObjectForKeyOriginalImplementation;
static LHUserDefaultsArrayForKeyOriginal LHPreferredLanguagesArrayForKeyOriginalImplementation;
static LHUserDefaultsStringArrayForKeyOriginal LHPreferredLanguagesStringArrayForKeyOriginalImplementation;

static BOOL LHPreferredLanguagesKeyMatches(NSString *key) {
    return [key isKindOfClass:[NSString class]] && [key isEqualToString:@"AppleLanguages"];
}

static NSArray<NSString *> *LHReducedPreferredLanguages(NSArray<NSString *> *original) {
    if (![original isKindOfClass:[NSArray class]] || [original count] <= 1) {
        return original;
    }

    NSString *primary = original[0];
    if (![primary isKindOfClass:[NSString class]] || [primary length] == 0) {
        return original;
    }

    return @[ primary ];
}

static NSArray<NSString *> *LHPreferredLanguagesReplacement(id self, SEL selector) {
    if (LHPreferredLanguagesOriginalImplementation == 0) {
        return nil;
    }
    return LHReducedPreferredLanguages(LHPreferredLanguagesOriginalImplementation(self, selector));
}

static id LHPreferredLanguagesObjectForKeyReplacement(NSUserDefaults *self, SEL selector, NSString *key) {
    if (LHPreferredLanguagesObjectForKeyOriginalImplementation == 0) {
        return nil;
    }
    id original = LHPreferredLanguagesObjectForKeyOriginalImplementation(self, selector, key);
    if (LHPreferredLanguagesKeyMatches(key)) {
        return LHReducedPreferredLanguages(original);
    }
    return original;
}

static NSArray *LHPreferredLanguagesArrayForKeyReplacement(NSUserDefaults *self, SEL selector, NSString *key) {
    if (LHPreferredLanguagesArrayForKeyOriginalImplementation == 0) {
        return nil;
    }
    NSArray *original = LHPreferredLanguagesArrayForKeyOriginalImplementation(self, selector, key);
    if (LHPreferredLanguagesKeyMatches(key)) {
        return LHReducedPreferredLanguages(original);
    }
    return original;
}

static NSArray<NSString *> *LHPreferredLanguagesStringArrayForKeyReplacement(NSUserDefaults *self, SEL selector, NSString *key) {
    if (LHPreferredLanguagesStringArrayForKeyOriginalImplementation == 0) {
        return nil;
    }
    NSArray<NSString *> *original = LHPreferredLanguagesStringArrayForKeyOriginalImplementation(self, selector, key);
    if (LHPreferredLanguagesKeyMatches(key)) {
        return LHReducedPreferredLanguages(original);
    }
    return original;
}

bool LHMitigation_locale_preferred_languages_foundation_primary_only_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"NSLocale");
    Class metaClass = object_getClass(targetClass);
    SEL selector = sel_registerName("preferredLanguages");
    if (targetClass == Nil || metaClass == Nil || selector == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_locale_preferred_languages_foundation_primary_only);
    }

    bool installed = false;
    installed = LHHookBackendHookMessage(backend, metaClass, selector, (void *)LHPreferredLanguagesReplacement, (void **)&LHPreferredLanguagesOriginalImplementation) || installed;

    Class defaultsClass = NSClassFromString(@"NSUserDefaults");
    SEL objectSelector = sel_registerName("objectForKey:");
    SEL arraySelector = sel_registerName("arrayForKey:");
    SEL stringArraySelector = sel_registerName("stringArrayForKey:");
    if (defaultsClass != Nil && objectSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             defaultsClass,
                                             objectSelector,
                                             (void *)LHPreferredLanguagesObjectForKeyReplacement,
                                             (void **)&LHPreferredLanguagesObjectForKeyOriginalImplementation) || installed;
    }
    if (defaultsClass != Nil && arraySelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             defaultsClass,
                                             arraySelector,
                                             (void *)LHPreferredLanguagesArrayForKeyReplacement,
                                             (void **)&LHPreferredLanguagesArrayForKeyOriginalImplementation) || installed;
    }
    if (defaultsClass != Nil && stringArraySelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             defaultsClass,
                                             stringArraySelector,
                                             (void *)LHPreferredLanguagesStringArrayForKeyReplacement,
                                             (void **)&LHPreferredLanguagesStringArrayForKeyOriginalImplementation) || installed;
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_locale_preferred_languages_foundation_primary_only);
    }
    return true;
}
