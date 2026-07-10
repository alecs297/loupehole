# Audio

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/AudioRouteProvider.swift`

Loupe category: Audio Route
Loupe tier: passive local audio state, with active local session activation and
live observation in stream mode
Permission required: none for Loupe's collected route, volume, sample-rate,
latency, channel-count, and device-name metadata. Microphone permission is only
required when an app records or captures microphone input.
Primary relevance: accessory names, route context, audio hardware capability,
ambient-session state, and macOS audio-device inventory.

This category covers audio-session and audio-device metadata that a normal app
can read without a user permission prompt. The highest-risk values are not raw
audio samples; they are names and route details that reveal paired accessories,
AirPlay targets, car/headset usage, virtual audio drivers, pro audio hardware,
or user context.

## Official Links

- [`AVAudioSession.currentRoute`](https://developer.apple.com/documentation/avfaudio/avaudiosession/currentroute)
- [`AVAudioSessionRouteDescription`](https://developer.apple.com/documentation/avfaudio/avaudiosessionroutedescription)
- [`AVAudioSessionRouteDescription.inputs`](https://developer.apple.com/documentation/avfaudio/avaudiosessionroutedescription/inputs)
- [`AVAudioSessionRouteDescription.outputs`](https://developer.apple.com/documentation/avfaudio/avaudiosessionroutedescription/outputs)
- [`AVAudioSessionPortDescription`](https://developer.apple.com/documentation/avfaudio/avaudiosessionportdescription)
- [`AVAudioSessionPortDescription.portName`](https://developer.apple.com/documentation/avfaudio/avaudiosessionportdescription/portname)
- [`AVAudioSessionPortDescription.portType`](https://developer.apple.com/documentation/avfaudio/avaudiosessionportdescription/porttype)
- [`AVAudioSession.sampleRate`](https://developer.apple.com/documentation/avfaudio/avaudiosession/samplerate)
- [`AVAudioSession.outputLatency`](https://developer.apple.com/documentation/avfaudio/avaudiosession/outputlatency)
- [`AVAudioSession.inputLatency`](https://developer.apple.com/documentation/avfaudio/avaudiosession/inputlatency)
- [`AVAudioSession.isOtherAudioPlaying`](https://developer.apple.com/documentation/avfaudio/avaudiosession/isotheraudioplaying)
- [`AVAudioSession.outputVolume`](https://developer.apple.com/documentation/avfaudio/avaudiosession/outputvolume)
- [`AVAudioSession.routeChangeNotification`](https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangenotification)
- [`AVAudioSession.setCategory(_:mode:options:)`](https://developer.apple.com/documentation/avfaudio/avaudiosession/setcategory%28_%3Amode%3Aoptions%3A%29)
- [`AVAudioSession.setActive(_:options:)`](https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive%28_%3Aoptions%3A%29)
- [`AVAudioSession.requestRecordPermission(_:)`](https://developer.apple.com/documentation/avfaudio/avaudiosession/requestrecordpermission%28_%3A%29)
- [`NSMicrophoneUsageDescription`](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSMicrophoneUsageDescription)
- [Core Audio overview](https://developer.apple.com/documentation/coreaudio)
- [`AudioObjectPropertyAddress`](https://developer.apple.com/documentation/coreaudio/audioobjectpropertyaddress)
- [`AudioObjectGetPropertyData`](https://developer.apple.com/documentation/coreaudio/audioobjectgetpropertydata%28_%3A_%3A_%3A_%3A_%3A_%3A%29)
- [`AudioObjectGetPropertyDataSize`](https://developer.apple.com/documentation/coreaudio/audioobjectgetpropertydatasize%28_%3A_%3A_%3A_%3A_%3A%29)
- [`kAudioHardwarePropertyDefaultOutputDevice`](https://developer.apple.com/documentation/coreaudio/kaudiohardwarepropertydefaultoutputdevice)
- [`kAudioHardwarePropertyDefaultInputDevice`](https://developer.apple.com/documentation/coreaudio/kaudiohardwarepropertydefaultinputdevice)
- [`kAudioObjectPropertyName`](https://developer.apple.com/documentation/coreaudio/kaudioobjectpropertyname)
- [`kAudioDevicePropertyNominalSampleRate`](https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertynominalsamplerate)
- [`kAudioDevicePropertyStreamConfiguration`](https://developer.apple.com/documentation/coreaudio/kaudiodevicepropertystreamconfiguration)
- [`kAudioHardwareServiceDeviceProperty_VirtualMainVolume`](https://developer.apple.com/documentation/audiotoolbox/kaudiohardwareservicedeviceproperty_virtualmainvolume)
- [`kAudioHardwarePropertyDevices`](https://developer.apple.com/documentation/coreaudio/kaudiohardwarepropertydevices)

Apple's permission model is important here: Loupe's Audio provider reads route
and device metadata. It does not record audio samples. Recording from a
microphone is a separate permissioned action that requires a microphone usage
description and user authorization.

## Loupe Signals

| Loupe signal | Provider source | Platforms | Permission | Classification | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `outputs` | iOS: `AVAudioSession.sharedInstance().currentRoute.outputs` mapped to `portType.rawValue` and `portName`; macOS: CoreAudio default output device name with type `default` | iOS, macOS | None | Passive route read after Loupe activates an ambient mixed session on iOS | High when names expose AirPods, AirPlay receivers, Bluetooth devices, HDMI docks, cars, displays, or pro audio interfaces. Route type alone is lower entropy but useful context. |
| `inputs` | iOS: `currentRoute.inputs` mapped to `portType.rawValue` and `portName`; macOS: CoreAudio default input device name with type `default` | iOS, macOS | None for metadata; microphone permission only for capture | Passive route read after Loupe activates an ambient mixed session on iOS | Medium to high. Input names can reveal headset microphones, external USB devices, Bluetooth accessories, studio hardware, or owner-named devices. |
| `sampleRate` | iOS: `AVAudioSession.sampleRate`; macOS: `kAudioDevicePropertyNominalSampleRate` on the default output device | iOS, macOS | None | Passive hardware/session read | Medium. Common values are low entropy, but unusual rates and route-dependent changes reveal accessory class, pro hardware, or current audio configuration. |
| `latency` | iOS: `AVAudioSession.outputLatency` and `AVAudioSession.inputLatency` | iOS | None | Passive session read | Medium. Latency distinguishes built-in, wired, Bluetooth, AirPlay, and other routes, and it is a strong consistency check against reported route and sample rate. |
| `otherAudioPlaying` | iOS: `AVAudioSession.isOtherAudioPlaying` | iOS | None | Passive session read | Low to medium. It is a boolean, but it leaks current user activity and can correlate app launches with music, calls, navigation, media playback, or another app's audio session. |
| `outputVolume` | iOS: `AVAudioSession.outputVolume`; macOS: `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` on the default output device when available | iOS, macOS | None | Passive local read; iOS stream observes KVO changes | Medium. Volume is user state that changes slowly enough to link nearby sessions and can reveal context such as muted, headset, car, or media use. |
| `outputChannels` | macOS: CoreAudio `kAudioDevicePropertyStreamConfiguration` for the default output scope | macOS | None | Passive hardware read | Medium. Stereo is common, but multichannel, aggregate, HDMI, or pro interface counts narrow the device cohort and must match the output device. |
| `inputChannels` | macOS: CoreAudio `kAudioDevicePropertyStreamConfiguration` for the default input scope | macOS | None for metadata | Passive hardware read | Medium. Mono/stereo/multichannel input counts reveal microphone or interface class and must match the selected input device. |
| `allDevices` | macOS: CoreAudio `kAudioHardwarePropertyDevices`, then `kAudioObjectPropertyName` for each device | macOS | None for metadata | Passive system audio inventory read | High. Full device inventory can reveal virtual drivers, meeting software devices, DAW tools, external interfaces, displays, headset names, and other rare hardware/software combinations. |

Loupe's iOS `collect()` path calls `setCategory(.ambient, options:
.mixWithOthers)` and `setActive(true)` before reading the current snapshot.
The iOS `stream()` path yields an initial snapshot, observes
`AVAudioSession.outputVolume` through KVO, and listens for
`AVAudioSession.routeChangeNotification`. The macOS stream path yields one
CoreAudio snapshot and finishes.

## Permission and Collection Class

No included Loupe signal requires Contacts, Location, Bluetooth, Local Network,
Motion, Photos, Microphone, or another user-granted runtime permission. The
provider reads metadata exposed through `AVAudioSession` and CoreAudio HAL
property APIs. It does not capture microphone samples or system audio.

On iOS, collection is not purely inert because Loupe activates the shared audio
session with an ambient, mix-with-others category before reading state. That is
an active local setup step, but it is not a permission prompt and it is not an
external probe. In normal app terms, the resulting signals are passive local
audio-session metadata.

The iOS stream path is active local observation. Loupe subscribes to route
changes and output-volume changes, so a tracker can watch how the user's audio
state changes during the app session. The macOS path is currently a one-shot
passive CoreAudio metadata read.

Microphone permission should be modeled separately from this page. If a target
app attempts to record or capture microphone input, the relevant surfaces are
permission prompts, capture-device APIs, audio buffers, and recording state.
Audio-route metadata can still expose input-device names before any raw audio is
captured.

## Fingerprinting Value

Routes and port names are the highest-value iOS signals. A built-in receiver or
speaker route is common, but named accessories can be highly identifying. Names
such as personal AirPods, room-specific AirPlay speakers, car systems, HDMI
devices, hearing devices, Bluetooth headsets, and USB interfaces can reveal the
owner, household, workplace, vehicle, or physical environment.

Inputs carry similar risk. A route that exposes a headset microphone, USB audio
interface, Bluetooth input, hearing accessory, or external microphone gives a
tracker a hardware and context signal even when the app never records audio.
Input route state also constrains what sample rates, latencies, and channel
counts are plausible.

Sample rate and latency are useful because they describe the active route's
capabilities. A 44.1 kHz, 48 kHz, 96 kHz, or 192 kHz value is not unique alone,
but uncommon values and route-dependent changes narrow the cohort. Latency is
especially useful as a detector for AirPlay, Bluetooth, built-in speakers,
wired routes, and pro audio hardware.

`isOtherAudioPlaying` is a small boolean but a meaningful behavioral signal.
It can reveal whether the user is already listening to media, using navigation,
in a call-like audio state, or running another audio app. Combined with time,
volume, route, and foreground behavior, it can help link sessions.

Output volume is a slow-moving local setting. A precise value can link app
sessions close in time, and extreme values such as muted, very low, or maximum
volume can reveal context. The iOS stream path makes this more valuable because
it can observe changes during the session.

macOS `allDevices` is the broadest fingerprint in this category. The complete
device list can reveal external displays, virtual audio drivers, aggregate
devices, DAW tools, conferencing software devices, capture cards, and named
headsets. Even if no single device is unique, the set and order can become a
rare inventory tuple.

Channel counts add hardware shape. Stereo output and mono input are common, but
multichannel output, aggregate devices, professional interfaces, or unusual
input counts are strong cohort reducers. They also make route spoofing harder
because they must match the reported device names, sample rate, and latency.

## Mitigation Strategy Ideas

### `audio.route`

Hook the route-description surface as a group:

- `AVAudioSession.currentRoute`
- `AVAudioSessionRouteDescription.inputs`
- `AVAudioSessionRouteDescription.outputs`
- `AVAudioSessionPortDescription.portType`
- `AVAudioSessionPortDescription.portName`
- route-change notification payloads and timing where practical
- equivalent wrappers that expose the same active route

Compatibility default should pass through for apps with real audio behavior:
voice chat, media playback, hearing/accessibility tools, navigation, musical
instruments, recording, conferencing, route pickers, and AirPlay workflows.

Strict mode can return a generic built-in route. On iPhone, that usually means a
common built-in receiver or speaker output and no named accessory. On iPad or
Mac profiles, use a matching built-in speaker/microphone style. Keep the route
type plausible for the selected device class, and do not return personalized
port names.

Accessory names should be removed or replaced with common generic labels. Do
not generate seed-derived names such as unique headset labels; that turns the
mitigation into a new identifier.

### `audio.input-output-devices`

Treat input and output routes as one tuple. If the output claims a built-in
speaker, the input should not claim a rare external studio microphone unless the
profile intentionally models that device. If a profile exposes no input route,
sample-rate, latency, and capture behavior must remain plausible for that state.

For macOS, this mitigation should cover default input, default output, and the
full `allDevices` inventory. A strict profile can return a small common baseline
such as built-in speakers and built-in microphone. A compatibility profile can
pass through for audio-production, meeting, accessibility, and screen-recording
apps.

### `audio.sample-rate-latency`

Hook `AVAudioSession.sampleRate`, `AVAudioSession.outputLatency`,
`AVAudioSession.inputLatency`, and the macOS nominal sample-rate property where
applicable. These values should be generated from the chosen route profile, not
as independent random numbers.

Default should usually pass through, because audio engines, media apps, games,
and recording apps can depend on the true hardware rate and latency. Strict
mode can return common values, but only with a full route tuple. For example, a
built-in profile can use common sample rates and low built-in latency, while an
AirPlay-like profile must account for much higher output latency.

Avoid over-precise synthetic latency. Cohort-known values or small continuous
perturbations selected from a finite seeded family are safer than hard bucket
edges or per-user floating-point constants with six decimal places.

### `audio.other-audio-playing`

Hook `AVAudioSession.isOtherAudioPlaying` only as a policy value, not as a
random boolean. Compatibility default should pass through because apps may use
this value to decide whether to mix, duck, silence, or defer audio.

Strict mode can normalize to `false` for apps that only use the value as a
fingerprinting probe. If the real system is visibly playing audio or if other
audio affects app behavior, returning `false` may be contradicted by route,
ducking, interruptions, or user-visible audio behavior.

### `audio.output-volume`

Hook `AVAudioSession.outputVolume`, CoreAudio virtual main volume reads, and
observable update paths. Compatibility default should pass through for apps that
display volume, react to mute/low volume, or provide media controls.

Strict mode can shape volume through a small finite family of continuous curves
or map it to common coarse values. Keep the value session-stable unless a
modeled volume event occurs. If the hook supports volume-change notifications
or KVO, the reported notification values must match future property reads.

Do not return a high-cardinality seed-derived constant. A precise synthetic
volume can be more identifying than the original value.

### `audio.channel-counts`

For macOS, hook stream-configuration reads that reveal input and output channel
counts. Channel counts should be part of the device profile:

- built-in speaker output usually maps to common low channel counts
- built-in microphone input usually maps to common low channel counts
- HDMI, aggregate, multichannel, and pro interfaces require matching device
  names, sample rates, and available streams

Default should pass through for apps that use CoreAudio directly. Strict mode
can return common built-in counts, but only if the full device inventory is also
normalized.

## Derivation Considerations

Audio values are a coherent tuple, not independent fields:

```text
device class determines built-in route vocabulary
route type determines plausible port names
route determines sample rate, latency, and channel counts
device inventory determines available defaults
volume changes slowly and must match observations
other-audio state must agree with mixing/interruption behavior
```

Route names and device names should be cohort constants or generic labels, not
per-user random derivations. A deterministic choice from a small common set is
acceptable when strict mode needs variety, but generated names must never expose
readable project strings, salts, profile IDs, owner names, or unique accessory
labels.

Sample rate, latency, and channel counts should be selected from common route
profiles. These are better modeled as cohort-static values attached to a
synthetic route than as values derived directly from the seed. If the selected
profile rotates, rotate the tuple together.

Output volume is a slowly varying state value. If spoofed, derive or store a
coherent per-scope volume timeline or apply a finite-family transfer curve over
the real value. The value should not jump across reads unless the
notification/KVO path reports the same change.

`isOtherAudioPlaying` should be pass-through or a low-entropy policy constant.
Do not derive a rare `true` state per app or per user. A synthetic `true` can
make the protected profile more unique and can force app behavior that users do
not expect.

macOS device inventory should be generated as an ordered baseline list for a
coherent device profile or passed through. Hiding only `allDevices` while
leaving default input/output names, channel counts, sample rate, or volume real
creates easy contradictions.

## Impact and Tradeoffs

Audio spoofing has real compatibility risk. Apps use route, sample rate,
latency, and channel counts to configure audio engines, choose buffers, display
route UI, synchronize media, handle voice chat, avoid feedback, and support
recording or accessibility workflows.

Hiding accessory names improves privacy, but it can make route pickers,
headphone-specific UI, AirPlay workflows, Bluetooth behavior, car audio, and
hearing-device support confusing or wrong. For apps whose purpose is audio, a
pass-through default is usually safer.

Sample-rate and latency spoofing can break playback, recording, games, live
monitoring, conferencing, music tools, or media sync. Partial spoofing is easy
to detect when an app compares route type, engine format, buffer timing, and
observed latency.

Output-volume spoofing can be user-visible. An app that displays volume,
warns about muted audio, or reacts to loudness can disagree with system UI if
the value is synthetic. Bucketed strict mode is lower risk than a fixed value,
but pass-through is still the compatibility default.

`isOtherAudioPlaying` normalization can alter app behavior. An app may decide
whether to mix, duck, or silence itself based on this value. Returning the common
`false` value reduces fingerprinting in simple probes but can conflict with
real audio-session behavior.

macOS device-inventory normalization can break professional audio, meetings,
screen capture, virtual audio routing, and accessibility tools. It should be
profile- or app-gated rather than globally forced.

The main implementation risk is contradiction. A synthetic built-in route with
a pro-interface channel count, AirPlay-like latency, and real virtual-device
inventory is more detectable than pass-through.

## Relevance

Audio Route is a P1 native passive fingerprint category. It is less stable than
IDFV, hardware model, boot time, storage dates, display, or OS version, but it
is valuable because it exposes user context and named accessories without a
permission prompt.

For iOS, route names, output volume, sample rate, latency, and
`isOtherAudioPlaying` are most relevant to short-session correlation and
context leakage. For macOS, full audio-device inventory and channel counts are
especially relevant because installed virtual devices and external interfaces
can form rare tuples.

Default behavior should be compatibility-first pass-through for audio-centric
apps. Strict privacy profiles can normalize names, routes, volume, and device
inventory later, but only as a coherent audio profile rather than independent
per-field random values.
