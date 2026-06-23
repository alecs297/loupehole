# Device Motion

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/DeviceMotionProvider.swift`

Loupe category: Device Motion
Loupe tier: active local sensor sampling, permission-free in Loupe's observed
Core Motion path
Permission required: none for `CMMotionManager` raw and fused motion samples
Primary relevance: live pose, sensor bias, environment/magnetic context,
behavioral movement, and coherence with any motion, compass, AR, fitness, or
screen-orientation profile.

This page covers the permission-free Core Motion values that Loupe reads through
`CMMotionManager`. Loupe starts accelerometer, gyroscope, magnetometer, and
device-motion updates, samples the latest values, and stops the manager for
one-shot collection. In stream mode it keeps updates running and emits snapshots
every 0.2 seconds.

## Official Links

- Apple Core Motion `CMMotionManager`: <https://developer.apple.com/documentation/coremotion/cmmotionmanager>
- Apple Core Motion `CMDeviceMotion`: <https://developer.apple.com/documentation/coremotion/cmdevicemotion>
- Apple Core Motion `CMAccelerometerData`: <https://developer.apple.com/documentation/coremotion/cmaccelerometerdata>
- Apple Core Motion `CMGyroData`: <https://developer.apple.com/documentation/coremotion/cmgyrodata>
- Apple Core Motion `CMMagnetometerData`: <https://developer.apple.com/documentation/coremotion/cmmagnetometerdata>
- Apple Core Motion `CMAttitude`: <https://developer.apple.com/documentation/coremotion/cmattitude>
- Apple Core Motion `CMAcceleration`: <https://developer.apple.com/documentation/coremotion/cmacceleration>
- Apple Core Motion `CMRotationRate`: <https://developer.apple.com/documentation/coremotion/cmrotationrate>
- Apple Core Motion `CMMagneticField`: <https://developer.apple.com/documentation/coremotion/cmmagneticfield>
- Apple Core Motion `CMCalibratedMagneticField`: <https://developer.apple.com/documentation/coremotion/cmcalibratedmagneticfield>
- Apple Core Motion `CMAttitudeReferenceFrame`: <https://developer.apple.com/documentation/coremotion/cmattitudereferenceframe>
- Apple bundle resource `NSMotionUsageDescription`: <https://developer.apple.com/documentation/bundleresources/information-property-list/nsmotionusagedescription>

## Loupe Signals and Decisions

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `accelerometer` | `CMMotionManager.accelerometerData?.acceleration` after `startAccelerometerUpdates()` | None | Active local sensor sampling, permission-free | Include | High in live streams. Axis values expose pose, movement, vibration, and sensor noise/bias that can correlate sessions or distinguish devices. |
| `gyroscope` | `CMMotionManager.gyroData?.rotationRate` after `startGyroUpdates()` | None | Active local sensor sampling, permission-free | Include | High for movement behavior and sensor-bias fingerprinting, especially when sampled continuously. |
| `magnetometer` | `CMMotionManager.magnetometerData?.magneticField` after `startMagnetometerUpdates()` | None | Active local sensor sampling, permission-free | Include | Medium to high. Magnetic field values reveal local environment and sensor calibration traits. |
| `attitude` | `CMDeviceMotion.attitude` after `startDeviceMotionUpdates(using:)` | None | Active fused-motion sampling, permission-free | Include | Medium. Pose and yaw/pitch/roll are live behavior signals and must agree with gravity and heading. |
| `gravity` | `CMDeviceMotion.gravity` | None | Active fused-motion sampling, permission-free | Include | Medium. Device orientation and gravity vector can link pose, screen orientation, and interaction state. |
| `userAcceleration` | `CMDeviceMotion.userAcceleration` | None | Active fused-motion sampling, permission-free | Include | Medium to high in live streams. Movement without gravity can expose gait, hand tremor, vehicle motion, and handling style. |
| `rotationRateFused` | `CMDeviceMotion.rotationRate` | None | Active fused-motion sampling, permission-free | Include | Medium to high. Bias-corrected rotation is a coherence check against raw gyro and attitude changes. |
| `magneticFieldCalibrated` | `CMDeviceMotion.magneticField` when Loupe's selected attitude frame is north-aligned | None | Active fused-motion sampling, permission-free | Include | Medium. Calibrated field plus accuracy ties raw magnetometer, heading, environment, and compass state together. |
| `heading` | `CMDeviceMotion.heading` when the reference frame is magnetic or true north | None | Active fused-motion sampling, permission-free | Include | Medium. Heading leaks orientation relative to magnetic north and can reinforce location/environment inferences. |
| `unavailable` | macOS placeholder | None | Platform placeholder | Exclude | Not a device fingerprint value. It only records that this Loupe category is unavailable on macOS. |

Loupe chooses the best available attitude reference frame in this order:
`xMagneticNorthZVertical`, `xArbitraryCorrectedZVertical`,
`xArbitraryZVertical`. It only emits calibrated magnetic field and heading when
the selected frame is north-aligned.

## Permission and Activity Classification

Loupe's Device Motion provider is not passive in the strict sensor-lifecycle
sense: it starts local Core Motion updates, waits briefly, reads the latest
samples, and stops the manager. Stream mode keeps the sensors active and emits
updates every 0.2 seconds.

The collection is still permission-free in Loupe's observed path. It does not
use `CMMotionActivityManager`, `CMPedometer`, or `CMAltimeter`, and it does not
request the Motion & Fitness authorization covered by `NSMotionUsageDescription`.
Those permissioned surfaces are tracked in `motion-sensors.md`.

## Fingerprinting Value

Raw inertial sensors are valuable because they carry both live user behavior and
hardware imperfections. Accelerometer and gyro streams can expose pose,
handling style, walking or vehicle vibration, tremor, tap cadence, and timing
jitter. Long enough streams can also reveal sensor bias and scale differences
that survive app restarts.

Magnetometer values are valuable because they blend device calibration with the
physical environment. Nearby magnets, buildings, vehicles, desk equipment, and
phone cases can produce repeatable local patterns. A calibrated magnetic field
plus heading is more useful than either value alone because it gives both field
shape and orientation.

Fused device motion adds consistency. `attitude`, `gravity`,
`userAcceleration`, and fused `rotationRate` are not independent fields. A
tracker can compare gravity to roll and pitch, compare user acceleration to raw
acceleration after gravity removal, and compare attitude deltas to rotation
rate. Contradictions are easy to detect.

The values are not stable identifiers in the same way as IDFV or host name, but
they are high-value live signals. They can link nearby sessions, reveal physical
context, and detect synthetic profiles that only spoof static fields.

## Mitigation Strategy Ideas

### `motion.raw_inertial`

Cover raw accelerometer, gyroscope, and magnetometer reads together:

- `CMMotionManager.accelerometerData`
- `CMMotionManager.gyroData`
- `CMMotionManager.magnetometerData`
- start/stop/update-interval paths where an app observes lifecycle behavior

Compatibility default should pass through. Games, AR, navigation, camera,
fitness, accessibility, musical-instrument, measurement, and anti-motion-sickness
apps can depend on real sensor data.

Strict behavior can coarsen values, reduce sampling precision, or add small
plausible noise. It should avoid a fixed zero vector except for apps that are
known to tolerate inert sensors. A permanently motionless device is easy to
detect when the user is interacting with the app or the screen orientation is
changing.

### `motion.fused_device_motion`

Cover fused motion as one tuple:

- `CMDeviceMotion.attitude`
- `CMDeviceMotion.gravity`
- `CMDeviceMotion.userAcceleration`
- `CMDeviceMotion.rotationRate`
- `CMDeviceMotion.magneticField`
- `CMDeviceMotion.heading`
- attitude reference-frame selection where practical

Do not spoof these fields independently. A useful strict profile needs a simple
motion model that produces internally consistent attitude, gravity, user
acceleration, and rotation rate over time.

For fingerprint-only apps, a low-motion profile can be useful: common portrait
or flat-table orientation, near-zero user acceleration, small rotation-rate
noise, and a plausible gravity vector. For sensor-dependent apps, pass-through
or very light quantization is safer.

### `motion.heading_magnetic`

Treat raw magnetometer, calibrated magnetic field, accuracy, heading, and
reference-frame choice as one magnetic surface. Strict mode can suppress heading
by using a non-north-aligned behavior only if the underlying API path can be
made to match platform behavior. Otherwise, prefer coherent coarsening to an
impossible heading/magnetic-field pair.

Avoid returning a seed-derived magnetic environment that is stable across many
apps. A unique synthetic magnetic tuple can become a new fingerprint.

## Derivation and Coherence Considerations

Device-motion values are live sensor values, not durable identity fields. They
should not be derived as high-cardinality per-user constants. When strict
spoofing is required, derive only a low-entropy motion profile and generate the
time series from that profile.

Core coherence rules:

```text
gravity direction agrees with roll and pitch
attitude deltas agree with fused rotation rate
raw acceleration is plausible relative to gravity + userAcceleration
raw gyro is plausible relative to fused rotation rate
heading agrees with calibrated magnetic field and selected reference frame
values change smoothly at the requested update interval
```

The selected profile must also agree with screen orientation, AR/camera
tracking, compass/location surfaces, pedometer/activity state, and any visible
user interaction. A stationary phone profile conflicts with a foreground app
that is receiving strong shake, compass, step, or AR motion evidence.

Purpose labels for any generated values should remain internal and seed-bound.
Returned values must not expose readable mitigation names, profile IDs, salts,
or project-specific markers.

## Impact and Tradeoffs

Device-motion mitigation has high compatibility risk. Sensor-heavy apps may
break, degrade UX, or detect tampering if motion values are frozen or
incoherent. Even ordinary apps can use motion for parallax, orientation,
accessibility interactions, camera stabilization, or fraud checks.

Quantization and light noise have lower user-visible impact than fixed
synthetic values, but they are weaker privacy controls. Strict low-motion
profiles reduce fingerprinting more aggressively, but they should be applied
only to apps that do not need real sensors.

Partial coverage is the main detection risk. A hook that changes only
accelerometer values while gravity, attitude, screen orientation, and camera/AR
state remain real creates a strong synthetic marker.

## Relevance

Device Motion is relevant for v1 planning because it is a permission-free live
sensor surface with high correlation value. It is not the first static identity
surface to implement, but it should stay visible in the plan because trackers
can use it to recover behavioral, environmental, and hardware-bias signals even
when conventional identifiers are hidden.

Default behavior should be compatibility-first pass-through. Strict profiles
can add coherent low-motion or quantized streams later, but only as a linked
sensor model rather than independent per-axis randomization.
