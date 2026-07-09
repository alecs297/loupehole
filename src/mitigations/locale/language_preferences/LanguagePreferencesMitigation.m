#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <dlfcn.h>

typedef NSArray<NSString *> *(*LHPreferredLanguagesOriginal)(id self, SEL selector);
typedef id (*LHUserDefaultsObjectForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *key);
typedef NSArray *(*LHUserDefaultsArrayForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *key);
typedef NSArray<NSString *> *(*LHUserDefaultsStringArrayForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *key);
typedef CFArrayRef (*LHCFLocaleCopyPreferredLanguagesOriginal)(void);
typedef CFPropertyListRef (*LHCFPreferencesCopyAppValueOriginal)(CFStringRef key, CFStringRef applicationID);

static LHPreferredLanguagesOriginal LHPreferredLanguagesOriginalImplementation;
static LHUserDefaultsObjectForKeyOriginal LHPreferredLanguagesObjectForKeyOriginalImplementation;
static LHUserDefaultsArrayForKeyOriginal LHPreferredLanguagesArrayForKeyOriginalImplementation;
static LHUserDefaultsStringArrayForKeyOriginal LHPreferredLanguagesStringArrayForKeyOriginalImplementation;
static LHCFLocaleCopyPreferredLanguagesOriginal LHCFLocaleCopyPreferredLanguagesOriginalImplementation;
static LHCFPreferencesCopyAppValueOriginal LHCFPreferencesCopyAppValueOriginalImplementation;

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

static CFArrayRef LHCreateReducedPreferredLanguagesCopy(CFArrayRef original) {
    if (original == 0 || CFGetTypeID(original) != CFArrayGetTypeID() || CFArrayGetCount(original) <= 1) {
        return original == 0 ? 0 : (CFArrayRef)CFRetain(original);
    }

    CFTypeRef primary = CFArrayGetValueAtIndex(original, 0);
    if (primary == 0 || CFGetTypeID(primary) != CFStringGetTypeID() || CFStringGetLength((CFStringRef)primary) == 0) {
        return (CFArrayRef)CFRetain(original);
    }

    const void *values[] = { primary };
    return CFArrayCreate(kCFAllocatorDefault, values, 1, &kCFTypeArrayCallBacks);
}

static BOOL LHCFPreferredLanguagesKeyMatches(CFStringRef key) {
    return key != 0 && CFGetTypeID(key) == CFStringGetTypeID() && CFStringCompare(key, CFSTR("AppleLanguages"), 0) == kCFCompareEqualTo;
}

static NSArray<NSString *> *LHPreferredLanguagesReplacement(id self, SEL selector) {
    if (LHPreferredLanguagesOriginalImplementation == 0) {
        return nil;
    }
    return LHReducedPreferredLanguages(LHPreferredLanguagesOriginalImplementation(self, selector));
}

static CFArrayRef LHCFLocaleCopyPreferredLanguagesReplacement(void) {
    if (LHCFLocaleCopyPreferredLanguagesOriginalImplementation == 0) {
        return 0;
    }
    CFArrayRef original = LHCFLocaleCopyPreferredLanguagesOriginalImplementation();
    CFArrayRef reduced = LHCreateReducedPreferredLanguagesCopy(original);
    if (original != 0) {
        CFRelease(original);
    }
    return reduced;
}

static CFPropertyListRef LHCFPreferencesCopyAppValueReplacement(CFStringRef key, CFStringRef applicationID) {
    if (LHCFPreferencesCopyAppValueOriginalImplementation == 0) {
        return 0;
    }
    CFPropertyListRef original = LHCFPreferencesCopyAppValueOriginalImplementation(key, applicationID);
    if (LHCFPreferredLanguagesKeyMatches(key) && original != 0 && CFGetTypeID(original) == CFArrayGetTypeID()) {
        CFArrayRef reduced = LHCreateReducedPreferredLanguagesCopy((CFArrayRef)original);
        CFRelease(original);
        return reduced;
    }
    return original;
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

    void *cfLocaleTarget = dlsym(RTLD_DEFAULT, "CFLocaleCopyPreferredLanguages");
    if (cfLocaleTarget != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              cfLocaleTarget,
                                              (void *)LHCFLocaleCopyPreferredLanguagesReplacement,
                                              (void **)&LHCFLocaleCopyPreferredLanguagesOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "CFLocaleCopyPreferredLanguages",
                                                (void *)LHCFLocaleCopyPreferredLanguagesReplacement,
                                                (void **)&LHCFLocaleCopyPreferredLanguagesOriginalImplementation) || installed;

    void *cfPreferencesTarget = dlsym(RTLD_DEFAULT, "CFPreferencesCopyAppValue");
    if (cfPreferencesTarget != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              cfPreferencesTarget,
                                              (void *)LHCFPreferencesCopyAppValueReplacement,
                                              (void **)&LHCFPreferencesCopyAppValueOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "CFPreferencesCopyAppValue",
                                                (void *)LHCFPreferencesCopyAppValueReplacement,
                                                (void **)&LHCFPreferencesCopyAppValueOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_locale_preferred_languages_foundation_primary_only);
    }
    return true;
}
