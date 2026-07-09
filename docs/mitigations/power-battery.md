# `power.battery`

The battery option maps the real charge level through a scoped smooth curve, reducing direct level correlation while preserving live battery movement and the platform battery state.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `power.battery` |
| Implemented mitigation | `power.battery.uidevice.curved_level` |
| Policy seeds | `battery_level_curve` |
| User-facing name | Battery level |
| Status | Experimental |
| Surface | Battery and power |
| Classification | Passive local power-state surface; active Objective-C hook mitigation |
| Affected APIs | `UIDevice.batteryLevel`, `UIDevice.batteryState` |
| Default behavior | Active when selected and allowed by runtime policy |
| Permission requirement | None |

## Surface And Relevance

Battery level changes slowly enough to link nearby launches. A direct rounded bucket reduces precision but can produce obvious stair-step behavior. Battery state provides context for whether the level should rise, fall, stay full, or be unknown.

## Mitigation Strategy

The mitigation hooks `UIDevice.batteryLevel` and maps valid values in `[0.0, 1.0]` through a scoped nonlinear transfer curve selected from a small finite family by `LH_POLICY_SEED(battery_level_curve)`. The curve is applied to the real level, keeps `0.0` and `1.0` anchored, stays monotonic for the selected parameter bounds, and rounds the result to two decimals. This preserves gradual live movement while avoiding a 1:1 copy of the exact battery percentage.

It also hooks `batteryState` as part of the same surface but returns the original state so level and state remain platform-coherent. Unknown level (`-1.0`), invalid values, and derivation failures pass through unchanged.

It does not spoof battery monitoring enablement, battery notifications, charging direction, Low Power Mode, thermal state, or performance behavior.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifier | `battery_level_curve` |
| Generated seed symbol | `LHGeneratedPolicySeed_battery_level_curve` |
| Helper | `LHMitigationDeriveBoundedU64` selects one of 48 curve profiles |
| Value shape | `float` in `[0.0, 1.0]`, rounded to two decimals |
| Derivation input | active/practical seed + generated policy seed + active `LHScope` |
| Storage behavior | No mitigation-owned state blob |
| Lifetime | Curve selection is stable until active seed, scope, or policy seed changes; returned level still follows real battery movement |

## Impact And Tradeoffs

The curved value is less visually static than a coarse bucket and less directly linkable than the raw level. It is still tied to real battery movement, so nearby sessions can remain correlated. Apps that show precise battery percentages or compare property reads with notifications may still observe notification cadence, charging behavior, Low Power Mode behavior, and other unmodified power-state effects.

## Validation

Repository-level validation is pending until catalog integration. Expected observations:

- `UIDevice.batteryLevel` returns a stable two-decimal curved value when monitoring exposes a valid level.
- Nearby original levels produce nearby reported levels rather than a fixed or per-read random value.
- Unknown level remains unknown.
- `UIDevice.batteryState` preserves original platform behavior.

## Rollback And Pass-Through

If `UIDevice` or the selectors are unavailable, the module registers as a no-op. Disabling the module restores original battery reads.
