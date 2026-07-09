# `sensors.pedometer`

This option rounds Core Motion pedometer fields to reduce exact daily activity leakage while preserving the original query/update delivery path.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `sensors.pedometer` |
| Implemented mitigation | `sensors.pedometer.coremotion.quantized` |
| Policy seeds | `motion_pedometer_steps`, `motion_pedometer_distance`, `motion_pedometer_floors`, `motion_pedometer_pace` |
| Status | Experimental |
| Surface | Motion & Sensors |
| Affected APIs | `CMPedometerData.numberOfSteps`, `distance`, `floorsAscended`, `floorsDescended`, `currentPace`, `currentCadence`, `averageActivePace` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | Motion & Fitness authorization is required by pedometer query/update paths |

## Surface And Relevance

Pedometer totals and pace fields reveal behavior over the current day. Exact steps, distance, floors, pace, cadence, and average pace can link sessions and describe commute, exercise, or inactivity patterns.

## Mitigation Strategy

The module hooks `CMPedometerData` getters and rounds original values:

- steps are rounded to coarse 250-step buckets;
- distance is rounded to coarse 100-meter buckets;
- floors ascended and descended are rounded to coarse floor buckets;
- pace, cadence, and average active pace are rounded to broader movement buckets.

Nil and unavailable values remain nil. The mitigation does not create a synthetic daily model or alter `CMPedometer` query/update callbacks.

## Derivation And Lifetime

The policy seeds select small scoped bucket phases for each semantic field. Values still come from the original pedometer data, so monotonicity and day-boundary behavior mostly remain framework-owned.

| Seed | Meaning |
| --- | --- |
| `motion_pedometer_steps` | Bucket phase for step count. |
| `motion_pedometer_distance` | Bucket phase for distance. |
| `motion_pedometer_floors` | Bucket phase for floors up/down. |
| `motion_pedometer_pace` | Bucket phase for pace, cadence, and average active pace. |

There is no mitigation-owned state blob.

## Impact And Gaps

Quantization is less disruptive than replacing activity history, but it still affects apps that need precise fitness metrics. It does not hide availability, authorization, query time ranges, start/end dates, or callback cadence.

The module does not yet guarantee cross-app daily consistency beyond the shared active seed and scope, and it does not tie step changes to raw motion or location movement.

## Validation

Expected observations after integration:

- covered numeric getters return rounded values;
- nil properties remain nil;
- query and update handlers still run through Core Motion.

## Rollback And Pass-Through

If `CMPedometerData` or all selected getters are unavailable, the module registers as no-op. If an original getter returns nil or a negative unavailable value, the replacement preserves that shape.
