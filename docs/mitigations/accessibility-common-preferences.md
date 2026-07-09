# `accessibility.common_preferences`

The accessibility common-preferences option normalizes many high-entropy UIKit accessibility booleans to a low-entropy common tuple. It is a strict privacy tradeoff, not a compatibility-first accessibility mode.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `accessibility.common_preferences` |
| Implemented mitigation | `accessibility.common_preferences.uikit.normalized` |
| Policy seeds | None; this mitigation returns documented policy constants |
| User-facing name | Accessibility common preferences |
| Status | Experimental |
| Surface | Accessibility |
| Classification | Passive local-preference reads; active UIKit hook mitigation |
| Affected APIs | `UIAccessibility` boolean class properties and the `UIAccessibilityDarkerSystemColorsEnabled` C function for assistive input, visual, media, and speech flags; `UITraitCollection.accessibilityContrast` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None |

## Surface And Relevance

Rare accessibility settings can strongly identify a user or preference bundle. However, apps may also read these settings to provide necessary accessibility behavior, so normalization has real usability risk.

## Mitigation Strategy

The mitigation hooks UIKit class methods for Loupe-observed `UIAccessibility` booleans. It returns `false` for rare enabled states such as VoiceOver, Switch Control, Guided Access, AssistiveTouch, Classic Invert, Grayscale, Reduce Motion, Bold Text, Increased Contrast, Reduce Transparency, captions, speech, and related flags. It returns `true` for common enabled defaults `isShakeToUndoEnabled` and `isVideoAutoplayEnabled`.

It also hooks `UIAccessibilityDarkerSystemColorsEnabled` and `-[UITraitCollection accessibilityContrast]` on the trait collection class family, returning normal contrast so the darker-system-colors and trait paths agree.

## Derivation And Lifetime

No state or seed-derived values are used. The tuple is constant by design because seeded rare accessibility bundles would be more identifying and less plausible.

## Impact And Tradeoffs

This module can degrade apps for users who rely on accessibility features. It does not cover notification names for setting changes, WebKit CSS media queries, rendered animation behavior, screenshots, AppKit, or `userInterfaceStyle`. Those paths are documented gaps; use pass-through policy for apps where accessibility adaptation matters.

## Validation

Expected observations after catalog selection and generation:

- Loupe's UIKit accessibility booleans report the common tuple.
- The darker-system-colors C/Swift boolean and accessibility-contrast trait both report normal contrast.
- The merged active-flags signal should collapse to no rare enabled flags except common defaults handled by Loupe's own string formatting.

## Rollback And Pass-Through

If no UIKit selector hook installs, the module registers as a no-op. Disabling this module restores real accessibility values.
