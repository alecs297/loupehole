# `power.thermal_state`

The thermal-state option collapses low-severity thermal readings while preserving serious and critical states.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `power.thermal_state` |
| Implemented mitigation | `power.thermal_state.processinfo.nominalized` |
| Policy seeds | None; this mitigation maps platform states to shared buckets. |
| User-facing name | Thermal state |
| Status | Experimental |
| Surface | Battery and power |
| Classification | Passive low-cardinality power and performance surface; active Objective-C hook mitigation |
| Affected APIs | `NSProcessInfo.thermalState` |
| Default behavior | Active when selected and allowed by runtime policy |
| Permission requirement | None |

## Surface And Relevance

Thermal state can reveal workload, charging, ambient conditions, throttling, and performance context. Higher states are operationally meaningful and should not be hidden casually.

## Mitigation Strategy

The mitigation hooks `-[NSProcessInfo thermalState]`. `nominal` and `fair` report as `nominal`; `serious` and `critical` pass through unchanged. This reduces low-severity entropy without hiding states where apps should reduce expensive work.

It does not hook thermal notifications, performance counters, timer behavior, GPU/CPU throttling, battery state, or app workload signals.

## Derivation And Lifetime

No policy seed or state blob is used. The value follows the real thermal state through a low-entropy bucket.

## Impact And Tradeoffs

Apps may miss a `fair` state and keep full-quality behavior longer than they otherwise would. Serious and critical states pass through to preserve safety and compatibility.

## Validation

Repository-level validation is pending until catalog integration. Expected observations:

- `nominal` and `fair` report as nominal.
- `serious` and `critical` preserve their original values.

## Rollback And Pass-Through

If `NSProcessInfo` or the selector is unavailable, the module registers as a no-op. Disabling the module restores original thermal-state reads.
