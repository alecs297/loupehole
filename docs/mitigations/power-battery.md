# `power.battery`

The battery option reduces charge-level precision while preserving the platform battery state.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `power.battery` |
| Implemented mitigation | `power.battery.uidevice.bucketed_level` |
| Policy seeds | None; this mitigation rounds the real level and passes through state. |
| User-facing name | Battery level |
| Status | Experimental |
| Surface | Battery and power |
| Classification | Passive local power-state surface; active Objective-C hook mitigation |
| Affected APIs | `UIDevice.batteryLevel`, `UIDevice.batteryState` |
| Default behavior | Active when selected and allowed by runtime policy |
| Permission requirement | None |

## Surface And Relevance

Battery level changes slowly enough to link nearby launches. Battery state provides context for whether the level should rise, fall, stay full, or be unknown.

## Mitigation Strategy

The mitigation hooks `UIDevice.batteryLevel` and rounds valid values in `[0.0, 1.0]` to tenths. It also hooks `batteryState` as part of the same surface but returns the original state so level and state remain platform-coherent.

It does not spoof battery monitoring enablement, battery notifications, charging direction, Low Power Mode, thermal state, or performance behavior.

## Derivation And Lifetime

No policy seed or state blob is used. The level follows the real battery level through a deterministic bucket function. The original `-1.0` unknown value and invalid values pass through unchanged.

## Impact And Tradeoffs

Rounding reduces short-session entropy while preserving broad battery behavior. Apps that show precise battery percentages or compare property reads with notifications may still observe the real notification cadence or see rounded display values.

## Validation

Repository-level validation is pending until catalog integration. Expected observations:

- `UIDevice.batteryLevel` returns tenths when monitoring exposes a valid level.
- Unknown level remains unknown.
- `UIDevice.batteryState` preserves original platform behavior.

## Rollback And Pass-Through

If `UIDevice` or the selectors are unavailable, the module registers as a no-op. Disabling the module restores original battery reads.
