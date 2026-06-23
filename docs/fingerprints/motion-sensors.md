# Motion & Sensors

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/MotionProvider.swift`

Loupe category: Motion & Sensors
Loupe tier: permissioned local sensor/history queries, with active local
observation in stream mode
Permission required: Motion & Fitness authorization through the Core Motion
surfaces Loupe uses
Primary relevance: activity state, step history, altitude/barometer context,
fitness behavior, place/context inference, and coherence with device-motion,
location, health, and power profiles.

This page covers the Core Motion APIs that Loupe separates from raw device
motion: `CMMotionActivityManager`, `CMPedometer`, and `CMAltimeter`. The
upstream provider comments call these the APIs that genuinely trigger the iOS
Motion prompt. Permission-free `CMMotionManager` inertial samples live in
`device-motion.md`.

## Official Links

- Apple Core Motion `CMMotionActivityManager`: <https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager>
- Apple Core Motion `CMMotionActivity`: <https://developer.apple.com/documentation/coremotion/cmmotionactivity>
- Apple Core Motion `CMPedometer`: <https://developer.apple.com/documentation/coremotion/cmpedometer>
- Apple Core Motion `CMPedometerData`: <https://developer.apple.com/documentation/coremotion/cmpedometerdata>
- Apple Core Motion `CMAltimeter`: <https://developer.apple.com/documentation/coremotion/cmaltimeter>
- Apple Core Motion `CMAltitudeData`: <https://developer.apple.com/documentation/coremotion/cmaltitudedata>
- Apple Core Motion `CMAbsoluteAltitudeData`: <https://developer.apple.com/documentation/coremotion/cmabsolutealtitudedata>
- Apple bundle resource `NSMotionUsageDescription`: <https://developer.apple.com/documentation/bundleresources/information-property-list/nsmotionusagedescription>

## Loupe Signals and Decisions

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `activity` | `CMMotionActivityManager.queryActivityStarting(from:to:to:)` for the last 60 seconds, and `startActivityUpdates(to:)` in stream mode | Motion & Fitness | Permissioned history query; stream mode is active local observation | Include | Medium to high. Activity labels and confidence reveal current behavior such as walking, running, cycling, stationary, or automotive. |
| `altimeter.pressure` | `CMAltimeter.startRelativeAltitudeUpdates(to:withHandler:)` | Motion & Fitness on Loupe's modeled surface | Permissioned active local sensor sampling | Include | Medium. Barometric pressure reflects local environment, weather, building elevation, and sensor state. |
| `altimeter.relativeAltitude` | `CMAltitudeData.relativeAltitude` from the relative altimeter stream | Motion & Fitness on Loupe's modeled surface | Permissioned active local sensor sampling | Include | Medium. Relative altitude can reveal stairs, elevators, floor changes, and recent movement. |
| `altimeter.absoluteAltitude` | `CMAltimeter.startAbsoluteAltitudeUpdates(to:withHandler:)` | Motion & Fitness on Loupe's modeled surface | Permissioned active local sensor sampling | Include | High when available. Absolute altitude narrows geography and building context even without GPS. |
| `altimeter.absoluteAccuracy` | `CMAbsoluteAltitudeData.accuracy` | Motion & Fitness on Loupe's modeled surface | Permissioned active local sensor sampling | Include | Medium. Accuracy constrains how believable the reported altitude is and can reveal sensor/fusion quality. |
| `altimeter.absolutePrecision` | `CMAbsoluteAltitudeData.precision` | Motion & Fitness on Loupe's modeled surface | Permissioned active local sensor sampling | Include | Medium. Precision is a consistency check for altitude and sensor quality. |
| `pedometer.steps` | `CMPedometer.queryPedometerData(from:to:)` from start of current day, and `startUpdates(from:)` in stream mode | Motion & Fitness | Permissioned history query; stream mode is active local observation | Include | High. Daily step count is behaviorally rich and slow-moving enough to link sessions. |
| `pedometer.distance` | `CMPedometerData.distance` | Motion & Fitness | Permissioned history query | Include | Medium to high. Distance reveals activity level and constrains step count, pace, and cadence. |
| `pedometer.floorsUp` | `CMPedometerData.floorsAscended` | Motion & Fitness | Permissioned history query | Include | Medium. Floors climbed reveal building use and daily activity. |
| `pedometer.floorsDown` | `CMPedometerData.floorsDescended` | Motion & Fitness | Permissioned history query | Include | Medium. Floors descended should track floors ascended and altitude changes over the day. |
| `pedometer.pace` | `CMPedometerData.currentPace` | Motion & Fitness | Permissioned live/history value | Include | Medium. Pace reveals current movement state and must match activity labels. |
| `pedometer.cadence` | `CMPedometerData.currentCadence` | Motion & Fitness | Permissioned live/history value | Include | Medium. Cadence is a behavioral gait signal and should match pace and activity. |
| `pedometer.averageActivePace` | `CMPedometerData.averageActivePace` | Motion & Fitness | Permissioned history aggregate | Include | Medium. Average pace summarizes the day's active movement. |
| `unavailable` | macOS placeholder | None | Platform placeholder | Exclude | Not a device fingerprint value. It only records that this Loupe category is unavailable on macOS. |

The provider checks availability before each family: activity, relative
altimeter, absolute altimeter, and pedometer. Absence of a value can itself
become a capability signal, so mitigation should preserve realistic availability
for the selected device and OS profile.

## Permission and Activity Classification

This category is permissioned in normal app privacy terms. Loupe's provider is
constructed with a `PermissionCenter`, and the upstream comments distinguish
these APIs from permission-free `CMMotionManager` samples.

The one-shot `collect()` path performs active local work:

- queries recent activity from the previous 60 seconds
- starts relative altitude updates and waits up to one second
- starts absolute altitude updates and waits up to one second
- queries pedometer totals from the start of the current day to now

The `stream()` path is active local observation. It starts activity, altimeter,
absolute-altimeter, and pedometer updates where available, maintains the latest
snapshot, and yields whenever one of the sensor streams changes.

No network request, Bluetooth scan, camera capture, microphone capture, Contacts
read, or Local Network probe is involved in this provider.

## Fingerprinting Value

Activity classification is valuable because it reveals what the user is doing
right now. `stationary`, `walking`, `running`, `automotive`, and `cycling` are
low-cardinality labels, but they become powerful when joined with time of day,
location-like altitude, route, battery, audio, and foreground app behavior.

Pedometer totals are stronger because they are cumulative over the day. Step
count, distance, floors, pace, cadence, and average active pace form a behavior
tuple that can link sessions and reveal lifestyle. Even rounded values can
distinguish "inactive morning", "commute already happened", "workout in
progress", or "late-day high activity" contexts.

Altitude and pressure expose environment. Relative altitude can reveal stairs,
elevators, buildings, transit, and current vertical movement. Absolute altitude,
when available, is especially sensitive because it can narrow geography or
floor-level context without using Core Location.

The values are also consistency checks. A profile that says the user is
stationary while step count and cadence are rising, or that reports major
altitude changes without matching activity and pressure changes, is easy to
flag as synthetic.

## Mitigation Strategy Ideas

### `motion.activity`

Hook activity queries and live updates as one surface:

- `CMMotionActivityManager.isActivityAvailable()`
- `queryActivityStarting(from:to:to:withHandler:)`
- `startActivityUpdates(to:withHandler:)`
- `stopActivityUpdates()`

Compatibility default should pass through because apps use activity for fitness,
navigation, safety, trip detection, journaling, accessibility, and battery
optimization.

Strict behavior can return a low-entropy activity state such as stationary or
unknown, but only when other motion surfaces agree. A user whose raw sensors,
pedometer cadence, and screen interactions all show movement should not receive
a permanently stationary activity profile.

### `motion.altimeter`

Cover relative pressure/altitude and absolute altitude as one linked surface:

- `CMAltimeter.isRelativeAltitudeAvailable()`
- `CMAltimeter.isAbsoluteAltitudeAvailable()`
- relative altitude update callbacks
- absolute altitude update callbacks
- `CMAltitudeData.pressure`
- `CMAltitudeData.relativeAltitude`
- `CMAbsoluteAltitudeData.altitude`, `accuracy`, and `precision`

Compatibility default should pass through for navigation, fitness, weather,
hiking, indoor-positioning, accessibility, safety, and measurement apps.

Strict behavior can coarsen pressure, reset relative altitude to a local
session baseline, or suppress absolute altitude by returning unavailable only
when that is plausible for the device/OS profile. Do not return precise
seed-derived altitude values that would identify the protected user.

### `motion.pedometer`

Treat daily steps, distance, floors, pace, cadence, and average active pace as a
single temporal model:

- `CMPedometer.isStepCountingAvailable()`
- `queryPedometerData(from:to:withHandler:)`
- `startUpdates(from:withHandler:)`
- `CMPedometerData` fields exposed by Loupe

Compatibility default should pass through for fitness, health, accessibility,
navigation, and gamified activity apps.

Strict behavior can return coarse, plausible daily activity buckets. The model
should advance over wall time, keep totals monotonic within the day, and avoid
high-entropy exact counts. Returning `0` all day is privacy-protective but
unrealistic for many users and can break app behavior.

## Derivation and Coherence Considerations

Motion & Sensors values are temporal and behavior-driven. They should be
generated from a small coherent activity model, not independent seed-derived
numbers.

Core coherence rules:

```text
steps are monotonic within the modeled day
distance agrees with steps and stride assumptions
pace and cadence agree with activity state
floors agree with relative altitude changes
absolute altitude agrees with pressure and location/profile context
activity confidence is plausible for the modeled sensor evidence
stream callbacks and later property/query results tell the same story
```

Availability must also be coherent. If the selected device profile lacks
barometer or absolute altitude support, the provider should not expose related
values. If pedometer support is hidden, all pedometer fields and live updates
must disappear together.

Generated daily activity should be scoped and reset by a profile day boundary.
Avoid per-app random step counts that contradict each other across apps opened
at the same time. Avoid exact, stable seed-derived numbers that become a new
identifier.

Purpose labels for generated values should remain internal and seed-bound.
Returned values must not expose readable mitigation names, salts, or profile
IDs.

## Impact and Tradeoffs

Spoofing this category can break legitimate features. Fitness apps, safety
features, navigation, journaling, accessibility tools, games, and health
workflows may rely on real motion history and live updates.

Suppressing altitude can reduce place leakage but may degrade hiking, weather,
indoor navigation, and emergency context. Suppressing pedometer data can protect
behavioral privacy but may make activity apps useless. Normalizing activity to
stationary can save privacy but conflicts with real movement and raw sensor
evidence.

The strongest privacy posture is to deny or avoid the Motion & Fitness
permission for apps that do not need it. Runtime mitigation is a second layer
for apps that already have permission or where the user wants compatibility
with reduced precision.

## Relevance

Motion & Sensors is relevant because it is a permissioned but high-value
behavioral category. It is not a silent surface in the same way as Device
Motion, but once granted it exposes rich live and historical context that can
link sessions and reveal sensitive daily patterns.

Default behavior should be permission-respecting pass-through. Strict profiles
can add coherent activity, altitude, and pedometer models later, with special
care for monotonic counters and cross-app temporal consistency.
