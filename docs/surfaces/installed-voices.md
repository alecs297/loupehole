# Installed Voices

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/VoicesProvider.swift`

Loupe category: Installed Voices
Loupe tier: passive local speech-voice inventory
Permission required: none
Primary relevance: downloaded text-to-speech voice inventory, language
coverage, accessibility settings, and Web Speech API equivalence.

This category covers voices returned by `AVSpeechSynthesisVoice.speechVoices()`.
Loupe reports the total voice count, distinct language tags, explicitly
downloaded Enhanced or Premium voices, and the full per-voice list with
language, gender, and quality. Downloaded voices are especially identifying
because most devices do not have many of them.

## Official Links

- Apple AVFAudio [`AVSpeechSynthesisVoice`](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice)
- Apple AVFAudio [`AVSpeechSynthesisVoice.speechVoices()`](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice/speechvoices%28%29)
- Apple AVFAudio [`AVSpeechSynthesisVoice.language`](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice/language)
- Apple AVFAudio [`AVSpeechSynthesisVoice.name`](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice/name)
- Apple AVFAudio [`AVSpeechSynthesisVoice.quality`](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice/quality)
- Apple AVFAudio [`AVSpeechSynthesisVoice.gender`](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice/gender)
- Apple AVFAudio [`AVSpeechSynthesisVoiceQuality`](https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoicequality)
- Apple AVFAudio [`AVSpeechSynthesizer`](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer)
- W3C Community Group [Web Speech API](https://dvcs.w3.org/hg/speech-api/raw-file/tip/webspeechapi)

The Web Speech API is an equivalent browser-facing surface because
`speechSynthesis.getVoices()` exposes a user-agent voice list. Loupe's provider
is native AVFoundation/AVFAudio, but mitigation planning should keep native and
WebView speech inventories coherent where possible.

## Loupe Signals and Decisions

| Loupe signal | Provider source | Platforms | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- | --- |
| `count` | Count of sorted `AVSpeechSynthesisVoice.speechVoices()` results | iOS, macOS | None | Passive local voice inventory summary | Include as a coarse summary | Low alone, medium when above baseline. It reveals whether the device has extra voices without naming them. |
| `languages` | Distinct `voice.language` values from all voices, localized through `Locale.current.localizedString(forIdentifier:)` for labels | iOS, macOS | None | Passive language-coverage summary | Include | Medium. The set of installed voice languages can reveal accessibility, multilingual, learning, or regional preferences. |
| `downloaded` | Voices whose `quality` is `.enhanced` or `.premium`, listed by name, language, and quality | iOS, macOS | None | Passive downloaded voice inventory | Include | High when non-empty. Enhanced and Premium voices are user-selected downloads and can be rare, large, and durable. |
| `all` | Full sorted voice list with `name`, `language`, `gender`, and non-default quality suffix | iOS, macOS | None | Passive full voice inventory enumeration | Include | High. The complete voice tuple can reveal OS baseline, locale, downloaded voices, voice quality, and unusual language support. |

Loupe sorts voices by language, then localized case-insensitive voice name. It
does not synthesize speech, play audio, request microphone access, or inspect
spoken-content preferences directly in this provider.

## Permission and Activity Classification

No included Installed Voices signal requires Contacts, Location, Bluetooth,
Local Network, Motion, Photos, Microphone, Speech Recognition, or another
runtime permission. The provider reads AVSpeechSynthesisVoice metadata.

The category is passive in Loupe's collection path. It enumerates voices but
does not start speech synthesis, capture audio, query the network, or download
voice assets. If a target app later speaks text, that is a separate active audio
behavior.

Voice inventory can still be sensitive. Downloaded Enhanced or Premium voices
often originate from explicit user choices in accessibility, spoken-content, or
language settings. The lack of a prompt does not make the inventory low risk.

## Fingerprinting Value

`downloaded` is the highest-value Loupe signal. Most devices have a common
baseline voice set. A user who downloads an Enhanced or Premium voice for a
specific language, accent, or accessibility workflow adds a durable and often
rare entry to the list. Multiple downloaded voices can become a distinctive
tuple.

`all` has high value because it combines baseline and custom state. Voice name,
language, gender, and quality can reveal OS version, locale support, installed
speech assets, and user preferences. Even when no downloaded voices are present,
the baseline set is a coherence dependency for OS and locale profiles.

`languages` is a useful middle ground. It is less revealing than full names, but
it can still expose multilingual needs or speech support that differs from the
device's current UI language. It must agree with locale, preferred languages,
keyboard languages, and Web Speech voices.

`count` is coarse and non-granular, but it detects inventory size. A count above
the baseline can reveal downloaded voices even if names are hidden, and a count
mismatch can expose partial mitigation.

The WebView equivalent matters. Browser fingerprinters can compare
`speechSynthesis.getVoices()` with native behavior in hybrid apps. If native
voice enumeration is normalized but WebKit still exposes the real voice list,
the profile remains linkable.

## Mitigation Strategy Ideas

### `voices.inventory`

Hook native voice inventory as a tuple:

- `AVSpeechSynthesisVoice.speechVoices()`
- `AVSpeechSynthesisVoice(language:)` and identifier-based lookup where used
- `name`, `language`, `quality`, `gender`, identifier, and traits for returned
  voice objects
- Web Speech API `speechSynthesis.getVoices()` in WebView-adjacent coverage

Compatibility default should pass through for screen reading, spoken-content,
education, language learning, navigation, communication, assistive technology,
and apps that let the user choose voices.

Strict mode can return a common baseline voice inventory for the selected OS,
locale, and device profile. The baseline must be complete enough that system
default voice selection and common language lookups still work.

### `voices.downloaded`

Downloaded Enhanced and Premium voices should be normalized carefully. A privacy
profile can hide downloaded voices from generic apps while keeping default
voices available. If a downloaded voice is hidden from `downloaded`, it should
also be absent from `all`, the total count, and equivalent lookup APIs.

Do not replace real downloaded voices with seed-derived rare voices. That makes
the protected profile a unique synthetic speech inventory. Prefer common
baseline voices shared by many users.

### `voices.language_coverage`

Language coverage should be generated from locale and OS baseline data. If the
selected profile has `fr-BE`, `en-US`, and `nl-BE` as language surfaces, the
voice inventory should make plausible speech voices available for those
languages or fall back in a normal platform way.

Strict language reduction can improve privacy, but it can break apps that speak
multilingual text or select voices based on BCP 47 tags. A middle mode can hide
downloaded voices while preserving baseline language coverage.

### Native and Web Speech Coherence

Hybrid apps can compare native AVSpeechSynthesisVoice inventory to Web Speech
API output. A full mitigation should align:

- available voice count
- language tags and default voice
- local versus remote voice labels where exposed
- voice names and quality classes where comparable
- voice-list change events after installs or downloads

Until WebView coverage exists, document native voice normalization as partial.

## Derivation Considerations

Voice inventory should be profile-derived, not random. The derived profile
should include:

```text
OS build and baseline voice set
locale and preferred-language tuple
default voice and fallback behavior
downloaded Enhanced/Premium voice visibility policy
count and language set computed from the visible voices
native and Web Speech inventory coherence
```

`count`, `languages`, `downloaded`, and `all` must be generated from the same
visible voice list. Do not filter names while preserving a real count or
language set.

Downloaded voices are durable state. They should not rotate per launch. If a
profile models a voice download or removal, treat it as a stable user/settings
event with consistent voice-list change behavior.

Voice names should be real platform voice names from the selected baseline or a
known downloaded voice catalog. Do not derive readable project strings,
mitigation labels, salts, or unique synthetic names into the returned list.

## Impact and Tradeoffs

Voice inventory mitigation can directly affect accessibility and usability.
Users may depend on specific voices for spoken content, assistive workflows,
language learning, navigation, reading, or communication. Hiding a downloaded
voice can make an app select a worse fallback or fail to speak a language well.

Strict baseline normalization improves privacy for generic apps but can create
contradictions if speech playback still uses hidden real voices, if system
settings show the downloaded voices, or if Web Speech exposes a different list.

Count-only or language-only normalization is insufficient. Apps can compare the
summary values with the full list, voice lookup APIs, speech behavior, or
WebView APIs. Incomplete coverage risks creating a rarer profile.

The safest default is pass-through. Privacy-focused profiles should hide
downloaded voices only for apps that do not need speech functionality, and they
should keep a complete, common baseline inventory.

## Exclusion Note

Loupe's Installed Voices provider excludes these adjacent surfaces:

- actual speech synthesis, utterance timing, audio output, and voice playback
- Speech Recognition permission and transcription APIs
- spoken-content settings outside the visible voice inventory
- voice asset files on disk and download history
- Siri voice, dictation, keyboard dictation, and screen-reader state

`count` and `languages` are coarse, non-granular summaries, but they are
included because they reveal inventory shape and must match the full `all` and
`downloaded` lists. The primary sensitive surface remains the explicit
downloaded voice and full voice inventory.

## Relevance

Installed Voices is a strong passive-native category for users with downloaded
voices and a medium-priority coherence category for everyone else. It is
especially relevant because web and native speech APIs can expose equivalent
inventory.

The mitigation priority is medium to high for generic apps and WebView-heavy
apps, with a compatibility-first default for accessibility and speech-centric
apps.
