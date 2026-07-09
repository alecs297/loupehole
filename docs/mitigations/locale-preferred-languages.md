# `locale.preferred_languages`

The preferred-languages option reduces ordered language-list entropy by preserving only the user's primary preferred language through the Foundation API Loupe observes.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `locale.preferred_languages` |
| Implemented mitigation | `locale.preferred_languages.foundation.primary_only` |
| Policy seeds | None; this module reduces the original list rather than deriving a synthetic locale profile |
| User-facing name | Preferred languages |
| Status | Experimental |
| Surface | Locale and region |
| Classification | Passive local language preference read; active Foundation hook mitigation |
| Affected APIs | `+[NSLocale preferredLanguages]`, `CFLocaleCopyPreferredLanguages`, `CFPreferencesCopyAppValue`, `-[NSUserDefaults objectForKey:]`, `-[NSUserDefaults arrayForKey:]`, `-[NSUserDefaults stringArrayForKey:]` for `AppleLanguages` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None |

## References

- Apple Developer: `Locale.preferredLanguages`.
- Apple Developer: `NSLocale`.
- Unicode LDML / CLDR locale identifiers.

## Surface And Relevance

An ordered preferred-language list can be high entropy for multilingual users. The first entry is often needed for app localization, while secondary entries can reveal language ability, region, travel, education, or accessibility choices.

## Mitigation Strategy

The mitigation hooks the `NSLocale` class method `preferredLanguages`, `CFLocaleCopyPreferredLanguages`, `CFPreferencesCopyAppValue`, and the `NSUserDefaults` read shapes commonly used for the backing `AppleLanguages` list. When the original list contains more than one valid string, the replacement returns an array containing only the original first language tag. Empty, malformed, single-entry lists, and unrelated defaults keys pass through unchanged.

The module does not alter `Locale.current`, `NSLocale.currentLocale`, calendars, time zones, formatters, WebKit language surfaces, or server-side `Accept-Language` headers.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifiers | None |
| Value shape | `NSArray<NSString *>` containing the original primary language |
| Derivation input | Original preferred-language or `AppleLanguages` list |
| Storage behavior | No mitigation-owned state |
| Lifetime | Tracks the original primary language |
| Dependencies | Should be paired with keyboard-language mitigation for Loupe's language tuple |

This is a reduction, not a generated locale profile. A future strict locale profile should use a cohort table and cover locale identifier, calendar, hour cycle, time zone, formatters, keyboards, and WebKit together.

## Impact And Tradeoffs

Apps may use secondary languages for localization fallback, content choice, search, translation, or support flows. This mitigation can reduce those fallbacks for protected apps. It preserves the primary language to avoid the most visible UI mismatch.

## Validation

Expected observations:

- Loupe's preferred-language list contains the original first language only.
- Direct `AppleLanguages` reads through covered `NSUserDefaults` and CFPreferences getters contain the original first language only.
- A single-language device reports the same list as before.
- Locale identifier, calendar, time-zone, and formatter behavior remain unchanged.

## Rollback And Pass-Through

If the class method and defaults hooks are unavailable or hook installation fails, the module registers as a no-op. If the original list is empty, malformed, or already contains one language, the original result is returned unchanged. Defaults keys other than `AppleLanguages` pass through unchanged.
