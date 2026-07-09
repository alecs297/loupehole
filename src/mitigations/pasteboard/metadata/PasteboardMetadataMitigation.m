#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

typedef NSInteger (*LHPasteboardIntegerOriginal)(id self, SEL selector);
typedef BOOL (*LHPasteboardBoolOriginal)(id self, SEL selector);

LH_POLICY_SEED(pasteboard_change_count_base)

static LHPasteboardIntegerOriginal LHPasteboardChangeCountOriginalImplementation;
static LHPasteboardIntegerOriginal LHPasteboardNumberOfItemsOriginalImplementation;
static LHPasteboardBoolOriginal LHPasteboardHasStringsOriginalImplementation;
static LHPasteboardBoolOriginal LHPasteboardHasURLsOriginalImplementation;
static LHPasteboardBoolOriginal LHPasteboardHasImagesOriginalImplementation;
static LHPasteboardBoolOriginal LHPasteboardHasColorsOriginalImplementation;
static LHPolicyEngine *LHPasteboardMetadataPolicy;

static NSInteger LHPasteboardSyntheticChangeCount(void) {
    uint64_t base = 0;
    if (LHPasteboardMetadataPolicy == 0 ||
        !LHMitigationDeriveBoundedU64(&LHPasteboardMetadataPolicy->config.buildSeed,
                                      &LHGeneratedPolicySeed_pasteboard_change_count_base,
                                      &LHPasteboardMetadataPolicy->appContext.scope,
                                      0,
                                      0,
                                      1024,
                                      &base)) {
        return 0;
    }

    return (NSInteger)base;
}

static NSInteger LHPasteboardChangeCountReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return LHPasteboardSyntheticChangeCount();
}

static NSInteger LHPasteboardNumberOfItemsReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return 0;
}

static BOOL LHPasteboardHasItemReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return NO;
}

static bool LHPasteboardHookInteger(LHHookBackend *backend,
                                    Class targetClass,
                                    const char *selectorName,
                                    void *replacement,
                                    LHPasteboardIntegerOriginal *original) {
    SEL selector = sel_registerName(selectorName);
    if (selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, (void **)original);
}

static bool LHPasteboardHookBool(LHHookBackend *backend,
                                 Class targetClass,
                                 const char *selectorName,
                                 void *replacement,
                                 LHPasteboardBoolOriginal *original) {
    SEL selector = sel_registerName(selectorName);
    if (selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, (void **)original);
}

static bool LHPasteboardInstallForClass(LHHookBackend *backend, Class targetClass) {
    bool installed = false;
    installed = LHPasteboardHookInteger(backend,
                                        targetClass,
                                        "changeCount",
                                        (void *)LHPasteboardChangeCountReplacement,
                                        &LHPasteboardChangeCountOriginalImplementation) || installed;
    installed = LHPasteboardHookInteger(backend,
                                        targetClass,
                                        "numberOfItems",
                                        (void *)LHPasteboardNumberOfItemsReplacement,
                                        &LHPasteboardNumberOfItemsOriginalImplementation) || installed;
    installed = LHPasteboardHookBool(backend,
                                     targetClass,
                                     "hasStrings",
                                     (void *)LHPasteboardHasItemReplacement,
                                     &LHPasteboardHasStringsOriginalImplementation) || installed;
    installed = LHPasteboardHookBool(backend,
                                     targetClass,
                                     "hasURLs",
                                     (void *)LHPasteboardHasItemReplacement,
                                     &LHPasteboardHasURLsOriginalImplementation) || installed;
    installed = LHPasteboardHookBool(backend,
                                     targetClass,
                                     "hasImages",
                                     (void *)LHPasteboardHasItemReplacement,
                                     &LHPasteboardHasImagesOriginalImplementation) || installed;
    installed = LHPasteboardHookBool(backend,
                                     targetClass,
                                     "hasColors",
                                     (void *)LHPasteboardHasItemReplacement,
                                     &LHPasteboardHasColorsOriginalImplementation) || installed;
    return installed;
}

/** Installs strict general-pasteboard metadata reduction for UIKit metadata properties. */
bool LHMitigation_pasteboard_metadata_uikit_empty_shape_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHPasteboardMetadataPolicy = policy;

    Class targetClass = NSClassFromString(@"UIPasteboard");
    if (targetClass == Nil) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_pasteboard_metadata_uikit_empty_shape);
    }

    bool installed = false;
    installed = LHPasteboardInstallForClass(backend, targetClass) || installed;

    SEL generalSelector = sel_registerName("generalPasteboard");
    if (generalSelector != 0 && [targetClass respondsToSelector:generalSelector]) {
        id (*messageSend)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        id generalPasteboard = messageSend((id)targetClass, generalSelector);
        Class concreteClass = object_getClass(generalPasteboard);
        if (concreteClass != Nil && concreteClass != targetClass) {
            installed = LHPasteboardInstallForClass(backend, concreteClass) || installed;
        }
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_pasteboard_metadata_uikit_empty_shape);
    }

    return true;
}
