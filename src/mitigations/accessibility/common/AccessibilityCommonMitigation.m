#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

typedef BOOL (*LHAccessibilityBooleanOriginal)(id self, SEL selector);
typedef UIAccessibilityContrast (*LHAccessibilityContrastOriginal)(UITraitCollection *self, SEL selector);

static LHAccessibilityBooleanOriginal LHAccessibilityBooleanOriginalImplementations[19];
static LHAccessibilityContrastOriginal LHAccessibilityContrastOriginalImplementation;

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

    SEL contrastSelector = sel_registerName("accessibilityContrast");
    if (traitCollectionClass != Nil && contrastSelector != 0) {
        installed = LHHookBackendHookMessage(backend, traitCollectionClass, contrastSelector, (void *)LHAccessibilityContrastReplacement, (void **)&LHAccessibilityContrastOriginalImplementation) || installed;
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_accessibility_common_preferences_uikit_normalized);
    }

    return true;
}
