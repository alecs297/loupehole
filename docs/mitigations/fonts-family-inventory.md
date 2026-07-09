# `fonts.family_inventory`

The font-family inventory option filters high-entropy custom family names from CoreText and UIKit enumeration while preserving common system-family prefixes.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `fonts.family_inventory` |
| Implemented mitigation | `fonts.family_inventory.coretext.filtered` |
| Policy seeds | None; this module filters original system font lists |
| User-facing name | Font family inventory |
| Status | Experimental |
| Surface | Fonts |
| Classification | Passive local font inventory; active CoreText/UIKit hook mitigation |
| Affected APIs | `CTFontManagerCopyAvailableFontFamilyNames()`, `+[UIFont familyNames]`, `+[UIFont fontNamesForFamilyName:]` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None |

## References

- Apple Developer: `CTFontManagerCopyAvailableFontFamilyNames()`.
- Apple Developer: `UIFont.familyNames`.
- Apple Developer: `UIFont.fontNames(forFamilyName:)`.
- Apple Bundle Resources: `UIAppFonts`.

## Surface And Relevance

Custom font family names can reveal design tools, enterprise profiles, language packs, brand fonts, or app-installed typefaces. Loupe reads CoreText's sorted family list and count, so the list and count must be reduced together.

## Mitigation Strategy

The mitigation hooks CoreText family enumeration through direct function patching and imported-symbol rebinding, plus UIKit class methods for family names and names within a family. It filters the original family list to broad common system-family prefixes such as Apple, SF, New York, Helvetica, Arial, Avenir, Courier, Times, PingFang, Hiragino, Kohinoor, and other stock iOS families.

For `fontNamesForFamilyName:`, hidden families return an empty array. Visible families call the original implementation so face names remain platform-correct. If filtering would produce an empty list, the original list passes through rather than exposing a tiny synthetic inventory.

The module does not hook font descriptors, font file loading, glyph coverage, rendering metrics, WebKit font probing, PDF/text layout, or app-bundled font registration beyond the family enumeration result.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifiers | None |
| Value shape | Filtered arrays of real family and face names |
| Derivation input | Original CoreText/UIKit font inventory |
| Storage behavior | No mitigation-owned state |
| Lifetime | Tracks real system inventory while hiding disallowed custom families |
| Dependencies | Rendering and WebKit font availability remain future coherence work |

Font lists should not be seed-derived. A future strict baseline should come from observed OS/locale cohort data rather than unique generated family names.

## Impact And Tradeoffs

Filtering custom fonts can break document, publishing, design, education, terminal, accessibility, and creative workflows. It can also be detected if lower-level font matching or text rendering still proves that a hidden font is available. The allowlist is intentionally conservative but not a complete OS baseline database.

## Validation

Expected observations:

- Loupe's CoreText family list and count omit disallowed custom-family names.
- `UIFont.familyNames` follows the filtered family list.
- `UIFont.fontNamesForFamilyName:` returns an empty array for hidden families and original face names for visible families.
- Rendering, descriptors, WebKit, and font files remain outside coverage.

## Rollback And Pass-Through

If neither CoreText nor UIKit hooks can install, the module registers as a no-op. If filtering would remove every family, the original list is returned unchanged. Disabling the mitigation restores real font enumeration.
