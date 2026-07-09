# `power.low_power_mode`

The Low Power Mode option normalizes `NSProcessInfo` Low Power Mode reads to the common disabled value.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `power.low_power_mode` |
| Implemented mitigation | `power.low_power_mode.processinfo.normalized_false` |
| Policy seeds | None; this mitigation returns a shared policy constant. |
| User-facing name | Low Power Mode |
| Status | Experimental |
| Surface | Battery and power |
| Classification | Passive low-cardinality power-state surface; active Objective-C hook mitigation |
| Affected APIs | `NSProcessInfo.isLowPowerModeEnabled` |
| Default behavior | Active when selected and allowed by runtime policy |
| Permission requirement | None |

## Surface And Relevance

Low Power Mode is a boolean, but the enabled state can be rarer and can correlate with battery level, background policy, timer behavior, and performance.

## Mitigation Strategy

The mitigation hooks `-[NSProcessInfo isLowPowerModeEnabled]` and returns `NO`. It does not hook `NSProcessInfoPowerStateDidChangeNotification`, background execution behavior, timer behavior, battery level, or real system scheduling policy.

## Derivation And Lifetime

No policy seed or state blob is used. The value is the shared low-entropy disabled state.

## Impact And Tradeoffs

This can make apps perform too much work on a device where Low Power Mode is genuinely enabled, and the underlying OS may still reveal constrained behavior through timing or background execution. Apps that use Low Power Mode for resource conservation may need this module disabled.

## Validation

Repository-level validation is pending until catalog integration. Expected observation: `NSProcessInfo.processInfo.isLowPowerModeEnabled` reports false while the module is enabled.

## Rollback And Pass-Through

If `NSProcessInfo` or the selector is unavailable, the module registers as a no-op. Disabling the module restores the original Low Power Mode value.
