# Locale & Region

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/LocaleProvider.swift`

Loupe category: Locale & Region
Loupe tier: passive local state
Permission required: none
Primary relevance: language-combination entropy, keyboard-language leakage,
time-zone and travel inference, and calendar/time-format coherence.

This category covers language, region, calendar, week, hour-cycle, time-zone,
and enabled-keyboard signals that normal apps can read without a user permission
prompt. Most values are not unique alone. The fingerprinting value comes from
the tuple: a user's preferred language order, enabled keyboard languages, region
format, time zone, calendar system, 12-hour or 24-hour preference, and first day
of week.

## Official and Equivalent Links

- [`Locale`](https://developer.apple.com/documentation/foundation/locale)
- [`Locale.current`](https://developer.apple.com/documentation/foundation/locale/current)
- [`Locale.identifier`](https://developer.apple.com/documentation/foundation/locale/identifier)
- [`Locale.preferredLanguages`](https://developer.apple.com/documentation/foundation/locale/preferredlanguages)
- [`Locale.firstDayOfWeek`](https://developer.apple.com/documentation/foundation/locale/firstdayofweek)
- [`Locale.hourCycle`](https://developer.apple.com/documentation/foundation/locale/hourcycle-swift.property)
- [`Locale.HourCycle`](https://developer.apple.com/documentation/foundation/locale/hourcycle-swift.enum)
- [`TimeZone.current`](https://developer.apple.com/documentation/foundation/timezone/current)
- [`TimeZone.identifier`](https://developer.apple.com/documentation/foundation/timezone/identifier)
- [`Calendar.current`](https://developer.apple.com/documentation/foundation/calendar/current)
- [`Calendar.identifier`](https://developer.apple.com/documentation/foundation/calendar/identifier-swift.property)
- [`Calendar.Identifier`](https://developer.apple.com/documentation/foundation/calendar/identifier-swift.enum)
- [`UITextInputMode.activeInputModes`](https://developer.apple.com/documentation/uikit/uitextinputmode/activeinputmodes)
- [`UITextInputMode.primaryLanguage`](https://developer.apple.com/documentation/uikit/uitextinputmode/primarylanguage)
- [`NSTextInputContext.keyboardInputSources`](https://developer.apple.com/documentation/appkit/nstextinputcontext/keyboardinputsources)
- [Apple archive: Reviewing Language and Region Settings](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/SpecifyingPreferences/SpecifyingPreferences.html)
- [Unicode LDML / CLDR locale identifiers](https://www.unicode.org/reports/tr35/)
- [Unicode LDML Part 4: Dates, week data, and calendar conventions](https://unicode.org/reports/tr35/tr35-dates.html)
- [IANA Time Zone Database](https://www.iana.org/time-zones)

Apple documents the app-readable locale, calendar, time-zone, and text-input
surfaces. Unicode CLDR explains the locale identifier conventions underneath
calendar, first-day-of-week, and hour-cycle extensions. IANA is the reference
database behind identifiers such as `Europe/Brussels` and `America/New_York`.

## Loupe Signals

| Loupe signal | Provider source | Permission | Classification | Fingerprinting value |
| --- | --- | --- | --- | --- |
| `identifier` | `Locale.current.identifier` | None | Passive locale snapshot | High as a compound value. It can combine language, region, calendar, and locale extensions, such as `en_US@calendar=gregorian`. |
| `firstDayOfWeek` | `Locale.current.firstDayOfWeek.rawValue` | None | Passive locale convention read | Medium. It is low-cardinality, but overrides or uncommon regional defaults add entropy and must agree with calendar UI behavior. |
| `hourCycle` | `Locale.current.hourCycle.rawValue` | None | Passive locale convention read | Medium. The 12-hour or 24-hour preference is common in some regions and unusual in others, so mismatches can identify a user's preference. |
| `preferredLanguages` | `Locale.preferredLanguages` joined in order | None | Passive ordered preference read | High. Ordered language combinations are especially identifying for multilingual users, and order can reveal the user's primary UI language. |
| `tz.identifier` | `TimeZone.current.identifier` | None | Passive time-zone read | High. The IANA identifier often narrows location more than UTC offset and can expose travel when it conflicts with region settings. |
| `calendar` | `Calendar.current.identifier` | None | Passive calendar preference read | Medium to high. Gregorian is common, while Buddhist, Islamic, Japanese, Hebrew, or other calendars can be strong cohort reducers. |
| `keyboards` | `PlatformTextInput.keyboardLanguageCodes()` | None | Passive local text-input enumeration | High when multiple languages are enabled. Loupe reports ordered base language codes and excludes emoji, making the language set and order the signal. |

Loupe emits `preferredLanguages` and `keyboards` as tag-style entries. The
keyboard helper is platform-specific:

- On iOS, it reads `UITextInputMode.activeInputModes`, takes each mode's
  `primaryLanguage`, strips to the base language before `-`, removes `emoji`,
  and deduplicates while preserving order.
- On macOS, it queries enabled, selectable keyboard input sources through Text
  Input Source Services, reads each source's language list, strips to the base
  language before `-` or `_`, and deduplicates while preserving order.

## Permission and Activity Classification

No Loupe Locale & Region signal needs Contacts, Location, Bluetooth, Local
Network, Motion, Photos, Calendar, Reminders, or another user-granted runtime
permission. These are app-readable settings and local text-input state.

The category is passive in Loupe's one-shot collection path. The app calls local
Foundation, UIKit, and platform text-input APIs; it does not prompt the user,
scan a network, ask another app for data, or perform an external probe.

Keyboard-language collection is best described as passive local enumeration.
It is more sensitive than a single locale property because it reads configured
text-input modes, but it still does not require a permission prompt and Loupe
does not activate, install, or switch keyboards.

## Fingerprinting Value

The highest-value signal is the combination of language surfaces. A single
preferred language like `en-US` is common. An ordered list such as `fr-CA`,
`en-CA`, `ja-JP`, plus enabled keyboards `fr`, `en`, and `ja`, is much more
specific. Keyboard languages can reveal languages a user writes in even when
the UI language or region is generic.

Language and region can also disagree in meaningful ways. A device may use an
English UI, a Belgian or Canadian region, Arabic and Japanese keyboards, a
Gregorian calendar, and a 24-hour clock. That tuple is not inherently invalid,
but it is much smaller than any one component's population.

`tz.identifier` is often stronger than a raw UTC offset. Many zones share the
same current offset, but identifiers preserve geography and daylight-saving
rules. Loupe's narrative code also treats region/time-zone mismatch as a travel
hint: a home region that differs from the current time-zone country can suggest
travel, relocation, VPN mismatch, or a synthetic profile.

Calendar, hour cycle, and first day of week are lower-cardinality fields, but
they are strong coherence checks. A non-Gregorian calendar can be rare in many
app populations. A 24-hour preference in a mostly 12-hour region, or a Monday
first day of week with a US-style locale, may reveal a user's personal settings
instead of a regional default.

`identifier` is the umbrella value. It can encode language, region, calendar,
and other locale extensions in one string, so it must agree with the separate
preferred-language, calendar, week, and hour-cycle reads.

## Mitigation Strategy Ideas

### `locale.profile`

Treat locale and region as one coherent profile, not as independent flags.
Coverage should include the Swift, Objective-C, CoreFoundation, formatter, and
WebKit-adjacent surfaces that expose the same tuple:

- `Locale.current`, `Locale.autoupdatingCurrent`, `NSLocale.current`, and
  `CFLocaleCopyCurrent`.
- `Locale.identifier`, `Locale.firstDayOfWeek`, and `Locale.hourCycle`.
- `Locale.preferredLanguages` and `NSLocale.preferredLanguages`.
- `Calendar.current`, `NSCalendar.current`, and calendar identifiers used by
  date formatters.
- `TimeZone.current`, `NSTimeZone.local`, and CoreFoundation time-zone reads.
- date, time, number, measurement, and currency formatters that derive behavior
  from the same locale profile.

Default behavior should pass through unless a target profile explicitly enables
locale normalization. Strict behavior should select a common, complete profile
from a cohort table and return all related values from that profile.

### `locale.preferred-languages`

Normalize the ordered preferred-language list only with care. Many apps use it
to choose UI language, content language, support flows, search behavior, and
server-side localization. A compatibility profile should usually preserve the
real primary app language and optionally reduce secondary languages.

Strict mode can return a short common list, such as one or two languages that
match the selected region profile. Avoid generating rare three-language stacks
from the seed. A synthetic multilingual list can be more identifying than the
real one if it is not population-shaped.

### `locale.keyboard-languages`

Hook `UITextInputMode.activeInputModes` and `primaryLanguage` on iOS, and the
equivalent macOS input-source APIs when relevant. Return keyboard languages
that are plausible for the selected preferred-language list. Emoji should stay
out of the returned Loupe-style language list because Loupe already removes it.

Compatibility default should pass through for text editors, keyboard-heavy
apps, language-learning apps, messaging apps, and any app where input behavior
matters. Strict mode can reduce the reported language set, but it should avoid
breaking the currently selected input mode or making autocorrect and text input
visibly inconsistent.

### `locale.time-zone`

Hook time-zone reads as a group, not only `TimeZone.current.identifier`.
Potential coverage includes Foundation, CoreFoundation, date formatters, WebKit
Intl time-zone exposure, and any bridge that returns the default time zone.

Strict mode should choose an IANA time zone that matches the selected region,
or an explicit travel profile that explains a stable mismatch. The identifier,
current offset, daylight-saving behavior, formatted times, calendar date
boundaries, and server-observed timestamps must all remain plausible.

### `locale.calendar-week-hour`

Calendar system, first day of week, and hour cycle should be generated together
with the locale identifier. A common strict profile can use Gregorian calendar,
regional default first day, and the region's common hour cycle. Non-Gregorian
calendars or unusual hour-cycle overrides should be opt-in because they carry
more entropy and are very visible to users.

Do not spoof only `hourCycle` while date formatters still emit the real time
style, or only `Calendar.current.identifier` while `Locale.identifier` keeps a
different calendar extension. Partial coverage creates obvious contradictions.

## Derivation Considerations

Derive a locale profile record from the active seed, scope, app policy, and
profile epoch. The record should contain all related fields:

```text
primary language and ordered preferred languages
region and locale identifier
keyboard language list
IANA time-zone identifier
calendar identifier
first day of week
hour cycle
formatter conventions that follow from the same profile
```

Use cohort tables or population-shaped profile templates instead of free-form
randomization. Valid BCP 47 and Unicode locale identifiers are necessary but
not sufficient; the tuple must also be plausible. For example, `en-US` with
`Europe/Brussels`, a Japanese calendar, Arabic and Thai keyboards, Monday first
day, and a 24-hour clock might be syntactically valid, but it is an unusually
specific synthetic identity unless the profile intentionally models that user.

Keyboard languages should be a plausible subset or extension of preferred
languages. It is normal for keyboard languages to include languages that are
not primary UI languages, but high-cardinality ordering should not be derived
by simply sorting hash output. Preserve stable order within a profile epoch.

Time zone is temporal state. It should not rotate per read or per launch. If a
profile supports travel, model travel as a stable profile event with plausible
duration, offset, and daylight-saving behavior. Otherwise, keep the time zone
coherent with the selected region.

Calendar, hour cycle, and first day of week are low-cardinality, user-visible
settings. Prefer common regional defaults unless the selected privacy profile
has a reason to preserve or model a user override. Do not seed-generate rare
calendar choices as decoration.

Purpose labels and derivation salts should remain internal and seed-bound.
Returned API values must not expose readable project names, mitigation names,
profile IDs, or derivation labels.

## Impact and Tradeoffs

Locale spoofing is highly user-visible. It can change UI language, date and
number formatting, currency display, measurement units, sorting, search,
content negotiation, analytics locale buckets, and server-side experiments.
Even when the app UI does not change, date and number parsing may.

Keyboard-language spoofing can break multilingual typing, autocorrect,
language-specific search, translation features, chat apps, note apps, and
keyboard-aware product flows. It can also be contradicted by actual typed text
or the currently selected keyboard if only enumeration APIs are spoofed.

Time-zone spoofing can affect calendars, alarms, travel apps, maps, delivery
windows, logs, fraud checks, authentication risk scoring, and server-side
timestamp interpretation. It can be contradicted by IP geolocation, carrier
country, Location permission results, local network context, or user-visible
clock behavior.

Calendar, first-day, and hour-cycle spoofing can confuse users quickly because
they affect dates and times everywhere. A strict profile that hides a rare
setting is useful for privacy, but it may also make the app feel localized for
someone else.

The safest default is compatibility-first pass-through. Strict mitigation should
switch to a coherent profile only when the user accepts the localization and
time-zone tradeoffs. Returning independent random values is worse than
pass-through because it creates a rare, internally contradictory fingerprint.

## Relevance

Locale & Region is a high-priority passive-native fingerprint category. It does
not provide a stable identifier like IDFV, but it contributes strong entropy
before any permission prompt appears, especially for multilingual users and
users with non-default keyboard, calendar, time-zone, first-day, or hour-cycle
settings.

The most important Loupe signals are `preferredLanguages`, `keyboards`, and
`tz.identifier`. `identifier`, `calendar`, `hourCycle`, and `firstDayOfWeek`
are essential coherence anchors. They should feed a single locale-profile plan
rather than many independent mitigation toggles.

