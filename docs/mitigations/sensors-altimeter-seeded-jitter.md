# `sensors.altimeter`

This option applies continuous seed-derived perturbations to Core Motion altimeter pressure and altitude values.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `sensors.altimeter` |
| Implemented mitigation | `sensors.altimeter.coremotion.seeded_jitter` |
| Policy seeds | `motion_altimeter_pressure`, `motion_altimeter_altitude` |
| Status | Experimental |
| Surface | Motion & Sensors |
| Affected APIs | `CMAltitudeData.relativeAltitude`, `CMAltitudeData.pressure`, `CMAbsoluteAltitudeData.altitude`, `accuracy`, `precision` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | Motion & Fitness authorization is required by the update paths that create these objects |

## Surface And Relevance

Pressure, relative altitude, absolute altitude, accuracy, and precision expose local environment, weather, building context, stairs/elevators, and place-like clues without using GPS.

## Mitigation Strategy

The module hooks Core Motion altimeter data getters and maps original values through seed-derived sine perturbations:

- pressure, relative altitude, and absolute altitude remain continuous;
- accuracy and precision are perturbed and then clamped to non-precise minimums when originally valid;
- nil and negative unavailable semantics are preserved.

## Derivation And Lifetime

`motion_altimeter_pressure` and `motion_altimeter_altitude` select scoped perturbation profiles through `LHValueApplySeededSinePerturbation`. No state blob is used; returned values remain derived from live framework data.

## Impact And Gaps

Altitude and pressure precision may matter to hiking, weather, indoor positioning, accessibility, fitness, and safety apps. This module does not suppress availability, manager lifecycle behavior, callback timing, or absolute-altitude support. It also does not connect altitude to a location profile or pedometer floors.

## Validation

Expected observations after integration:

- covered getters return seed-shaped pressure/altitude values instead of fixed buckets;
- unavailable values retain their native nil or negative shape;
- update callbacks still arrive through Core Motion.

## Rollback And Pass-Through

If `CMAltitudeData`, `CMAbsoluteAltitudeData`, or all selected selectors are unavailable, the module registers as no-op. Replacement code preserves native unavailable shapes rather than fabricating unrelated readings.
