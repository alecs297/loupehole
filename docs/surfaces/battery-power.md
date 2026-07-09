# Battery & Power

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/BatteryProvider.swift`

Loupe category: Battery
Loupe tier: passive local state, with active local sampling in stream mode
Permission required: none
Primary relevance: slow-changing session correlation, power-state behavior, and
thermal/performance coherence.

This category covers battery and power values that apps can read without a user
permission prompt. The values are low-cardinality individually, but they change
slowly enough to link short sessions and can explain or contradict other timing,
performance, charging, and background-execution observations.

## Official Links

- [`UIDevice.isBatteryMonitoringEnabled`](https://developer.apple.com/documentation/uikit/uidevice/isbatterymonitoringenabled)
- [`UIDevice.batteryLevel`](https://developer.apple.com/documentation/uikit/uidevice/batterylevel)
- [`UIDevice.batteryState`](https://developer.apple.com/documentation/uikit/uidevice/batterystate-swift.property)
- [`UIDevice.BatteryState`](https://developer.apple.com/documentation/uikit/uidevice/batterystate-swift.enum)
- [`UIDevice.batteryLevelDidChangeNotification`](https://developer.apple.com/documentation/uikit/uidevice/batteryleveldidchangenotification)
- [`UIDevice.batteryStateDidChangeNotification`](https://developer.apple.com/documentation/uikit/uidevice/batterystatedidchangenotification)
- [`ProcessInfo.isLowPowerModeEnabled`](https://developer.apple.com/documentation/foundation/processinfo/islowpowermodeenabled)
- [`ProcessInfo.PowerStateDidChangeMessage`](https://developer.apple.com/documentation/foundation/processinfo/powerstatedidchangemessage)
- [`ProcessInfo.thermalState`](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.property)
- [`ProcessInfo.ThermalState`](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum)
- [`ProcessInfo.thermalStateDidChangeNotification`](https://developer.apple.com/documentation/foundation/processinfo/thermalstatedidchangenotification)

Apple documents battery level and state behind battery monitoring. Loupe enables
that monitoring before reading the values, and temporarily restores the previous
monitoring state for one-shot collection when it had been disabled.

## Loupe Signals

| Loupe signal | Provider source | Permission | Classification | Fingerprinting value |
| --- | --- | --- | --- | --- |
| `batteryLevel` | `PlatformDevice.isBatteryMonitoringEnabled = true`, then `PlatformDevice.batteryLevel` and `PlatformDevice.batteryState` | None | Passive local read with a battery-monitoring side effect; stream mode samples every 5 seconds | Medium. Charge level is formatted to two decimals, changes slowly, and can link app launches or web sessions close in time. State adds charging, full, unplugged, or unknown context. |
| `lowPowerMode` | `ProcessInfo.processInfo.isLowPowerModeEnabled` | None | Passive local process-info read | Low to medium. It is a single boolean, but enabled state may be rarer and can correlate with user behavior, battery level, background limits, and performance policy. |
| `thermalState` | `ProcessInfo.processInfo.thermalState` mapped to `nominal`, `fair`, `serious`, `critical`, or `unknown` | None | Passive local process-info read | Low to medium. It is low-cardinality and often transient, but can correlate with workload, charging, ambient heat, throttling, and timing measurements. |

Loupe emits `batteryLevel` as a compound signal with two entries: `Level` and
`State`. If `batteryLevel` is negative, Loupe displays `unknown`; otherwise it
formats the level as a fractional value with two decimal places.

## Permission and Activity Classification

No signal in this category needs Contacts, Location, Bluetooth, Local Network,
Motion, Photos, or another user-granted runtime permission. A normal app can
query these values directly.

Battery level and state are not available as simple passive constants until
battery monitoring is enabled. Loupe sets `isBatteryMonitoringEnabled` to
`true` before reading them. That is still local process activity, not an
external probe and not a permission prompt, but mitigation work should treat the
monitoring flag, battery properties, and battery notifications as one coherent
surface.

Loupe's one-shot `collect()` path is passive collection with a local enable/read
side effect. Loupe's `stream()` path is active local sampling: it enables
battery monitoring, yields immediately, then refreshes every 5 seconds until the
stream ends. Low Power Mode and thermal state are passive reads in both paths,
with equivalent notification surfaces available to apps that observe changes.

## Fingerprinting Value

Battery level is the strongest value in this category because it is a
slow-moving time-domain signal. Two sessions that see the same charge level and
charging state within a short period can be linked even if more stable
identifiers are hidden. The value also constrains plausible timelines: a device
cannot jump from 0.34 unplugged to 0.92 unplugged a minute later.

Battery state is lower-cardinality but important context. `charging`, `full`,
`unplugged`, and `unknown` explain why level changes or stays fixed. State also
lets trackers compare reported power state against external power behavior,
performance, background execution, and user-visible battery changes.

Low Power Mode is a boolean, so it is not unique by itself. It becomes useful
when joined with battery level, charging state, app throttling, background
refresh behavior, animation/timer decisions, and performance timing. A rare
enabled value can add entropy in a population where most devices report `false`.

Thermal state is also low-cardinality, but it is useful as a consistency and
context signal. Higher thermal states can coincide with charging, sustained CPU
or GPU work, throttled timing, background-service reduction, and user behavior.
It can help distinguish a real device state from a synthetic profile that only
changes static identity fields.

## Mitigation Strategy Ideas

### `power.battery-level-state`

Hook the battery monitoring and battery value surface as a group:

- `UIDevice.isBatteryMonitoringEnabled`
- `UIDevice.batteryLevel`
- `UIDevice.batteryState`
- battery level and battery state notifications
- any equivalent platform wrapper used by the target process

Compatibility default should pass through unless a profile explicitly enables
power-state normalization. Many apps use battery state for legitimate UI or
resource decisions, and incorrect values are visible to users.

Strict mode can return a synthetic per-scope battery timeline. The timeline
should be plausible rather than fixed: level should drift slowly, charging state
should explain the direction of drift, and `full` should only appear at or near
100 percent. Until Loupehole owns the full timeline and notification surface, a
scoped transfer curve over the real level is a safer middle ground than a fixed
level or a 1:1 raw value. Use a small finite curve family and common display
precision rather than high-entropy per-user decimals. If returning `unknown`,
keep both level and state unknown and preserve the platform's disabled-monitoring
behavior.

Do not spoof only `batteryLevel` while leaving `batteryState` real. That creates
easy contradictions such as an unplugged state with rapidly rising charge, or a
full state with a low level.

### `power.low-power-mode`

Hook `ProcessInfo.isLowPowerModeEnabled` and the corresponding power-state
change notification path. Compatibility default should pass through because
apps may reduce work, disable background activity, or change network behavior
when Low Power Mode is active.

Strict mode can normalize to the common `false` value, but that is safest only
when the rest of the process behavior is also compatible with normal power
policy. If the real system is in Low Power Mode, timers, background execution,
and app behavior may still reveal the underlying state. Avoid deriving a random
boolean per app or user; a seeded rare `true` value can be more identifying than
the original.

### `power.thermal-state`

Hook `ProcessInfo.thermalState` and thermal-state change notifications as a
single surface. Compatibility default should pass through because thermal state
is a safety and performance signal that apps are supposed to respect.

Strict mode can bucket to `nominal` or possibly `fair` for short reads, but it
must account for observable consequences. Returning `nominal` while the app is
throttled, timers are delayed, or the device is visibly hot creates a strong
synthetic marker. Never generate `serious` or `critical` as a random profile
value; those states are rare, operationally meaningful, and higher entropy.

## Derivation Considerations

Battery level and state should be temporal values, not static identity values.
Derive a per-scope timeline from the active seed, scope, and a profile epoch,
then store or reconstruct it so repeated reads during the same session remain
stable. The timeline should advance with wall time, respect charging state, and
avoid impossible jumps.

Good battery derivation should construct related fields together:

```text
batteryState determines allowed level movement
level changes slowly across short windows
full implies level is near 1.00
unknown level pairs with unknown state
notification values match property values
```

Use coarse common buckets unless an app genuinely needs fine-grained values.
Loupe displays two decimals, but returning a unique seed-derived decimal can
turn mitigation into a new identifier. A deterministic value from a common
population shape is safer than a high-cardinality synthetic charge.

The current compiled `power.battery` module is an intermediate mitigation, not a
complete synthetic timeline. It passes through `batteryState`, maps valid real
levels through a scoped monotonic nonlinear curve selected from a small finite
seeded family, and rounds to two decimals. This keeps reported charge continuous
with real movement but not 1:1 with the raw level. A future strict mode should
also own monitoring enablement, notifications, charging direction, and
state-level coherence.

Low Power Mode should be a policy choice, not a high-cardinality derivation.
The useful modes are pass-through, normalize false, or explicitly preserve true
for compatibility. Do not rotate it independently from battery level and state,
because a low battery with disabled Low Power Mode and an unplugged state can be
plausible, but the same tuple should stay coherent over time.

Thermal state should usually pass through or use a short-lived low-entropy
bucket. If strict normalization is required, derive only common states and keep
them consistent with workload, charging, and performance/timing observations.

Purpose labels for generated values should remain internal and seed-bound.
Returned API values must not expose readable project names, mitigation names,
profile IDs, or derivation salts.

## Impact and Tradeoffs

Battery spoofing can confuse apps that display charge, defer uploads until
charging, warn users before long tasks, or change behavior when power is low.
It can also be user-visible if an app reports a battery state that conflicts
with the system UI.

Low Power Mode spoofing can make apps perform too much work on a constrained
device or unnecessarily disable features on a normal device. Passing through is
more compatible; normalizing to `false` reduces a rare-state fingerprint but can
be contradicted by OS scheduling and background behavior.

Thermal-state spoofing has the highest safety and performance risk in this
category. Apps use thermal state to back off expensive work. Hiding `serious` or
`critical` can increase heat or battery drain, while faking those states can
degrade functionality for no privacy benefit.

The main implementation risk is partial coverage. Apps can read current
properties, subscribe to notifications, infer state through behavior, or compare
power data with timing and performance. A good mitigation should either cover
the related paths coherently or pass through.

## Relevance

Battery & Power is relevant for v1 planning as a passive-native temporal
fingerprint category. It is not as stable as IDFV, hostname, OS version, or boot
time, but it can link sessions close in time and can reveal contradictions in a
synthetic profile.

`batteryLevel` plus battery state is the highest-priority surface here because
it changes slowly and is directly sampled by Loupe. Low Power Mode and thermal
state are lower priority as standalone values, but they are important coherence
dependencies for background behavior, performance timing, charging state, and
power-aware app decisions.

Default behavior should be compatibility-first pass-through. Strict profiles
can add synthetic power state later, but only as a small coherent model rather
than independent random values.
