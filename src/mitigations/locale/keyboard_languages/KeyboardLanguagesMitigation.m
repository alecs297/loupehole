#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NSArray *(*LHActiveInputModesOriginal)(id self, SEL selector);

static LHActiveInputModesOriginal LHActiveInputModesOriginalImplementation;

static NSString *LHKeyboardBaseLanguage(NSString *language) {
    if (![language isKindOfClass:[NSString class]] || [language length] == 0) {
        return nil;
    }

    NSRange dash = [language rangeOfString:@"-"];
    NSRange underscore = [language rangeOfString:@"_"];
    NSUInteger end = [language length];
    if (dash.location != NSNotFound && dash.location < end) {
        end = dash.location;
    }
    if (underscore.location != NSNotFound && underscore.location < end) {
        end = underscore.location;
    }
    if (end == 0) {
        return nil;
    }
    return [[language substringToIndex:end] lowercaseString];
}

static NSString *LHKeyboardPrimaryPreferredBaseLanguage(void) {
    NSArray<NSString *> *preferred = [NSLocale preferredLanguages];
    for (NSString *language in preferred) {
        NSString *base = LHKeyboardBaseLanguage(language);
        if (base != nil && ![base isEqualToString:@"emoji"]) {
            return base;
        }
    }
    return nil;
}

static NSString *LHKeyboardModePrimaryLanguage(id mode) {
    SEL selector = sel_registerName("primaryLanguage");
    if (mode == nil || selector == 0 || ![mode respondsToSelector:selector]) {
        return nil;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id language = [mode performSelector:selector];
#pragma clang diagnostic pop
    return [language isKindOfClass:[NSString class]] ? language : nil;
}

static NSArray *LHFilteredActiveInputModes(NSArray *original) {
    if (![original isKindOfClass:[NSArray class]] || [original count] <= 1) {
        return original;
    }

    NSString *preferredBase = LHKeyboardPrimaryPreferredBaseLanguage();
    if (preferredBase == nil) {
        return original;
    }

    NSMutableArray *filtered = [NSMutableArray array];
    NSUInteger nonEmojiCount = 0;
    for (id mode in original) {
        NSString *language = LHKeyboardModePrimaryLanguage(mode);
        NSString *base = LHKeyboardBaseLanguage(language);
        if (base == nil || [base isEqualToString:@"emoji"] || [base isEqualToString:preferredBase]) {
            [filtered addObject:mode];
            if (![base isEqualToString:@"emoji"]) {
                nonEmojiCount++;
            }
        }
    }

    if (nonEmojiCount == 0 || [filtered count] == [original count]) {
        return original;
    }
    return filtered;
}

static NSArray *LHActiveInputModesReplacement(id self, SEL selector) {
    if (LHActiveInputModesOriginalImplementation == 0) {
        return nil;
    }
    return LHFilteredActiveInputModes(LHActiveInputModesOriginalImplementation(self, selector));
}

bool LHMitigation_locale_keyboard_languages_uikit_primary_only_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"UITextInputMode");
    Class metaClass = object_getClass(targetClass);
    SEL selector = sel_registerName("activeInputModes");
    if (targetClass == Nil || metaClass == Nil || selector == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_locale_keyboard_languages_uikit_primary_only);
    }

    if (!LHHookBackendHookMessage(backend, metaClass, selector, (void *)LHActiveInputModesReplacement, (void **)&LHActiveInputModesOriginalImplementation)) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_locale_keyboard_languages_uikit_primary_only);
    }
    return true;
}
