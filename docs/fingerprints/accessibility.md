# Accessibility Fingerprint Category

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/AccessibilityProvider.swift`

Loupe category: Accessibility
Loupe tier: passive local preference and trait reads
Permission required: none
Primary relevance: rare accessibility states, visual-preference coherence, and
cross-session user preference correlation.

This category covers accessibility settings and appearance traits that apps can
read without a user permission prompt. Most values are booleans. A common
`false` value usually contributes little entropy, but an enabled state can be
rare and stable enough to identify or segment users, especially when several
settings are enabled together.

## Official Links

- [`UIAccessibility.isVoiceOverRunning`](https://developer.apple.com/documentation/uikit/uiaccessibility/isvoiceoverrunning)
- [`UIAccessibility.isSwitchControlRunning`](https://developer.apple.com/documentation/uikit/uiaccessibility/isswitchcontrolrunning)
- [`UIAccessibility.isGuidedAccessEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isguidedaccessenabled)
- [`UIAccessibility.isGrayscaleEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isgrayscaleenabled)
- [`UIAccessibility.isInvertColorsEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isinvertcolorsenabled)
- [`UIAccessibility.isReduceMotionEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isreducemotionenabled)
- [`UIAccessibility.isAssistiveTouchRunning`](https://developer.apple.com/documentation/uikit/uiaccessibility/isassistivetouchrunning)
- [`UIAccessibility.isShakeToUndoEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isshaketoundoenabled)
- [`UIAccessibility.isBoldTextEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isboldtextenabled)
- [`UIAccessibility.isDarkerSystemColorsEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isdarkersystemcolorsenabled)
- [`UIAccessibility.isReduceTransparencyEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isreducetransparencyenabled)
- [`UIAccessibility.isMonoAudioEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/ismonoaudioenabled)
- [`UIAccessibility.isSpeakScreenEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isspeakscreenenabled)
- [`UIAccessibility.isSpeakSelectionEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isspeakselectionenabled)
- [`UIAccessibility.isClosedCaptioningEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isclosedcaptioningenabled)
- [`UIAccessibility.isVideoAutoplayEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isvideoautoplayenabled)
- [`UIAccessibility.shouldDifferentiateWithoutColor`](https://developer.apple.com/documentation/uikit/uiaccessibility/shoulddifferentiatewithoutcolor)
- [`UIAccessibility.buttonShapesEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/buttonshapesenabled)
- [`UIAccessibility.isOnOffSwitchLabelsEnabled`](https://developer.apple.com/documentation/uikit/uiaccessibility/isonoffswitchlabelsenabled)
- [`UITraitCollection.userInterfaceStyle`](https://developer.apple.com/documentation/uikit/uitraitcollection/userinterfacestyle)
- [`UITraitCollection.accessibilityContrast`](https://developer.apple.com/documentation/uikit/uitraitcollection/accessibilitycontrast)
- [`NSWorkspace.isVoiceOverEnabled`](https://developer.apple.com/documentation/appkit/nsworkspace/isvoiceoverenabled)
- [`NSWorkspace.isSwitchControlEnabled`](https://developer.apple.com/documentation/appkit/nsworkspace/isswitchcontrolenabled)
- [`NSWorkspace.accessibilityDisplayShouldReduceMotion`](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldreducemotion)
- [`NSWorkspace.accessibilityDisplayShouldIncreaseContrast`](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldincreasecontrast)
- [`NSWorkspace.accessibilityDisplayShouldReduceTransparency`](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldreducetransparency)
- [`NSWorkspace.accessibilityDisplayShouldDifferentiateWithoutColor`](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshoulddifferentiatewithoutcolor)
- [`NSWorkspace.accessibilityDisplayShouldInvertColors`](https://developer.apple.com/documentation/appkit/nsworkspace/accessibilitydisplayshouldinvertcolors)

Loupe's platform shim maps iOS values through `UIAccessibility` and
`UITraitCollection`. The macOS build uses `NSWorkspace` for the available
equivalents and returns fixed fallback values for iOS-only settings.

## Loupe Signals

| Loupe signal | Provider source | Permission | Classification | Fingerprinting value |
| --- | --- | --- | --- | --- |
| `voiceOverRunning` | `PlatformAccessibility.isVoiceOverRunning` -> `UIAccessibility.isVoiceOverRunning` on iOS, `NSWorkspace.isVoiceOverEnabled` on macOS | None | Passive local accessibility-state read | High when `true`. A screen-reader session is uncommon and can be stable across launches. |
| `switchControlRunning` | `PlatformAccessibility.isSwitchControlRunning` -> `UIAccessibility.isSwitchControlRunning` on iOS, `NSWorkspace.isSwitchControlEnabled` on macOS | None | Passive local accessibility-state read | High when `true`. Switch Control is rare and can strongly narrow the user cohort. |
| `guidedAccessEnabled` | `PlatformAccessibility.isGuidedAccessEnabled` -> `UIAccessibility.isGuidedAccessEnabled` on iOS | None | Passive local accessibility-state read | Medium to high when `true`. It can indicate kiosk, child, classroom, care, or managed-device use. |
| `grayscaleEnabled` | `PlatformAccessibility.isGrayscaleEnabled` -> `UIAccessibility.isGrayscaleEnabled` on iOS | None | Passive local display-accessibility read | Medium when `true`. It is a rare visual preference and may correlate with color filter behavior. |
| `invertColorsEnabled` | `PlatformAccessibility.isInvertColorsEnabled` -> `UIAccessibility.isInvertColorsEnabled` on iOS, `NSWorkspace.accessibilityDisplayShouldInvertColors` on macOS | None | Passive local display-accessibility read | Medium to high when `true`. Classic Invert is visually significant and uncommon. |
| `reduceMotionEnabled` | `PlatformAccessibility.isReduceMotionEnabled` -> `UIAccessibility.isReduceMotionEnabled` on iOS, `NSWorkspace.accessibilityDisplayShouldReduceMotion` on macOS | None | Passive local display-accessibility read | Low to medium. More common than assistive input settings, but useful when joined with animation and timing behavior. |
| `activeFlags` | Merged enabled labels from additional `PlatformAccessibility` booleans | None | Passive local accessibility-preference read | Medium to high depending on active count and rarity. The comma-separated set can reveal a distinctive preference bundle. |
| `userInterfaceStyle` | `PlatformScreen.displayInfo().userInterfaceStyle` from `UITraitCollection.userInterfaceStyle` on iOS, `NSApp.effectiveAppearance` on macOS | None | Passive local appearance-trait read | Low alone. Light or dark style is common, but it is a coherence anchor for WebView, CSS media queries, screenshots, and app theme behavior. |
| `accessibilityContrast` | `PlatformScreen.displayInfo().accessibilityContrast` from `UITraitCollection.accessibilityContrast` on iOS, `NSWorkspace.accessibilityDisplayShouldIncreaseContrast` on macOS | None | Passive local appearance-trait read | Medium when `high`. Increase Contrast is less common than light/dark style and overlaps with darker system colors. |

The `activeFlags` Loupe signal merges these additional labels when enabled:

- `AssistiveTouch`
- `ShakeToUndo`
- `BoldText`
- `IncreaseContrast`
- `ReduceTransparency`
- `MonoAudio`
- `SpeakScreen`
- `SpeakSelection`
- `ClosedCaptioning`
- `VideoAutoplay`
- `DifferentiateWithoutColor`
- `ButtonShapes`
- `OnOffLabels`

If no merged flag is active, Loupe returns `none enabled`. That common empty
state is low value, but the exact enabled subset can become highly identifying.

## Permission and Activity Classification

No included Accessibility signal needs Contacts, Location, Bluetooth, Local
Network, Motion, Photos, Microphone, Camera, or another user-granted runtime
permission. These are app-readable local settings and environment traits.

Loupe's one-shot `collect()` path is passive. It reads current properties and
does not subscribe to notifications, launch external services, scan other apps,
or perform network probes. Notification counterparts for many accessibility
settings should still be treated as the same surface during mitigation planning
because apps can observe setting changes over time.

The only "active" concern is behavioral: an app may adapt its UI after reading a
setting, and the user can often see whether animations, contrast, typography,
video autoplay, captions, or color treatment match their real system
preference. That makes incorrect spoofing user-visible even though collection
itself is passive.

## Fingerprinting Value

Accessibility settings are strong because many are rare, sticky, and personal.
One enabled flag can add meaningful entropy. Multiple enabled flags can form a
distinct bundle that persists across app launches, websites, and native apps.

Assistive input states such as VoiceOver, Switch Control, Guided Access, and
AssistiveTouch are the highest-value booleans. They are uncommon and can also
affect observable behavior such as focus order, event timing, reduced gestures,
or app UI accommodations. Spoofing them without the matching behavior can be
easy to detect and can harm usability.

Display and motion preferences have lower individual entropy, but they are
excellent coherence checks. Reduce Motion, Reduce Transparency, Classic Invert,
Grayscale, Bold Text, Increase Contrast, Differentiate Without Color, Button
Shapes, On/Off Labels, light/dark style, and high contrast all have visible UI
effects. Native values must agree with WebKit CSS media queries, screenshots,
rendered colors, animation timing, and theme selection.

Audio, speech, captions, and autoplay flags are lower priority as standalone
fingerprints, but enabled states can still narrow the cohort. They can also
interact with media behavior, captions, autoplay decisions, and spoken-content
features, so they should not be randomized independently.

## Mitigation Strategy Ideas

### Assistive Input State

Mitigation ID ideas:

- `accessibility.voiceover`
- `accessibility.switch_control`
- `accessibility.guided_access`
- `accessibility.assistive_touch`

Compatibility default should pass through. These settings often describe real
access needs, and apps use them to adjust navigation, controls, gestures, and
focus behavior. Returning `false` while the real feature is in use can make the
app less accessible.

Strict mode can normalize rare enabled states to `false` only when the user has
explicitly chosen fingerprint reduction over per-app accessibility adaptation.
The mitigation should cover current property reads and corresponding status
change notifications. If notification behavior is not covered, pass through.

Do not seed-generate `true` values for these flags. A synthetic enabled
assistive-input state is rare, user-visible, and likely to make the protected
profile more unique.

### Display, Motion, and Contrast

Mitigation ID ideas:

- `accessibility.reduce_motion`
- `accessibility.invert_colors`
- `accessibility.grayscale`
- `accessibility.bold_text`
- `accessibility.increase_contrast`
- `accessibility.reduce_transparency`
- `accessibility.differentiate_without_color`
- `accessibility.button_shapes`
- `accessibility.on_off_labels`
- `appearance.user_interface_style`
- `appearance.accessibility_contrast`

Treat these as one coherent visual-preference profile. A profile can pass
through, normalize to common defaults, or choose a small common cohort, but it
should not randomize each boolean independently.

For compatibility-first behavior, pass through all visual accessibility values.
For strict behavior, the safest common tuple is usually normal contrast, no
classic invert, no grayscale, no reduce transparency, no button shapes, no on/off
labels, and a stable light/dark style chosen as part of the broader appearance
profile. Reduce Motion may be normalized only if animation behavior, WebKit
media queries, and app-observed transition behavior are also coherent.

Increase Contrast has two Loupe paths: the merged `IncreaseContrast` label via
`UIAccessibility.isDarkerSystemColorsEnabled`, and the separate
`accessibilityContrast` trait via `UITraitCollection.accessibilityContrast`.
These must agree. If one says high contrast and the other says normal, the
synthetic profile is easy to detect.

### Speech, Captions, Audio, and Autoplay

Mitigation ID ideas:

- `accessibility.mono_audio`
- `accessibility.speak_screen`
- `accessibility.speak_selection`
- `accessibility.closed_captioning`
- `accessibility.video_autoplay`
- `accessibility.shake_to_undo`

Compatibility default should pass through. These settings can affect media,
spoken content, captions, undo affordances, and playback expectations.

Strict mode can normalize rare enabled states to common values, but only as
policy constants. Do not derive a rare media-accessibility bundle per app or per
user. If media behavior remains real, prefer pass-through rather than returning
contradictory settings.

### Merged `activeFlags`

Loupe exposes the additional settings as one comma-separated signal, but target
apps can read each underlying flag directly. A mitigation should hook the
underlying APIs, not only try to rewrite a merged string. The merged value
should then naturally reflect the normalized underlying booleans.

If a selected policy does not cover every merged flag, pass through the
uncovered values and document that partial coverage. Incoherent omission is
more detectable than explicit pass-through.

## Derivation Considerations

Most accessibility values should be policy constants or pass-through values,
not high-cardinality seed derivations. A seeded rare `true` can create a new
identifier, while a seeded random bundle of enabled settings is both
fingerprintable and likely unrealistic.

Good derivation should operate at profile-family level:

```text
assistive input flags stay pass-through unless explicitly normalized
visual accessibility flags are selected as one coherent tuple
appearance style agrees across UIKit, AppKit, WebKit, and screenshots
increase contrast APIs agree with accessibility contrast traits
notification values agree with property values
```

Light/dark style should be part of the broader appearance profile. If the app
sees dark mode natively, WebKit should expose matching color-scheme behavior,
and rendered UI should not obviously use a light-only profile. A stable
per-scope light/dark choice can be acceptable, but rotating it too often makes
the user's theme appear inconsistent.

Contrast must be handled across both boolean and trait paths. On iOS, Loupe
reads `UIAccessibility.isDarkerSystemColorsEnabled` through the merged flags and
`UITraitCollection.accessibilityContrast` as a separate signal. On macOS, Loupe
uses `NSWorkspace.accessibilityDisplayShouldIncreaseContrast` for both the
equivalent merged flag and the contrast trait. The generated profile should
return one consistent high/normal answer.

Purpose labels for generated values should remain internal and seed-bound.
Returned API values must not expose readable project names, mitigation names,
profile IDs, or derivation salts.

## Impact and Tradeoffs

Accessibility spoofing has higher user-impact risk than many passive identity
surfaces. Apps are supposed to use these settings to make interfaces usable.
Hiding VoiceOver, Switch Control, Bold Text, Reduce Motion, captions, or
contrast preferences can degrade the app for the user who needs them.

Passing through is the most compatible default and preserves accessibility.
Normalizing rare enabled states can reduce entropy, but it trades away app-level
adaptation and may still be contradicted by observable OS behavior, WebKit
media queries, input timing, focus behavior, screenshots, or rendered UI.

Partial spoofing is especially risky. Returning dark mode while CSS media
queries report light mode, reporting normal contrast while darker system colors
are enabled, or hiding Reduce Motion while transitions are visibly reduced can
be a stronger fingerprint than the original values.

The safest strict mode is coherent reduction to common values, applied across
property reads, trait reads, notifications, and equivalent APIs. The safest
default remains pass-through for real accessibility needs, with strict
normalization exposed as an explicit user-selected tradeoff.

## Relevance

Accessibility is relevant for v1 planning as a passive-native fingerprint
category with high rare-state value and high coherence risk. It does not need a
runtime permission prompt, so trackers can read it before any visible consent
event.

The highest-priority surfaces are VoiceOver, Switch Control, Guided Access,
AssistiveTouch, Increase Contrast, accessibility contrast, Classic Invert,
Grayscale, and light/dark style. Reduce Motion, Reduce Transparency, Bold Text,
Button Shapes, On/Off Labels, captions, speech, audio, and autoplay are lower as
standalone values, but important as part of the visual and media coherence
profile.

Loupehole should default to pass-through until it can provide coherent
appearance and accessibility profiles. Strict profiles can later normalize
selected rare states, but should do so as complete low-entropy tuples rather
than independent per-flag randomization.
