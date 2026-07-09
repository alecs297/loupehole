#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#include <stdlib.h>

typedef BOOL (*LHAccessibilityBooleanOriginal)(id self, SEL selector);
typedef BOOL (*LHAccessibilityBooleanFunctionOriginal)(void);
typedef BOOL (*LHAccessibilityDarkerSystemColorsFunctionOriginal)(void);
typedef UIAccessibilityHearingDeviceEar (*LHAccessibilityHearingDevicePairedEarOriginal)(void);
typedef UIAccessibilityContrast (*LHAccessibilityContrastOriginal)(UITraitCollection *self, SEL selector);

static LHAccessibilityBooleanOriginal LHAccessibilityBooleanOriginalImplementations[19];
static LHAccessibilityBooleanFunctionOriginal LHAccessibilityBooleanFunctionOriginalImplementations[24];
static LHAccessibilityDarkerSystemColorsFunctionOriginal LHAccessibilityDarkerSystemColorsFunctionOriginalImplementation;
static LHAccessibilityHearingDevicePairedEarOriginal LHAccessibilityHearingDevicePairedEarOriginalImplementation;
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

static BOOL LHAccessibilityFunctionReturnFalse(void) {
    return NO;
}

static BOOL LHAccessibilityFunctionReturnTrue(void) {
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

static UIAccessibilityHearingDeviceEar LHAccessibilityHearingDevicePairedEarReplacement(void) {
    return UIAccessibilityHearingDeviceEarNone;
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

static bool LHAccessibilityHookBooleanFunction(LHHookBackend *backend,
                                               const char *symbol,
                                               void *replacement,
                                               LHAccessibilityBooleanFunctionOriginal *original) {
    bool installed = false;
    void *target = dlsym(RTLD_DEFAULT, symbol);
    if (target != 0) {
        installed = LHHookBackendHookFunction(backend, target, replacement, (void **)original) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend, symbol, replacement, (void **)original) || installed;
    return installed;
}

static bool LHAccessibilityHookFunctionWithOriginal(LHHookBackend *backend,
                                                    const char *symbol,
                                                    void *replacement,
                                                    void **original) {
    bool installed = false;
    void *target = dlsym(RTLD_DEFAULT, symbol);
    if (target != 0) {
        installed = LHHookBackendHookFunction(backend, target, replacement, original) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend, symbol, replacement, original) || installed;
    return installed;
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

    size_t functionIndex = 0;
    static const char *falseFunctionSymbols[] = {
        "UIAccessibilityIsVoiceOverRunning",
        "UIAccessibilityIsMonoAudioEnabled",
        "UIAccessibilityIsClosedCaptioningEnabled",
        "UIAccessibilityIsInvertColorsEnabled",
        "UIAccessibilityIsGuidedAccessEnabled",
        "UIAccessibilityIsBoldTextEnabled",
        "UIAccessibilityButtonShapesEnabled",
        "UIAccessibilityIsGrayscaleEnabled",
        "UIAccessibilityIsReduceTransparencyEnabled",
        "UIAccessibilityIsReduceMotionEnabled",
        "UIAccessibilityPrefersCrossFadeTransitions",
        "UIAccessibilityIsSwitchControlRunning",
        "UIAccessibilityIsSpeakSelectionEnabled",
        "UIAccessibilityIsSpeakScreenEnabled",
        "UIAccessibilityIsAssistiveTouchRunning",
        "UIAccessibilityShouldDifferentiateWithoutColor",
        "UIAccessibilityIsOnOffSwitchLabelsEnabled",
        "AXShowBordersEnabled",
    };
    for (size_t i = 0; i < sizeof(falseFunctionSymbols) / sizeof(falseFunctionSymbols[0]); i++) {
        installed = LHAccessibilityHookBooleanFunction(backend,
                                                       falseFunctionSymbols[i],
                                                       (void *)LHAccessibilityFunctionReturnFalse,
                                                       &LHAccessibilityBooleanFunctionOriginalImplementations[functionIndex++]) || installed;
    }

    static const char *trueFunctionSymbols[] = {
        "UIAccessibilityIsShakeToUndoEnabled",
        "UIAccessibilityIsVideoAutoplayEnabled",
    };
    for (size_t i = 0; i < sizeof(trueFunctionSymbols) / sizeof(trueFunctionSymbols[0]); i++) {
        installed = LHAccessibilityHookBooleanFunction(backend,
                                                       trueFunctionSymbols[i],
                                                       (void *)LHAccessibilityFunctionReturnTrue,
                                                       &LHAccessibilityBooleanFunctionOriginalImplementations[functionIndex++]) || installed;
    }

    installed = LHAccessibilityHookFunctionWithOriginal(backend,
                                                        "UIAccessibilityDarkerSystemColorsEnabled",
                                                        (void *)LHAccessibilityDarkerSystemColorsFunctionReplacement,
                                                        (void **)&LHAccessibilityDarkerSystemColorsFunctionOriginalImplementation) || installed;
    installed = LHAccessibilityHookFunctionWithOriginal(backend,
                                                        "UIAccessibilityHearingDevicePairedEar",
                                                        (void *)LHAccessibilityHearingDevicePairedEarReplacement,
                                                        (void **)&LHAccessibilityHearingDevicePairedEarOriginalImplementation) || installed;

    installed = LHAccessibilityHookContrastClasses(backend, traitCollectionClass) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_accessibility_common_preferences_uikit_normalized);
    }

    return true;
}
