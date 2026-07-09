#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <dlfcn.h>

typedef CFArrayRef (*LHCopyFontFamiliesOriginal)(void);
typedef NSArray<NSString *> *(*LHUIFontFamilyNamesOriginal)(id self, SEL selector);
typedef NSArray<NSString *> *(*LHUIFontNamesForFamilyOriginal)(id self, SEL selector, NSString *familyName);

static LHCopyFontFamiliesOriginal LHCopyFontFamiliesOriginalImplementation;
static LHUIFontFamilyNamesOriginal LHUIFontFamilyNamesOriginalImplementation;
static LHUIFontNamesForFamilyOriginal LHUIFontNamesForFamilyOriginalImplementation;

static BOOL LHFontFamilyHasAllowedPrefix(NSString *family) {
    static NSString *prefixes[] = {
        @".Apple",
        @"Academy Engraved",
        @"Al ",
        @"American Typewriter",
        @"Apple",
        @"Arial",
        @"Avenir",
        @"Baghdad",
        @"Beirut",
        @"Bodoni",
        @"Bradley",
        @"Brush Script",
        @"Chalk",
        @"Cochin",
        @"Copperplate",
        @"Courier",
        @"Damascus",
        @"Didot",
        @"DIN ",
        @"Diwan",
        @"Euphemia",
        @"Futura",
        @"Geeza",
        @"Georgia",
        @"Gill Sans",
        @"Helvetica",
        @"Hiragino",
        @"Hoefler",
        @"Iowan",
        @"Kailasa",
        @"Kannada",
        @"Kefa",
        @"Khmer",
        @"Kohinoor",
        @"Lao Sangam",
        @"Malayalam",
        @"Marion",
        @"Marker Felt",
        @"Menlo",
        @"Mishafi",
        @"Myanmar",
        @"New York",
        @"Noteworthy",
        @"Noto",
        @"Optima",
        @"Oriya",
        @"Palatino",
        @"Papyrus",
        @"Party LET",
        @"PingFang",
        @"Rockwell",
        @"Savoye",
        @"SF ",
        @"Sinhala",
        @"Snell Roundhand",
        @"STIX",
        @"Symbol",
        @"Tamil",
        @"Telugu",
        @"Thonburi",
        @"Times",
        @"Trebuchet",
        @"Verdana",
        @"Zapf"
    };

    for (size_t i = 0; i < sizeof(prefixes) / sizeof(prefixes[0]); i++) {
        if ([family hasPrefix:prefixes[i]]) {
            return YES;
        }
    }
    return NO;
}

static BOOL LHFontFamilyIsVisible(NSString *family) {
    if (![family isKindOfClass:[NSString class]] || [family length] == 0) {
        return NO;
    }
    return LHFontFamilyHasAllowedPrefix(family);
}

static NSArray<NSString *> *LHFilteredFontFamilies(NSArray *families) {
    if (![families isKindOfClass:[NSArray class]] || [families count] == 0) {
        return families;
    }

    NSMutableArray<NSString *> *filtered = [NSMutableArray arrayWithCapacity:[families count]];
    for (id family in families) {
        if (LHFontFamilyIsVisible(family)) {
            [filtered addObject:family];
        }
    }

    if ([filtered count] == 0 || [filtered count] == [families count]) {
        return families;
    }
    return filtered;
}

static CFArrayRef LHCopyFontFamiliesReplacement(void) {
    if (LHCopyFontFamiliesOriginalImplementation == 0) {
        return 0;
    }

    CFArrayRef original = LHCopyFontFamiliesOriginalImplementation();
    if (original == 0) {
        return 0;
    }

    NSArray *bridged = (__bridge NSArray *)original;
    NSArray *filtered = LHFilteredFontFamilies(bridged);
    if (filtered == bridged) {
        return original;
    }

    CFRetain((__bridge CFTypeRef)filtered);
    CFRelease(original);
    return (__bridge CFArrayRef)filtered;
}

static NSArray<NSString *> *LHUIFontFamilyNamesReplacement(id self, SEL selector) {
    if (LHUIFontFamilyNamesOriginalImplementation == 0) {
        return nil;
    }
    return LHFilteredFontFamilies(LHUIFontFamilyNamesOriginalImplementation(self, selector));
}

static NSArray<NSString *> *LHUIFontNamesForFamilyReplacement(id self, SEL selector, NSString *familyName) {
    if (!LHFontFamilyIsVisible(familyName)) {
        return @[];
    }
    if (LHUIFontNamesForFamilyOriginalImplementation != 0) {
        return LHUIFontNamesForFamilyOriginalImplementation(self, selector, familyName);
    }
    return nil;
}

static bool LHFontInventoryInstallUIKitHooks(LHHookBackend *backend) {
    Class targetClass = NSClassFromString(@"UIFont");
    Class metaClass = object_getClass(targetClass);
    if (targetClass == Nil || metaClass == Nil) {
        return false;
    }

    bool installed = false;
    SEL familyNamesSelector = sel_registerName("familyNames");
    SEL fontNamesSelector = sel_registerName("fontNamesForFamilyName:");

    if (familyNamesSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             metaClass,
                                             familyNamesSelector,
                                             (void *)LHUIFontFamilyNamesReplacement,
                                             (void **)&LHUIFontFamilyNamesOriginalImplementation) || installed;
    }
    if (fontNamesSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             metaClass,
                                             fontNamesSelector,
                                             (void *)LHUIFontNamesForFamilyReplacement,
                                             (void **)&LHUIFontNamesForFamilyOriginalImplementation) || installed;
    }
    return installed;
}

bool LHMitigation_fonts_family_inventory_coretext_filtered_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    bool installed = false;
    void *copyFamiliesTarget = dlsym(RTLD_DEFAULT, "CTFontManagerCopyAvailableFontFamilyNames");
    if (copyFamiliesTarget != 0) {
        installed = LHHookBackendHookFunction(backend,
                                             copyFamiliesTarget,
                                             (void *)LHCopyFontFamiliesReplacement,
                                             (void **)&LHCopyFontFamiliesOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "CTFontManagerCopyAvailableFontFamilyNames",
                                                (void *)LHCopyFontFamiliesReplacement,
                                                (void **)&LHCopyFontFamiliesOriginalImplementation) || installed;
    installed = LHFontInventoryInstallUIKitHooks(backend) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_fonts_family_inventory_coretext_filtered);
    }
    return true;
}
