#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NSArray<NSString *> *(*LHPreferredLanguagesOriginal)(id self, SEL selector);
typedef id (*LHUserDefaultsObjectForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *key);
typedef NSArray *(*LHUserDefaultsArrayForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *key);
typedef NSArray<NSString *> *(*LHUserDefaultsStringArrayForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *key);
typedef NSDictionary *(*LHUserDefaultsDictionaryRepresentationOriginal)(NSUserDefaults *self, SEL selector);
typedef NSDictionary *(*LHUserDefaultsDomainOriginal)(NSUserDefaults *self, SEL selector, NSString *domainName);
typedef CFArrayRef (*LHCFLocaleCopyPreferredLanguagesOriginal)(void);
typedef CFPropertyListRef (*LHCFPreferencesCopyAppValueOriginal)(CFStringRef key, CFStringRef applicationID);
typedef CFPropertyListRef (*LHCFPreferencesCopyValueOriginal)(CFStringRef key,
                                                              CFStringRef applicationID,
                                                              CFStringRef userName,
                                                              CFStringRef hostName);
typedef CFDictionaryRef (*LHCFPreferencesCopyMultipleOriginal)(CFArrayRef keysToFetch,
                                                               CFStringRef applicationID,
                                                               CFStringRef userName,
                                                               CFStringRef hostName);

static LHPreferredLanguagesOriginal LHPreferredLanguagesOriginalImplementation;
static LHUserDefaultsObjectForKeyOriginal LHPreferredLanguagesObjectForKeyOriginalImplementation;
static LHUserDefaultsArrayForKeyOriginal LHPreferredLanguagesArrayForKeyOriginalImplementation;
static LHUserDefaultsStringArrayForKeyOriginal LHPreferredLanguagesStringArrayForKeyOriginalImplementation;
static LHUserDefaultsDictionaryRepresentationOriginal LHPreferredLanguagesDictionaryRepresentationOriginalImplementation;
static LHUserDefaultsDomainOriginal LHPreferredLanguagesPersistentDomainOriginalImplementation;
static LHUserDefaultsDomainOriginal LHPreferredLanguagesVolatileDomainOriginalImplementation;
static LHCFLocaleCopyPreferredLanguagesOriginal LHCFLocaleCopyPreferredLanguagesOriginalImplementation;
static LHCFPreferencesCopyAppValueOriginal LHCFPreferencesCopyAppValueOriginalImplementation;
static LHCFPreferencesCopyValueOriginal LHCFPreferencesCopyValueOriginalImplementation;
static LHCFPreferencesCopyMultipleOriginal LHCFPreferencesCopyMultipleOriginalImplementation;
static __thread unsigned int LHPreferredLanguagesReplacementDepth;

#define LH_PREFERRED_LANGUAGES_CALL_ORIGINAL(result, expression) \
    do { \
        LHPreferredLanguagesReplacementDepth++; \
        @try { \
            (result) = (expression); \
        } @finally { \
            LHPreferredLanguagesReplacementDepth--; \
        } \
    } while (0)

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

static NSDictionary *LHReducedPreferredLanguagesDictionary(NSDictionary *original) {
    if (![original isKindOfClass:[NSDictionary class]]) {
        return original;
    }

    id languages = [original objectForKey:@"AppleLanguages"];
    NSArray *reduced = LHReducedPreferredLanguages(languages);
    if (reduced == languages || [reduced isEqual:languages]) {
        return original;
    }

    NSMutableDictionary *copy = [original mutableCopy];
    if (copy == nil) {
        return original;
    }
    [copy setObject:reduced forKey:@"AppleLanguages"];
    return [copy autorelease];
}

static CFPropertyListRef LHCreateReducedPreferredLanguagesValueCopy(CFStringRef key, CFPropertyListRef original) {
    if (!LHCFPreferredLanguagesKeyMatches(key) || original == 0 || CFGetTypeID(original) != CFArrayGetTypeID()) {
        return original == 0 ? 0 : (CFPropertyListRef)CFRetain(original);
    }
    return (CFPropertyListRef)LHCreateReducedPreferredLanguagesCopy((CFArrayRef)original);
}

static CFDictionaryRef LHCreateReducedPreferredLanguagesDictionaryCopy(CFDictionaryRef original) {
    if (original == 0 || CFGetTypeID(original) != CFDictionaryGetTypeID()) {
        return original == 0 ? 0 : (CFDictionaryRef)CFRetain(original);
    }

    CFTypeRef languages = CFDictionaryGetValue(original, CFSTR("AppleLanguages"));
    if (languages == 0 || CFGetTypeID(languages) != CFArrayGetTypeID()) {
        return (CFDictionaryRef)CFRetain(original);
    }

    CFArrayRef reduced = LHCreateReducedPreferredLanguagesCopy((CFArrayRef)languages);
    if (reduced == 0) {
        return (CFDictionaryRef)CFRetain(original);
    }
    if (CFEqual(reduced, languages)) {
        CFRelease(reduced);
        return (CFDictionaryRef)CFRetain(original);
    }

    CFMutableDictionaryRef copy = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, original);
    if (copy == 0) {
        CFRelease(reduced);
        return (CFDictionaryRef)CFRetain(original);
    }
    CFDictionarySetValue(copy, CFSTR("AppleLanguages"), reduced);
    CFRelease(reduced);
    return copy;
}

static NSArray<NSString *> *LHPreferredLanguagesReplacement(id self, SEL selector) {
    if (LHPreferredLanguagesOriginalImplementation == 0) {
        return nil;
    }
    if (LHPreferredLanguagesReplacementDepth != 0) {
        return LHPreferredLanguagesOriginalImplementation(self, selector);
    }

    NSArray<NSString *> *original = nil;
    LH_PREFERRED_LANGUAGES_CALL_ORIGINAL(original, LHPreferredLanguagesOriginalImplementation(self, selector));
    return LHReducedPreferredLanguages(original);
}

static CFArrayRef LHCFLocaleCopyPreferredLanguagesReplacement(void) {
    if (LHCFLocaleCopyPreferredLanguagesOriginalImplementation == 0) {
        return 0;
    }
    if (LHPreferredLanguagesReplacementDepth != 0) {
        return LHCFLocaleCopyPreferredLanguagesOriginalImplementation();
    }

    CFArrayRef original = 0;
    LH_PREFERRED_LANGUAGES_CALL_ORIGINAL(original, LHCFLocaleCopyPreferredLanguagesOriginalImplementation());
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
    if (LHPreferredLanguagesReplacementDepth != 0) {
        return LHCFPreferencesCopyAppValueOriginalImplementation(key, applicationID);
    }

    CFPropertyListRef original = 0;
    LH_PREFERRED_LANGUAGES_CALL_ORIGINAL(original, LHCFPreferencesCopyAppValueOriginalImplementation(key, applicationID));
    CFPropertyListRef reduced = LHCreateReducedPreferredLanguagesValueCopy(key, original);
    if (original != 0) {
        CFRelease(original);
    }
    return reduced;
}

static CFPropertyListRef LHCFPreferencesCopyValueReplacement(CFStringRef key,
                                                             CFStringRef applicationID,
                                                             CFStringRef userName,
                                                             CFStringRef hostName) {
    if (LHCFPreferencesCopyValueOriginalImplementation == 0) {
        return 0;
    }
    if (LHPreferredLanguagesReplacementDepth != 0) {
        return LHCFPreferencesCopyValueOriginalImplementation(key, applicationID, userName, hostName);
    }

    CFPropertyListRef original = 0;
    LH_PREFERRED_LANGUAGES_CALL_ORIGINAL(original, LHCFPreferencesCopyValueOriginalImplementation(key, applicationID, userName, hostName));
    CFPropertyListRef reduced = LHCreateReducedPreferredLanguagesValueCopy(key, original);
    if (original != 0) {
        CFRelease(original);
    }
    return reduced;
}

static CFDictionaryRef LHCFPreferencesCopyMultipleReplacement(CFArrayRef keysToFetch,
                                                              CFStringRef applicationID,
                                                              CFStringRef userName,
                                                              CFStringRef hostName) {
    if (LHCFPreferencesCopyMultipleOriginalImplementation == 0) {
        return 0;
    }
    if (LHPreferredLanguagesReplacementDepth != 0) {
        return LHCFPreferencesCopyMultipleOriginalImplementation(keysToFetch, applicationID, userName, hostName);
    }

    CFDictionaryRef original = 0;
    LH_PREFERRED_LANGUAGES_CALL_ORIGINAL(original, LHCFPreferencesCopyMultipleOriginalImplementation(keysToFetch, applicationID, userName, hostName));
    CFDictionaryRef reduced = LHCreateReducedPreferredLanguagesDictionaryCopy(original);
    if (original != 0) {
        CFRelease(original);
    }
    return reduced;
}

static id LHPreferredLanguagesObjectForKeyReplacement(NSUserDefaults *self, SEL selector, NSString *key) {
    if (LHPreferredLanguagesObjectForKeyOriginalImplementation == 0) {
        return nil;
    }
    if (LHPreferredLanguagesReplacementDepth != 0) {
        return LHPreferredLanguagesObjectForKeyOriginalImplementation(self, selector, key);
    }

    id original = nil;
    LH_PREFERRED_LANGUAGES_CALL_ORIGINAL(original, LHPreferredLanguagesObjectForKeyOriginalImplementation(self, selector, key));
    if (LHPreferredLanguagesKeyMatches(key)) {
        return LHReducedPreferredLanguages(original);
    }
    return original;
}

static NSArray *LHPreferredLanguagesArrayForKeyReplacement(NSUserDefaults *self, SEL selector, NSString *key) {
    if (LHPreferredLanguagesArrayForKeyOriginalImplementation == 0) {
        return nil;
    }
    if (LHPreferredLanguagesReplacementDepth != 0) {
        return LHPreferredLanguagesArrayForKeyOriginalImplementation(self, selector, key);
    }

    NSArray *original = nil;
    LH_PREFERRED_LANGUAGES_CALL_ORIGINAL(original, LHPreferredLanguagesArrayForKeyOriginalImplementation(self, selector, key));
    if (LHPreferredLanguagesKeyMatches(key)) {
        return LHReducedPreferredLanguages(original);
    }
    return original;
}

static NSArray<NSString *> *LHPreferredLanguagesStringArrayForKeyReplacement(NSUserDefaults *self, SEL selector, NSString *key) {
    if (LHPreferredLanguagesStringArrayForKeyOriginalImplementation == 0) {
        return nil;
    }
    if (LHPreferredLanguagesReplacementDepth != 0) {
        return LHPreferredLanguagesStringArrayForKeyOriginalImplementation(self, selector, key);
    }

    NSArray<NSString *> *original = nil;
    LH_PREFERRED_LANGUAGES_CALL_ORIGINAL(original, LHPreferredLanguagesStringArrayForKeyOriginalImplementation(self, selector, key));
    if (LHPreferredLanguagesKeyMatches(key)) {
        return LHReducedPreferredLanguages(original);
    }
    return original;
}

static NSDictionary *LHPreferredLanguagesDictionaryRepresentationReplacement(NSUserDefaults *self, SEL selector) {
    if (LHPreferredLanguagesDictionaryRepresentationOriginalImplementation == 0) {
        return nil;
    }
    if (LHPreferredLanguagesReplacementDepth != 0) {
        return LHPreferredLanguagesDictionaryRepresentationOriginalImplementation(self, selector);
    }

    NSDictionary *original = nil;
    LH_PREFERRED_LANGUAGES_CALL_ORIGINAL(original, LHPreferredLanguagesDictionaryRepresentationOriginalImplementation(self, selector));
    return LHReducedPreferredLanguagesDictionary(original);
}

static NSDictionary *LHPreferredLanguagesPersistentDomainReplacement(NSUserDefaults *self, SEL selector, NSString *domainName) {
    if (LHPreferredLanguagesPersistentDomainOriginalImplementation == 0) {
        return nil;
    }
    if (LHPreferredLanguagesReplacementDepth != 0) {
        return LHPreferredLanguagesPersistentDomainOriginalImplementation(self, selector, domainName);
    }

    NSDictionary *original = nil;
    LH_PREFERRED_LANGUAGES_CALL_ORIGINAL(original, LHPreferredLanguagesPersistentDomainOriginalImplementation(self, selector, domainName));
    return LHReducedPreferredLanguagesDictionary(original);
}

static NSDictionary *LHPreferredLanguagesVolatileDomainReplacement(NSUserDefaults *self, SEL selector, NSString *domainName) {
    if (LHPreferredLanguagesVolatileDomainOriginalImplementation == 0) {
        return nil;
    }
    if (LHPreferredLanguagesReplacementDepth != 0) {
        return LHPreferredLanguagesVolatileDomainOriginalImplementation(self, selector, domainName);
    }

    NSDictionary *original = nil;
    LH_PREFERRED_LANGUAGES_CALL_ORIGINAL(original, LHPreferredLanguagesVolatileDomainOriginalImplementation(self, selector, domainName));
    return LHReducedPreferredLanguagesDictionary(original);
}

bool LHMitigation_locale_preferred_languages_foundation_primary_only_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    bool installed = false;
    Class targetClass = NSClassFromString(@"NSLocale");
    Class metaClass = object_getClass(targetClass);
    SEL selector = sel_registerName("preferredLanguages");
    if (targetClass != Nil && metaClass != Nil && selector != 0) {
        installed = LHHookBackendHookMessage(backend, metaClass, selector, (void *)LHPreferredLanguagesReplacement, (void **)&LHPreferredLanguagesOriginalImplementation) || installed;
    }

    Class defaultsClass = NSClassFromString(@"NSUserDefaults");
    SEL objectSelector = sel_registerName("objectForKey:");
    SEL arraySelector = sel_registerName("arrayForKey:");
    SEL stringArraySelector = sel_registerName("stringArrayForKey:");
    SEL dictionaryRepresentationSelector = sel_registerName("dictionaryRepresentation");
    SEL persistentDomainSelector = sel_registerName("persistentDomainForName:");
    SEL volatileDomainSelector = sel_registerName("volatileDomainForName:");
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
    if (defaultsClass != Nil && dictionaryRepresentationSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             defaultsClass,
                                             dictionaryRepresentationSelector,
                                             (void *)LHPreferredLanguagesDictionaryRepresentationReplacement,
                                             (void **)&LHPreferredLanguagesDictionaryRepresentationOriginalImplementation) || installed;
    }
    if (defaultsClass != Nil && persistentDomainSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             defaultsClass,
                                             persistentDomainSelector,
                                             (void *)LHPreferredLanguagesPersistentDomainReplacement,
                                             (void **)&LHPreferredLanguagesPersistentDomainOriginalImplementation) || installed;
    }
    if (defaultsClass != Nil && volatileDomainSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             defaultsClass,
                                             volatileDomainSelector,
                                             (void *)LHPreferredLanguagesVolatileDomainReplacement,
                                             (void **)&LHPreferredLanguagesVolatileDomainOriginalImplementation) || installed;
    }

    installed = LHHookBackendHookImportedSymbol(backend,
                                                "CFLocaleCopyPreferredLanguages",
                                                (void *)LHCFLocaleCopyPreferredLanguagesReplacement,
                                                (void **)&LHCFLocaleCopyPreferredLanguagesOriginalImplementation) || installed;

    installed = LHHookBackendHookImportedSymbol(backend,
                                                "CFPreferencesCopyAppValue",
                                                (void *)LHCFPreferencesCopyAppValueReplacement,
                                                (void **)&LHCFPreferencesCopyAppValueOriginalImplementation) || installed;

    installed = LHHookBackendHookImportedSymbol(backend,
                                                "CFPreferencesCopyValue",
                                                (void *)LHCFPreferencesCopyValueReplacement,
                                                (void **)&LHCFPreferencesCopyValueOriginalImplementation) || installed;

    installed = LHHookBackendHookImportedSymbol(backend,
                                                "CFPreferencesCopyMultiple",
                                                (void *)LHCFPreferencesCopyMultipleReplacement,
                                                (void **)&LHCFPreferencesCopyMultipleOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_locale_preferred_languages_foundation_primary_only);
    }
    return true;
}
