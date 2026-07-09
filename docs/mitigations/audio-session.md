# `audio.session`

The audio-session option reduces precision and personalized labels from iOS audio-session metadata. It covers passive `AVAudioSession` reads used by Loupe's Audio Route provider.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `audio.session` |
| Implemented mitigation | `audio.session.avaudiosession.coarse_values` |
| Policy seeds | None; this mitigation buckets real values and returns generic cohort labels. |
| User-facing name | Audio session metadata |
| Status | Experimental |
| Surface | Audio route |
| Classification | Passive audio-session fingerprinting surface; active Objective-C hook mitigation |
| Affected APIs | `AVAudioSessionPortDescription.portName`, `AVAudioSession.outputVolume`, `sampleRate`, `outputLatency`, `inputLatency`, `isOtherAudioPlaying` |
| Default behavior | Active when selected and allowed by runtime policy |
| Permission requirement | None for these metadata reads |

## Surface And Relevance

Audio route metadata can expose named accessories, current output volume, active sample rate, latency, and whether another app is playing audio. Accessory names are the highest-risk value because they can contain owner, room, car, headset, AirPlay, or external-device context.

## Mitigation Strategy

The mitigation hooks audio-session scalar properties and port-name reads:

- `portName` returns a generic label derived from the real `portType`, such as `Speaker`, `Receiver`, `Bluetooth Audio`, or `AirPlay`.
- `outputVolume` is rounded to tenths.
- `sampleRate` is downshifted to the nearest common 44.1 kHz or 48 kHz value when close enough to those cohorts.
- `outputLatency` and `inputLatency` are rounded to 5 ms buckets.
- `isOtherAudioPlaying` returns `NO`.

It does not alter route arrays, route-change notifications, audio-session activation, recording permission, CoreAudio HAL, macOS device inventory, channel counts, or actual audio capture/playback behavior.

## Derivation And Lifetime

No policy seed is declared because this module does not create a scoped synthetic identity. It reduces the precision of the real value or returns a shared generic label. Repeated reads follow the underlying system state through the same bucket function.

## Impact And Tradeoffs

Generic port names hide personalized accessory names while preserving the broad route type. Coarse volume and latency reduce short-session entropy but can still be contradicted by apps that compare against KVO notifications, route-change payloads, audio-engine timing, or CoreAudio paths not covered here.

Normalizing `isOtherAudioPlaying` to false can affect apps that decide whether to mix, duck, defer, or silence audio. Audio-centric apps may need this module disabled.

## Validation

Repository-level validation is pending until the catalog and default selection are merged. Expected observations:

- Loupe's iOS audio route names no longer expose personalized port names.
- Volume is reported in 0.1 buckets.
- Latency is reported in 5 ms buckets.
- Sample rate reports common 44.1 kHz or 48 kHz cohorts where applicable.
- Other audio playing reports false.

## Rollback And Pass-Through

If the target classes or selectors are unavailable, the module registers as a no-op. For scalar values, invalid original values pass through unchanged. Disabling the module restores original `AVAudioSession` behavior for these properties.
