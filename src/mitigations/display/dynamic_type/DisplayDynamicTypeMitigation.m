#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

typedef NSString *(*LHDynamicTypeOriginal)(id self, SEL selector);

static LHDynamicTypeOriginal LHTraitContentSizeOriginalImplementation;
static LHDynamicTypeOriginal LHApplicationContentSizeOriginalImplementation;

static NSString *LHDynamicTypeBucket(NSString *category) {
    if (![category isKindOfClass:[NSString class]]) {
        return category;
    }

    if ([category isEqualToString:UIContentSizeCategoryAccessibilityMedium] ||
        [category isEqualToString:UIContentSizeCategoryAccessibilityLarge] ||
        [category isEqualToString:UIContentSizeCategoryAccessibilityExtraLarge] ||
        [category isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraLarge] ||
        [category isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
        return UIContentSizeCategoryAccessibilityLarge;
    }

    if ([category isEqualToString:UIContentSizeCategoryExtraSmall] ||
        [category isEqualToString:UIContentSizeCategorySmall] ||
        [category isEqualToString:UIContentSizeCategoryMedium] ||
        [category isEqualToString:UIContentSizeCategoryLarge] ||
        [category isEqualToString:UIContentSizeCategoryExtraLarge] ||
        [category isEqualToString:UIContentSizeCategoryExtraExtraLarge] ||
        [category isEqualToString:UIContentSizeCategoryExtraExtraExtraLarge]) {
        return UIContentSizeCategoryLarge;
    }

    return category;
}

static NSString *LHDynamicTypeReplacement(id self, SEL selector, LHDynamicTypeOriginal original) {
    if (original == 0) {
        return nil;
    }
    return LHDynamicTypeBucket(original(self, selector));
}

static NSString *LHTraitContentSizeReplacement(id self, SEL selector) {
    return LHDynamicTypeReplacement(self, selector, LHTraitContentSizeOriginalImplementation);
}

static NSString *LHApplicationContentSizeReplacement(id self, SEL selector) {
    return LHDynamicTypeReplacement(self, selector, LHApplicationContentSizeOriginalImplementation);
}

static bool LHDynamicTypeHook(LHHookBackend *backend, Class targetClass, const char *selectorName, void *replacement, void **original) {
    SEL selector = sel_registerName(selectorName);
    if (targetClass == Nil || selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original);
}

bool LHMitigation_display_dynamic_type_uikit_bucketed_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    bool installed = false;
    installed = LHDynamicTypeHook(backend,
                                  NSClassFromString(@"UITraitCollection"),
                                  "preferredContentSizeCategory",
                                  (void *)LHTraitContentSizeReplacement,
                                  (void **)&LHTraitContentSizeOriginalImplementation) || installed;
    installed = LHDynamicTypeHook(backend,
                                  NSClassFromString(@"UIApplication"),
                                  "preferredContentSizeCategory",
                                  (void *)LHApplicationContentSizeReplacement,
                                  (void **)&LHApplicationContentSizeOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_display_dynamic_type_uikit_bucketed);
    }
    return true;
}
