#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

typedef NSInteger (*LHPasteboardIntegerOriginal)(id self, SEL selector);

LH_POLICY_SEED(pasteboard_change_count_base)

static LHPasteboardIntegerOriginal LHPasteboardChangeCountOriginalImplementation;
static LHPolicyEngine *LHPasteboardMetadataPolicy;
static BOOL LHPasteboardObservedBaseInitialized;
static NSInteger LHPasteboardObservedBase;

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
    NSInteger base = LHPasteboardSyntheticChangeCount();
    if (LHPasteboardChangeCountOriginalImplementation == 0) {
        return base;
    }

    NSInteger current = LHPasteboardChangeCountOriginalImplementation(self, selector);
    if (!LHPasteboardObservedBaseInitialized) {
        LHPasteboardObservedBase = current;
        LHPasteboardObservedBaseInitialized = YES;
    }

    NSInteger delta = current - LHPasteboardObservedBase;
    if (delta < 0) {
        delta = 0;
    }
    return base + delta;
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

static bool LHPasteboardInstallForClass(LHHookBackend *backend, Class targetClass) {
    bool installed = false;
    installed = LHPasteboardHookInteger(backend,
                                        targetClass,
                                        "changeCount",
                                        (void *)LHPasteboardChangeCountReplacement,
                                        &LHPasteboardChangeCountOriginalImplementation) || installed;
    return installed;
}

/** Installs general-pasteboard change-count reduction for UIKit metadata properties. */
bool LHMitigation_pasteboard_metadata_uikit_change_count_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHPasteboardMetadataPolicy = policy;

    Class targetClass = NSClassFromString(@"UIPasteboard");
    if (targetClass == Nil) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_pasteboard_metadata_uikit_change_count);
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
        return LHHookBackendRegisterNoOp(backend, LHModuleID_pasteboard_metadata_uikit_change_count);
    }

    return true;
}
