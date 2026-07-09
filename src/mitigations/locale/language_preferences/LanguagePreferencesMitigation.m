#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NSArray<NSString *> *(*LHPreferredLanguagesOriginal)(id self, SEL selector);

static LHPreferredLanguagesOriginal LHPreferredLanguagesOriginalImplementation;

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

bool LHMitigation_locale_preferred_languages_foundation_primary_only_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"NSLocale");
    Class metaClass = object_getClass(targetClass);
    SEL selector = sel_registerName("preferredLanguages");
    if (targetClass == Nil || metaClass == Nil || selector == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_locale_preferred_languages_foundation_primary_only);
    }

    if (!LHHookBackendHookMessage(backend, metaClass, selector, (void *)LHPreferredLanguagesReplacement, (void **)&LHPreferredLanguagesOriginalImplementation)) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_locale_preferred_languages_foundation_primary_only);
    }
    return true;
}
