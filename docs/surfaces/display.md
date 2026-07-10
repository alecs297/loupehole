# Display

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/DisplayProvider.swift`

Loupe category: Display
Loupe tier: passive live
Permission required: none
Primary relevance: user display settings, accessibility preference leakage, and
coherence dependencies for the broader hardware/display profile.

This page scopes Loupehole's Display fingerprint category to display-derived
values that should be considered directly in this category. Per user rule,
screen size, native bounds, scale, native scale, safe area, and model-constant
display traits are excluded from first-class mitigation planning here even
though Loupe reports them.

## Official Links

- [`UIWindowScene.screen`](https://developer.apple.com/documentation/uikit/uiwindowscene/screen)
- [`UIScreen`](https://developer.apple.com/documentation/uikit/uiscreen)
- [`UIScreen.nativeBounds`](https://developer.apple.com/documentation/uikit/uiscreen/nativebounds)
- [`UIScreen.scale`](https://developer.apple.com/documentation/uikit/uiscreen/scale)
- [`UIScreen.nativeScale`](https://developer.apple.com/documentation/uikit/uiscreen/nativescale)
- [`UIScreen.maximumFramesPerSecond`](https://developer.apple.com/documentation/uikit/uiscreen/maximumframespersecond)
- [`UIScreen.brightness`](https://developer.apple.com/documentation/uikit/uiscreen/brightness)
- [`UITraitCollection.displayGamut`](https://developer.apple.com/documentation/uikit/uitraitcollection/displaygamut)
- [`UITraitCollection.horizontalSizeClass`](https://developer.apple.com/documentation/uikit/uitraitcollection/horizontalsizeclass)
- [`UITraitCollection.verticalSizeClass`](https://developer.apple.com/documentation/uikit/uitraitcollection/verticalsizeclass)
- [`UITraitCollection.preferredContentSizeCategory`](https://developer.apple.com/documentation/uikit/uitraitcollection/preferredcontentsizecategory)
- [`UIContentSizeCategory`](https://developer.apple.com/documentation/uikit/uicontentsizecategory)
- [`UIView.safeAreaInsets`](https://developer.apple.com/documentation/uikit/uiview/safeareainsets)
- [`NSScreen`](https://developer.apple.com/documentation/appkit/nsscreen)
- [`NSScreen.backingScaleFactor`](https://developer.apple.com/documentation/appkit/nsscreen/backingscalefactor)
- [`NSScreen.maximumFramesPerSecond`](https://developer.apple.com/documentation/appkit/nsscreen/maximumframespersecond)
- [`NSScreen.safeAreaInsets`](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets)

## Loupe Signals

| Loupe signal | Source API | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `unavailable` | Placeholder emitted when `PlatformScreen.displayInfo()` cannot find an active scene/window | None | Passive app state placeholder | Exclude | Not a device fingerprint value. It only says Loupe could not read display state in the current attachment state. |
| `nativeBounds` | `UIWindowScene.screen.nativeBounds` through `UIScreen.nativeBounds` | None | Passive static hardware/scene read | Exclude | Exact physical pixel size is a strong model classifier, but belongs in a coherent hardware/display profile rather than this category page. |
| `scale` | `UIScreen.scale` | None | Passive static hardware/scene read | Exclude | Point-to-pixel ratio is mostly a display/model cohort constant and must agree with native bounds, WebKit DPR, and selected hardware profile. |
| `nativeScale` | `UIScreen.nativeScale` | None | Passive static hardware/scene read | Exclude | Actual backing scale is a model/display-mode classifier and is especially useful when joined with bounds and WebKit screen values. |
| `maxFPS` | `UIScreen.maximumFramesPerSecond` | None | Passive static capability read | Exclude | Refresh ceiling reveals display class, such as 60 Hz versus ProMotion-capable devices. Treat as a model-constant display trait. |
| `brightness` | `UIScreen.brightness` | None | Passive live setting read | Include | Current brightness is a user/environment/usage signal that can correlate sessions and reveal habits even though it is not stable hardware identity. |
| `displayGamut` | `UITraitCollection.displayGamut` | None | Passive trait read | Exclude | sRGB/P3 capability is mostly a model/display cohort constant and should be generated with the device profile. |
| `sizeClass` | `UITraitCollection.horizontalSizeClass` and `verticalSizeClass` | None | Passive live scene/layout trait read | Exclude | Size class is driven by device class, orientation, multitasking/windowing, and scene geometry. It is UI-layout state, not a standalone Display mitigation here. |
| `preferredContentSizeCategory` | `UITraitCollection.preferredContentSizeCategory` | None | Passive user-preference trait read | Include | Dynamic Type can reveal accessibility or reading preferences; rare accessibility categories are meaningful entropy and affect app UI behavior. |
| `safeAreaInsets` | `UIWindow.safeAreaInsets` inherited from `UIView.safeAreaInsets` | None | Passive scene/chassis trait read | Exclude | Insets reveal notch, Dynamic Island, home indicator, orientation, and window geometry. Per rule, keep safe-area handling out of this category page. |

Loupe collects these values on the main actor and exposes the category as a
live provider with a one-second update interval. That makes brightness and
scene-derived traits time-varying observations, but the collection is still
passive: the app reads local UIKit/AppKit state and does not trigger a user
permission prompt.

## Permission and Collection Class

| Surface | Runtime permission | Passive or active | Notes |
| --- | --- | --- | --- |
| `UIScreen.brightness` | None | Passive live read | The value can change with user adjustment, system auto-brightness, app writes, lock state, and ambient context. |
| `UITraitCollection.preferredContentSizeCategory` | None | Passive user-preference read | Exposes Dynamic Type size through the active window trait collection. It should be kept coherent with equivalent app-wide content-size APIs. |
| Excluded screen metrics and safe-area traits | None | Passive static or scene read | No runtime prompt, but excluded here by rule and delegated to hardware/display-profile coherence work. |

No included Display signal requires Contacts, Location, Local Network,
Bluetooth, Motion, Photos, or another user-granted TCC permission. The risk is
silent local readability rather than permission bypass.

## Fingerprinting Value

`brightness` is low to medium as a standalone identifier but useful as a live
correlation signal. Exact floating-point brightness can link adjacent launches,
separate foreground sessions, or distinguish users with unusual brightness
habits. It can also indirectly reflect context: night use, outdoor use,
auto-brightness behavior, media playback adjustments, or apps that temporarily
force a brightness level.

`preferredContentSizeCategory` is higher value when it leaves the common default
range. Large, extra-large, and accessibility Dynamic Type categories can reveal
reading preferences or accessibility needs. The value is not merely cosmetic:
apps adapt layout, text metrics, and sometimes product behavior based on it, so
normalizing it has real UX impact.

The excluded model-constant display traits have high fingerprinting value in
the broader system. `nativeBounds`, `scale`, `nativeScale`, `maxFPS`,
`displayGamut`, and `safeAreaInsets` can identify a small device cohort and can
contradict WebKit `screen`/`devicePixelRatio`, GPU/Metal, camera, model, and
safe-area observations. They remain important, but this page does not assign
standalone mitigations to them.

## Mitigation Strategy Ideas

### `display.brightness`

Default behavior should reduce direct correlation rather than invent a rare
fixed value. A scoped smooth transfer curve over the real value preserves broad
UX intent and avoids obvious bucket edges while still breaking the exact raw
brightness mirror.

Strict behavior can return a stable common value such as mid brightness, but
only for apps that do not legitimately adapt to brightness. Reading, camera,
scanner, kiosk, video, and accessibility-oriented apps may expect the real value
or may set brightness themselves. For those apps, pass-through or a continuous
value derived from the post-write real value is safer than a fixed synthetic
value.

The hook should target `UIScreen.brightness` reads. Avoid interfering with
brightness writes unless a separate policy explicitly covers setter behavior.
If the app writes brightness and then reads it back, either pass through for
that flow or return a shaped value that is predictably derived from the
post-write real value.

### `display.dynamic_type`

Compatibility default should pass through. Dynamic Type is an accessibility and
readability preference, and hiding it by default can make apps render text too
small or choose layouts that do not fit the user.

Strict behavior may normalize to a common content-size category, typically the
platform default large category, but only when the user accepts the accessibility
tradeoff. A middle mode can bucket rare accessibility categories to a less
specific accessibility category while preserving the signal that larger text is
needed.

Coverage should include equivalent surfaces where practical:

- `UITraitCollection.preferredContentSizeCategory`
- `UIApplication.preferredContentSizeCategory`
- content-size change notifications if an app watches them for consistency
- any future AccessibilityProvider surface that summarizes large text state

Do not return one Dynamic Type value through traits and a contradictory value
through app-wide content-size APIs.

### Excluded Display Profile Values

Do not create one-off mitigations in this category for screen dimensions, scale,
safe-area, gamut, or refresh ceiling. If those values are mitigated, they should
come from a complete real-device display profile that also aligns with:

- `hw.machine`, marketing model, CPU/RAM, GPU/Metal, and camera capabilities
- WebKit `screen.width`, `screen.height`, `devicePixelRatio`, CSS media queries,
  and WebGL renderer data
- orientation, size-class, windowing, and safe-area observations
- maximum frame rate and any timing/animation cadence mitigation

If the display profile resolver cannot provide a coherent value, pass through
the real display value rather than returning a hand-mixed synthetic trait.

## Derivation Considerations

Brightness should not become a new per-user identifier. Prefer deterministic
low-cardinality shaping of the real value, a common policy constant, or a
session-stable common value drawn from a tiny set. If a seeded transfer function
is used, choose from a small finite family and avoid making it stable across too
many unrelated apps unless the profile explicitly calls for that.

Dynamic Type should usually be a policy choice, not a random derivation. The
default is pass-through because it preserves usability. Strict normalization
should use a common shared value, and any bucketed accessibility value must stay
coherent with accessibility flags such as larger text summaries, bold text,
contrast, and reduce-transparency settings.

Excluded model-display values are cohort static. They should be selected from a
known plausible device profile instead of derived independently from per-user
seed material. The generator should never produce rare hand-mixed combinations
such as a small-screen safe area with ProMotion refresh, an incompatible GPU, or
WebKit screen values that disagree with native display metrics.

Purpose labels for any derived Display values should stay internal and
seed-bound. Returned API values must not expose readable mitigation names,
profile IDs, salts, or other Loupehole implementation details.

## Impact and Tradeoffs

Brightness mitigation has modest compatibility risk when it only rounds reads,
but a fixed value can break apps that adapt contrast, media overlays, scanning,
or reader modes. It can also conflict with apps that intentionally set
brightness for a short task.

Dynamic Type mitigation has high accessibility risk. Normalizing large text to
a common small/default category may make an app harder or impossible to use for
the protected user. Treat strict normalization as an explicit opt-in, and keep
the compatibility default friendly to real accessibility needs.

Leaving model-constant display traits out of this page reduces implementation
scope but does not make those traits harmless. It prevents fragmented spoofing:
partial changes to screen size, scale, safe area, gamut, or FPS are easy to
detect when other hardware and WebKit surfaces still report the real device.

The safest Display behavior is coherent reduction. Bucket live user settings,
preserve accessibility by default, and move hardware-like display values only as
part of a complete device profile.

## Exclusion Note

Per user rule, this page excludes the following from first-class Display
mitigation ownership:

- screen size and bounds, including `UIScreen.bounds` and WebKit screen-size
  equivalents
- `nativeBounds`
- `scale`
- `nativeScale`
- `safeAreaInsets`
- model-constant display traits, including `maxFPS`, `displayGamut`, static
  screen class, refresh capability, notch/Dynamic Island/home-indicator shape,
  and other chassis-derived display constants
- size-class values when they are being used as screen-size, orientation,
  multitasking, or scene-geometry classifiers

These values remain relevant to fingerprinting. They should be handled by a
separate coherent hardware/display profile plan where display metrics, WebKit
screen values, model identifiers, GPU/Metal, camera, and safe-area expectations
are generated and tested together.

## Relevance

Display remains a P0 coherence category in the broader Loupehole roadmap because
hardware display metrics and WebKit screen values are strong model classifiers.
Within this scoped page, the actionable included surfaces are narrower:
brightness is a P1/P2 live correlation signal, while Dynamic Type is P1 because
rare user preference states are identifying and user-impacting.

This page should feed future mitigation docs for brightness precision reduction
and Dynamic Type preference handling. It should not be used to justify
standalone screen-size, scale, safe-area, or refresh-rate spoofing outside a
complete device-profile generator.
