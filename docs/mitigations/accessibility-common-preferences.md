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
| Affected APIs | `UIAccessibility` boolean class properties; `UIAccessibility...` C functions for assistive input, visual, media, motion, speech, captions, hearing-device, and button-shape flags; `AXShowBordersEnabled`; `UITraitCollection.accessibilityContrast` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None |

## References

- Apple Developer: `UIAccessibility`.
- Apple Developer: `UITraitCollection.accessibilityContrast`.

## Surface And Relevance

Rare accessibility settings can strongly identify a user or preference bundle. However, apps may also read these settings to provide necessary accessibility behavior, so normalization has real usability risk.

## Mitigation Strategy

The mitigation hooks UIKit class methods for Loupe-observed `UIAccessibility` booleans and the public C function entry points for the same settings. It returns `false` for rare enabled states such as VoiceOver, Switch Control, Guided Access, AssistiveTouch, Classic Invert, Grayscale, Reduce Motion, Prefer Cross-Fade Transitions, Bold Text, Increased Contrast, Reduce Transparency, captions, speech, button shapes, on/off labels, and related flags. It returns `true` for common enabled defaults `isShakeToUndoEnabled` and `isVideoAutoplayEnabled`.

It also hooks `UIAccessibilityDarkerSystemColorsEnabled`, the iOS 26.1 `AXShowBordersEnabled` replacement for Button Shapes, and `-[UITraitCollection accessibilityContrast]` on the trait collection class family, returning normal contrast so the darker-system-colors and trait paths agree. `UIAccessibilityHearingDevicePairedEar` returns `UIAccessibilityHearingDeviceEarNone` to avoid exposing a paired-hearing-device state through this passive flag.

## Derivation And Lifetime

No policy seeds are declared. No state or seed-derived values are used. The tuple is constant by design because seeded rare accessibility bundles would be more identifying and less plausible.

| Item | Value |
| --- | --- |
| Policy seed identifiers | None |
| Generated seed symbols | None |
| Helpers/state owner | None |
| Value shape | Fixed common accessibility tuple |
| Derivation input | None |
| Lifetime | Stable while the module is enabled |
| Temporal dependencies | None |

## Impact And Tradeoffs

This module can degrade apps for users who rely on accessibility features, including hearing-device-aware apps. It does not cover notification names for setting changes, SwiftUI environment values, WebKit CSS media queries, rendered animation behavior, screenshots, AppKit, or `userInterfaceStyle`. Those paths are documented gaps; use pass-through policy for apps where accessibility adaptation matters.

## Validation

Expected observations after catalog selection and generation:

- Loupe's UIKit accessibility booleans report the common tuple.
- UIKit C-function probes report the same common tuple as the `UIAccessibility` class properties.
- The darker-system-colors C/Swift boolean and accessibility-contrast trait both report normal contrast.
- Prefer Cross-Fade Transitions, Button Shapes / Show Borders, and paired hearing-device probes report the documented common values.
- The merged active-flags signal should collapse to no rare enabled flags except common defaults handled by Loupe's own string formatting.

## Rollback And Pass-Through

If no UIKit selector or C-function hook installs, the module registers as a no-op. Disabling this module restores real accessibility values.
