# Fonts Fingerprint Category

Upstream source: `.research/upstream/loupe/code/Loupe/Providers/FontsProvider.swift`

Loupe category: Fonts
Loupe tier: passive local font inventory
Permission required: none
Primary relevance: custom font installation, configuration-profile leakage,
and cross-surface typography inventory coherence.

This category covers the installed font family inventory that CoreText exposes
to the app. A stock device usually has a common baseline. The fingerprinting
value appears when a user, app, configuration profile, enterprise deployment,
or creative workflow adds fonts that change the family list.

## Official Links

- Apple CoreText [`CTFontManagerCopyAvailableFontFamilyNames()`](https://developer.apple.com/documentation/coretext/ctfontmanagercopyavailablefontfamilynames%28%29)
- Apple CoreText [Core Text Functions](https://developer.apple.com/documentation/coretext/core-text-functions)
- Apple CoreText [`CTFontDescriptor`](https://developer.apple.com/documentation/coretext/ctfontdescriptor)
- Apple UIKit [`UIFont.familyNames`](https://developer.apple.com/documentation/uikit/uifont/familynames)
- Apple UIKit [`UIFont.fontNames(forFamilyName:)`](https://developer.apple.com/documentation/uikit/uifont/fontnames%28forfamilyname%3A%29)
- Apple AppKit [`NSFontManager.availableFontFamilies`](https://developer.apple.com/documentation/appkit/nsfontmanager/availablefontfamilies)
- Apple AppKit [`NSFontManager.availableFontNames(with:)`](https://developer.apple.com/documentation/appkit/nsfontmanager/availablefontnames%28with%3A%29)
- Apple Bundle Resources [`UIAppFonts`](https://developer.apple.com/documentation/bundleresources/information-property-list/uiappfonts)

Loupe uses CoreText directly through `PlatformFont.familyNames`, which calls
`CTFontManagerCopyAvailableFontFamilyNames()`. UIKit and AppKit font-family
enumeration are equivalent surfaces for mitigation planning even though the
provider does not call them directly.

## Loupe Signals and Decisions

| Loupe signal | Provider source | Platforms | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- | --- |
| `familyCount` | Sorted count of `PlatformFont.familyNames`, backed by `CTFontManagerCopyAvailableFontFamilyNames()` | iOS, macOS | None | Passive local font inventory summary | Include as a coarse summary | Low alone, medium when non-default. It reveals whether the family inventory differs from the expected OS/device baseline without naming the custom families. |
| `familiesAll` | Full sorted list of available font family names from the same CoreText call | iOS, macOS | None | Passive local font inventory enumeration | Include | High when custom fonts are present. The full set can reveal design tools, enterprise profiles, language packs, brand fonts, and app-installed typefaces. |

Loupe sorts the family list before emitting it. It does not enumerate individual
font faces, PostScript names, glyph coverage, font tables, rendering metrics,
or app-specific typography output in this provider.

## Permission and Activity Classification

No included Fonts signal requires Contacts, Location, Bluetooth, Local Network,
Motion, Photos, Microphone, Files, or another user-granted runtime permission.
The provider reads CoreText's local font manager inventory.

The category is passive in Loupe's collection path. The app does not install,
load from the network, open font files manually, render test glyphs, or probe
another app's container. It asks the system font manager for available family
names and reports the resulting list.

Mitigation code would be active in the implementation sense because it hooks
CoreText/UIKit/AppKit enumeration paths, but the original fingerprint surface is
passive local inventory.

## Fingerprinting Value

`familiesAll` is the primary signal. Most devices with the same OS and locale
share a predictable system font baseline. Custom family names can be rare:
corporate brand fonts, academic fonts, design-tool bundles, font-manager apps,
language-specific fonts, or configuration-profile fonts can narrow a user or
organization quickly.

`familyCount` is a coarse, non-granular signal, but it still has value. A count
above the expected baseline can show that the device has custom fonts even when
the names are hidden. A count mismatch can also detect incomplete mitigation if
`familiesAll` is filtered but count APIs still expose the real inventory size.

The font inventory is durable compared with pasteboard or battery state. It may
survive reboots and app launches until the user removes fonts, updates the OS,
or a profile changes. That makes it useful for medium-term linking even without
a stable device identifier.

Font inventory also interacts with rendering fingerprints. A web view, native
text engine, canvas test, PDF renderer, or document editor may infer the same
custom fonts through fallback behavior, glyph support, or metrics. Hiding only
the family list is incomplete if rendering still proves the fonts exist.

## Mitigation Strategy Ideas

### `fonts.family_inventory`

Hook the family-list surfaces together:

- `CTFontManagerCopyAvailableFontFamilyNames()`
- `UIFont.familyNames`
- `UIFont.fontNames(forFamilyName:)`
- `NSFontManager.availableFontFamilies`
- `NSFontManager.availableFontNames(with:)`
- any Objective-C wrappers that expose the same CoreText inventory

Compatibility default should pass through for design, publishing, document,
education, accessibility, office, terminal, and creative apps. Those apps may
need the real font list to render documents correctly or let the user choose an
installed font.

Privacy mode can filter custom fonts from enumeration while preserving the
system baseline for the selected OS profile. If a family is removed from
`familiesAll`, count surfaces must reflect the filtered list. If the app asks
for names within a filtered family, return an empty or baseline-consistent
result instead of leaking the family through a second API.

Strict mode can return the baseline font family set for a common OS/device
profile. The baseline should come from observed cohort data, not from a
handwritten small list. Missing system fonts can break layout and make the
profile more unique than the real device.

### `fonts.custom_family_policy`

Custom fonts should be policy-controlled by app class:

- pass through for apps where custom fonts are core functionality
- hide user-installed and profile-installed families for generic apps
- preserve app-bundled fonts that are part of the app's own resources
- optionally allow a small common language-support expansion tied to locale

Do not generate seed-derived custom family names. A unique synthetic font list
is a new identifier. When strict mode needs variety, choose complete baseline
profiles shared by many devices.

### Rendering and WebView Coherence

Future coverage should include font availability as observed through WebKit,
CoreText font matching, fallback rendering, canvas text metrics, PDF rendering,
and document preview paths. If native enumeration says a font is absent but text
layout uses that font with real metrics, the contradiction can be detected.

The mitigation should also distinguish system/user fonts from app-bundled
fonts. An app's own bundled font can legitimately remain available even when
user-installed fonts are hidden.

## Derivation Considerations

Font inventory is mostly cohort-static. It should be generated from an OS,
locale, and device profile, then optionally augmented by a small, explicit
custom-font policy. Do not derive individual family names directly from seed
material.

The derived record should include:

```text
OS and build baseline font family set
locale or language-support additions
user/profile/app font visibility policy
family count derived from the visible family list
font names or faces for visible families if those APIs are covered
rendering fallback behavior for hidden or visible families
```

`familyCount` must be computed from the same visible list returned by
`familiesAll`. The count should never preserve the real custom-font total while
the list is filtered.

Profile rotation should be rare. Fonts do not normally change every launch. If
a custom-font profile event is modeled, it should look like installation,
removal, OS update, or configuration-profile change rather than random churn.

Purpose labels, salts, and mitigation IDs should stay internal. Font family
names returned to apps should be real system or app font names, not readable
Loupehole labels.

## Impact and Tradeoffs

Font mitigation can break visible rendering. If an app uses an installed font
for a document, design, slide deck, terminal, code editor, or accessibility
workflow, hiding that family can change layout, fallback, pagination, export,
or editing behavior.

Filtering custom fonts improves privacy for generic apps but may reveal itself
if lower-level font matching still succeeds or rendering metrics still match
the real font. A partial hook can be worse than pass-through because it creates
a contradiction between inventory and behavior.

Returning an incomplete baseline can also be fingerprintable. A tiny fake font
set, stale OS baseline, or locale-incompatible font list may identify Loupehole
users as a smaller cohort.

The safest default is pass-through. Strict profiles should use complete,
observed baseline inventories and should only hide user/profile fonts when the
target app does not depend on typography workflows.

## Exclusion Note

Loupe's Fonts provider excludes these adjacent surfaces:

- individual font faces and PostScript names
- glyph coverage, supported scripts, font tables, and font metadata
- text rendering metrics, fallback behavior, and canvas/WebKit font probes
- app-bundled font registration details beyond their effect on availability
- font files on disk and configuration-profile contents

`familyCount` is a coarse, non-granular surface, but it is included because it
can reveal custom-font presence and must stay coherent with the filtered family
list. The full family list remains the main privacy surface.

## Relevance

Fonts is a high-value passive inventory category when custom fonts are present.
It is lower value on a stock device, but still important because enumeration,
counting, and rendering must agree with the selected OS and locale profile.

The mitigation priority is medium to high for generic apps and web/container
surfaces. It should be compatibility-first for apps where font availability is
real user functionality.
