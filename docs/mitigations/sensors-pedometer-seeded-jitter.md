# `sensors.pedometer`

This option applies continuous seed-derived perturbations to Core Motion pedometer fields while preserving the original query/update delivery path.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `sensors.pedometer` |
| Implemented mitigation | `sensors.pedometer.coremotion.seeded_jitter` |
| Policy seeds | `motion_pedometer_steps`, `motion_pedometer_distance`, `motion_pedometer_floors`, `motion_pedometer_pace` |
| Status | Experimental |
| Surface | Motion & Sensors |
| Affected APIs | `CMPedometerData.numberOfSteps`, `distance`, `floorsAscended`, `floorsDescended`, `currentPace`, `currentCadence`, `averageActivePace` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | Motion & Fitness authorization is required by pedometer query/update paths |

## Surface And Relevance

Pedometer totals and pace fields reveal behavior over the current day. Exact steps, distance, floors, pace, cadence, and average pace can link sessions and describe commute, exercise, or inactivity patterns.

## Mitigation Strategy

The module hooks `CMPedometerData` getters and maps original numeric values through small deterministic sine perturbations. The perturbation profile is derived from the active build seed, app scope, policy seed, and a field context. This avoids fixed bucket edges while keeping nearby inputs nearby outputs.

Nil and unavailable values remain nil. Negative unavailable values pass through. Step and floor outputs remain integral and nonnegative.

## Derivation And Lifetime

The policy seeds select the per-field perturbation profiles:

| Seed | Meaning |
| --- | --- |
| `motion_pedometer_steps` | Seeded shaping for step count. |
| `motion_pedometer_distance` | Seeded shaping for distance. |
| `motion_pedometer_floors` | Seeded shaping for floors up/down. |
| `motion_pedometer_pace` | Seeded shaping for pace, cadence, and average active pace. |

There is no mitigation-owned state blob. Values still come from original pedometer data, so day-boundary behavior and callback cadence remain framework-owned.

## Impact And Gaps

Seeded perturbation is less detectable than coarse rounding, but it still affects apps that need precise fitness metrics. It does not hide availability, authorization, query time ranges, start/end dates, or callback cadence.

The module does not guarantee a full daily activity model and does not tie step changes to raw motion or location movement.

## Validation

Expected observations after integration:

- covered numeric getters return continuous seed-shaped values rather than fixed buckets;
- nil properties remain nil;
- query and update handlers still run through Core Motion.

## Rollback And Pass-Through

If `CMPedometerData` or all selected getters are unavailable, the module registers as no-op. If an original getter returns nil or a negative unavailable value, the replacement preserves that shape.
