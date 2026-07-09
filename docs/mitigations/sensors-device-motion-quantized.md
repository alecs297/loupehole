# `sensors.device_motion`

This option reduces precision on permission-free Core Motion raw and fused motion values. It is a getter-level mitigation: it does not stop sensor updates or replace the motion timeline.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `sensors.device_motion` |
| Implemented mitigation | `sensors.device_motion.coremotion.quantized` |
| Policy seeds | `device_motion_acceleration`, `device_motion_rotation_rate`, `device_motion_magnetic_field`, `device_motion_attitude`, `device_motion_heading` |
| Status | Experimental |
| Surface | Device Motion |
| Affected APIs | `CMAccelerometerData.acceleration`, `CMGyroData.rotationRate`, `CMMagnetometerData.magneticField`, `CMDeviceMotion.gravity`, `CMDeviceMotion.userAcceleration`, `CMDeviceMotion.rotationRate`, `CMDeviceMotion.magneticField`, `CMDeviceMotion.heading`, `CMAttitude.roll`, `CMAttitude.pitch`, `CMAttitude.yaw` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None for the covered `CMMotionManager` data paths |

## Surface And Relevance

The covered values expose live pose, movement, vibration, magnetic environment, and sensor-bias signals. The mitigation keeps the original motion stream shape but rounds returned values into coarse buckets.

## Mitigation Strategy

The module hooks Core Motion data-object getters and returns quantized versions of the original values:

- acceleration and rotation-rate vectors are rounded to coarse per-axis buckets;
- raw and calibrated magnetic fields are rounded to larger magnetic-field buckets;
- attitude roll and pitch are rounded to 5-degree buckets, and yaw plus heading to wider buckets;
- unavailable classes or selectors register the module as a no-op.

The hook does not synthesize a stationary profile and does not alter `CMMotionManager` start/stop/update-interval methods. This makes the first implementation less invasive but weaker than a full low-motion timeline.

## Derivation And Lifetime

The policy seeds select a small scoped bucket phase for each semantic stream. Returned values are still based on the original sensor reading, so they change as the device moves. There is no mitigation-owned state blob.

| Seed | Meaning |
| --- | --- |
| `device_motion_acceleration` | Bucket phase for raw acceleration, gravity, and user acceleration. |
| `device_motion_rotation_rate` | Bucket phase for raw and fused rotation rate. |
| `device_motion_magnetic_field` | Bucket phase for raw and calibrated magnetic field vectors. |
| `device_motion_attitude` | Bucket phase for roll, pitch, and yaw. |
| `device_motion_heading` | Bucket phase for heading. |

Rotation occurs when the active seed, scope, or policy seed identifiers change.

## Impact And Gaps

Quantization preserves more compatibility than a frozen synthetic profile, but it does not remove all behavioral or hardware-bias information. Apps can still observe update timing, timestamps, availability, manager lifecycle behavior, and broad movement.

The module does not cover ARKit, camera stabilization, screen orientation, compass APIs outside `CMDeviceMotion.heading`, or a coherent synthetic motion model.

## Validation

Expected observations after catalog integration and generation:

- covered getters return bucketed values rather than full precision;
- unavailable Core Motion classes register no-op rather than failing startup;
- motion-dependent apps still receive changing values, not a per-call random stream.

## Rollback And Pass-Through

If a selector is unavailable, that hook is skipped. If no selectors install, the module registers as no-op. If an original implementation pointer is unavailable inside a replacement, the replacement returns the native zero/unknown-shaped value for that getter rather than inventing a second fallback.
