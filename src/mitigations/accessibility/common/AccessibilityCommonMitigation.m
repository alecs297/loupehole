#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#include <stdlib.h>

typedef BOOL (*LHAccessibilityBooleanOriginal)(id self, SEL selector);
typedef BOOL (*LHAccessibilityDarkerSystemColorsFunctionOriginal)(void);
typedef UIAccessibilityContrast (*LHAccessibilityContrastOriginal)(UITraitCollection *self, SEL selector);

static LHAccessibilityBooleanOriginal LHAccessibilityBooleanOriginalImplementations[19];
static LHAccessibilityDarkerSystemColorsFunctionOriginal LHAccessibilityDarkerSystemColorsFunctionOriginalImplementation;
static LHAccessibilityContrastOriginal LHAccessibilityContrastOriginalImplementations[64];

static BOOL LHAccessibilityReturnFalse(id self, SEL selector) {
    (void)self;
    (void)selector;
    return NO;
}

static BOOL LHAccessibilityReturnTrue(id self, SEL selector) {
    (void)self;
    (void)selector;
    return YES;
}

static UIAccessibilityContrast LHAccessibilityContrastReplacement(UITraitCollection *self, SEL selector) {
    (void)self;
    (void)selector;
    return UIAccessibilityContrastNormal;
}

static BOOL LHAccessibilityDarkerSystemColorsFunctionReplacement(void) {
    return NO;
}

static bool LHAccessibilityHookBoolean(LHHookBackend *backend,
                                       Class targetClass,
                                       const char *selectorName,
                                       void *replacement,
                                       LHAccessibilityBooleanOriginal *original) {
    SEL selector = sel_registerName(selectorName);
    if (targetClass == Nil || selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, (void **)original);
}

static bool LHAccessibilityClassIsTraitCollectionSubclass(Class candidate, Class traitCollectionClass) {
    for (Class current = candidate; current != Nil; current = class_getSuperclass(current)) {
        if (current == traitCollectionClass) {
            return true;
        }
    }
    return false;
}

static bool LHAccessibilityHookContrastClasses(LHHookBackend *backend, Class traitCollectionClass) {
    SEL contrastSelector = sel_registerName("accessibilityContrast");
    if (traitCollectionClass == Nil || contrastSelector == 0) {
        return false;
    }

    bool installed = false;
    size_t originalIndex = 0;
    int classCount = objc_getClassList(NULL, 0);
    if (classCount <= 0) {
        return LHHookBackendHookMessage(backend,
                                        traitCollectionClass,
                                        contrastSelector,
                                        (void *)LHAccessibilityContrastReplacement,
                                        (void **)&LHAccessibilityContrastOriginalImplementations[originalIndex]);
    }

    Class *classes = (Class *)calloc((size_t)classCount, sizeof(Class));
    if (classes == 0) {
        return false;
    }

    int actualCount = objc_getClassList(classes, classCount);
    for (int index = 0; index < actualCount && originalIndex < (sizeof(LHAccessibilityContrastOriginalImplementations) / sizeof(LHAccessibilityContrastOriginalImplementations[0])); index++) {
        Class candidate = classes[index];
        if (!LHAccessibilityClassIsTraitCollectionSubclass(candidate, traitCollectionClass) ||
            class_getInstanceMethod(candidate, contrastSelector) == 0) {
            continue;
        }

        installed = LHHookBackendHookMessage(backend,
                                             candidate,
                                             contrastSelector,
                                             (void *)LHAccessibilityContrastReplacement,
                                             (void **)&LHAccessibilityContrastOriginalImplementations[originalIndex++]) || installed;
    }
    free(classes);
    return installed;
}

bool LHMitigation_accessibility_common_preferences_uikit_normalized_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class accessibilityClass = object_getClass(NSClassFromString(@"UIAccessibility"));
    Class traitCollectionClass = NSClassFromString(@"UITraitCollection");
    bool installed = false;
    size_t index = 0;

    static const char *falseSelectors[] = {
        "isVoiceOverRunning",
        "isSwitchControlRunning",
        "isGuidedAccessEnabled",
        "isGrayscaleEnabled",
        "isInvertColorsEnabled",
        "isReduceMotionEnabled",
        "isAssistiveTouchRunning",
        "isBoldTextEnabled",
        "isDarkerSystemColorsEnabled",
        "isReduceTransparencyEnabled",
        "isMonoAudioEnabled",
        "isSpeakScreenEnabled",
        "isSpeakSelectionEnabled",
        "isClosedCaptioningEnabled",
        "shouldDifferentiateWithoutColor",
        "buttonShapesEnabled",
        "isOnOffSwitchLabelsEnabled",
    };
    for (size_t i = 0; i < sizeof(falseSelectors) / sizeof(falseSelectors[0]); i++) {
        installed = LHAccessibilityHookBoolean(backend,
                                               accessibilityClass,
                                               falseSelectors[i],
                                               (void *)LHAccessibilityReturnFalse,
                                               &LHAccessibilityBooleanOriginalImplementations[index++]) || installed;
    }

    installed = LHAccessibilityHookBoolean(backend,
                                           accessibilityClass,
                                           "isShakeToUndoEnabled",
                                           (void *)LHAccessibilityReturnTrue,
                                           &LHAccessibilityBooleanOriginalImplementations[index++]) || installed;
    installed = LHAccessibilityHookBoolean(backend,
                                           accessibilityClass,
                                           "isVideoAutoplayEnabled",
                                           (void *)LHAccessibilityReturnTrue,
                                           &LHAccessibilityBooleanOriginalImplementations[index++]) || installed;

    void *darkerSystemColorsTarget = dlsym(RTLD_DEFAULT, "UIAccessibilityDarkerSystemColorsEnabled");
    if (darkerSystemColorsTarget != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              darkerSystemColorsTarget,
                                              (void *)LHAccessibilityDarkerSystemColorsFunctionReplacement,
                                              (void **)&LHAccessibilityDarkerSystemColorsFunctionOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "UIAccessibilityDarkerSystemColorsEnabled",
                                                (void *)LHAccessibilityDarkerSystemColorsFunctionReplacement,
                                                (void **)&LHAccessibilityDarkerSystemColorsFunctionOriginalImplementation) || installed;

    installed = LHAccessibilityHookContrastClasses(backend, traitCollectionClass) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_accessibility_common_preferences_uikit_normalized);
    }

    return true;
}
