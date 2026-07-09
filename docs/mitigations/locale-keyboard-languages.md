# `locale.keyboard_languages`

The keyboard-languages option reduces text-input language enumeration to modes matching the primary preferred language, while preserving emoji and unknown modes.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `locale.keyboard_languages` |
| Implemented mitigation | `locale.keyboard_languages.uikit.primary_only` |
| Policy seeds | None; this module filters original UIKit mode objects |
| User-facing name | Keyboard languages |
| Status | Experimental |
| Surface | Locale and region |
| Classification | Passive local text-input enumeration; active UIKit hook mitigation |
| Affected APIs | `+[UITextInputMode activeInputModes]`, `UITextInputMode.primaryLanguage` as read from returned mode objects |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None |

## References

- Apple Developer: `UITextInputMode.activeInputModes`.
- Apple Developer: `UITextInputMode.primaryLanguage`.
- Unicode LDML / CLDR language tags.

## Surface and Relevance

Enabled keyboard languages can reveal languages the user writes in, even when the UI language is generic. Loupe strips emoji and deduplicates base languages, so the visible signal is the ordered set of non-emoji keyboard language codes.

## Mitigation Strategy

The mitigation hooks the `UITextInputMode` class method `activeInputModes`. It reads the primary preferred language from `NSLocale preferredLanguages`, reduces both language tags to their base language, and keeps:

- modes matching the primary preferred base language;
- emoji modes;
- modes without a readable primary language.

If filtering would remove every non-emoji mode, the original list passes through. The module returns original mode objects; it does not synthesize keyboard objects or alter the currently selected input mode.

## Derivation and Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifiers | None |
| Value shape | Filtered `NSArray` of original `UITextInputMode` objects |
| Derivation input | Original active input modes + current primary preferred language |
| Storage behavior | No mitigation-owned state |
| Lifetime | Tracks real keyboard and primary-language changes |
| Dependencies | Pairs with `locale.preferred_languages.foundation.primary_only` when both are selected |

This module is a compatibility-oriented reduction. A complete strict locale profile would need coherent keyboard, preferred-language, locale, calendar, hour-cycle, time-zone, formatter, and WebKit behavior.

## Impact and Tradeoffs

Keyboard enumeration can be used by messaging, language learning, translation, search, and keyboard-aware product flows. Filtering can hide real multilingual typing support from those apps. Actual typed text, keyboard switching UI, autocorrect, and system settings remain outside coverage.

## Validation

Expected observations:

- Loupe's keyboard language list is reduced to the primary preferred base language when multiple non-emoji languages are installed.
- Emoji does not force pass-through, matching Loupe's own exclusion of emoji from the reported language signal.
- If no safe primary-language match exists, the original list is returned.

## Rollback and Pass-Through

If `UITextInputMode` or `activeInputModes` is unavailable, the module registers as a no-op. If filtering would remove every usable non-emoji mode, the original result is returned unchanged.
