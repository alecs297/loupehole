# `voices.inventory`

The voice-inventory option hides downloaded Enhanced and Premium speech voices from native AVSpeechSynthesisVoice enumeration while preserving baseline/default voices.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `voices.inventory` |
| Implemented mitigation | `voices.inventory.avspeech.downloaded_hidden` |
| Policy seeds | None; this module filters original AVSpeechSynthesisVoice objects |
| User-facing name | Installed speech voices |
| Status | Experimental |
| Surface | Installed voices |
| Classification | Passive local voice inventory; active AVFoundation hook mitigation |
| Affected APIs | `+[AVSpeechSynthesisVoice speechVoices]`, `+[AVSpeechSynthesisVoice voiceWithLanguage:]`, `+[AVSpeechSynthesisVoice voiceWithIdentifier:]` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None |

## References

- Apple Developer: `AVSpeechSynthesisVoice`.
- Apple Developer: `AVSpeechSynthesisVoice.speechVoices()`.
- Apple Developer: `AVSpeechSynthesisVoice.language`.
- Apple Developer: `AVSpeechSynthesisVoice.quality`.
- W3C Community Group: Web Speech API.

## Surface And Relevance

Downloaded Enhanced and Premium voices are durable user-selected assets and can be rare. Loupe reports the full voice list, distinct languages, count, and downloaded voice names, so all native summary values should come from one visible list.

## Mitigation Strategy

The mitigation hooks the `AVSpeechSynthesisVoice` class methods that enumerate or look up native voices:

- `speechVoices` filters out voices whose quality is above the default quality.
- `voiceWithLanguage:` returns the original voice when visible, otherwise falls back to the first visible voice with the same exact or base language.
- `voiceWithIdentifier:` returns nil for hidden downloaded voices.

Returned voices are original platform objects. The module does not invent voice names, genders, qualities, identifiers, or language tags.

Web Speech, speech playback, Siri/dictation voices, spoken-content settings, voice asset files, and download history are not covered.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifiers | None |
| Value shape | Filtered arrays or original visible `AVSpeechSynthesisVoice` objects |
| Derivation input | Original AVSpeech voice inventory |
| Storage behavior | No mitigation-owned state |
| Lifetime | Tracks baseline/default voice availability; downloaded voices stay hidden while enabled |
| Dependencies | Locale and Web Speech voice coherence remain future work |

Voice names should be real platform names from a shared baseline, not seed-derived synthetic strings. This first module hides high-entropy downloaded voices without replacing them with rare generated alternatives.

## Impact And Tradeoffs

Voice filtering can affect accessibility, spoken-content, language-learning, communication, navigation, and reading apps. A hidden downloaded voice may cause fallback to a lower-quality baseline voice or no exact identifier match. Hybrid apps can still compare native behavior with Web Speech until WebView coverage exists.

## Validation

Expected observations:

- Loupe's downloaded Enhanced/Premium list is empty or reduced to default-quality voices only.
- The total count, language set, and all-voice list come from the same filtered native list.
- Identifier lookup for a hidden downloaded voice returns nil.
- Speech playback and Web Speech remain outside coverage.

## Rollback And Pass-Through

If `AVSpeechSynthesisVoice` or its selectors are unavailable, the module registers as a no-op. If filtering would remove every voice, the original list is returned unchanged. Disabling the mitigation restores the real native voice inventory.
