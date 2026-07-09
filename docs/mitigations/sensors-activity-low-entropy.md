# `sensors.activity`

This option lowers the entropy of Core Motion activity classification values exposed through `CMMotionActivity`.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `sensors.activity` |
| Implemented mitigation | `sensors.activity.coremotion.low_entropy` |
| Policy seeds | `motion_activity_profile` |
| Status | Experimental |
| Surface | Motion & Sensors |
| Affected APIs | `CMMotionActivity.unknown`, `stationary`, `walking`, `running`, `automotive`, `cycling`, `confidence` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | Motion & Fitness authorization is required by the manager/query paths that create these objects |

## Surface And Relevance

Activity labels reveal whether the user appears stationary, walking, running, cycling, or automotive. They are low-cardinality values, but they become identifying when joined with time, location, pedometer, altitude, and app behavior.

## Mitigation Strategy

The module hooks `CMMotionActivity` property getters. It returns one scoped low-entropy profile:

- most scopes report stationary with low confidence;
- a small scoped cohort reports unknown with low confidence;
- walking, running, automotive, and cycling return `NO`.

The mitigation does not intercept `CMMotionActivityManager` query or update callbacks. It changes the activity object after delivery.

## Derivation And Lifetime

`LH_POLICY_SEED(motion_activity_profile)` selects the scoped activity profile using `LHMitigationDeriveBoundedU64`. There is no state blob; the chosen profile is stable until seed, scope, or policy seed changes.

## Impact And Gaps

This is a strict privacy-oriented behavior and can break fitness, navigation, safety, journaling, accessibility, and trip-detection features. It can also conflict with raw motion, pedometer, location, or visible user movement because this worker slice does not own a full motion timeline.

Manager availability, authorization state, query timing, update lifecycle, and historical activity arrays remain outside this module.

## Validation

Expected observations after integration:

- activity boolean getters collapse to stationary or unknown;
- confidence reports low;
- manager-level authorization and callback delivery still follow the original framework behavior.

## Rollback And Pass-Through

If `CMMotionActivity` or all selectors are unavailable, the module registers as no-op. The replacement values are native boolean/enum shapes and do not expose project markers.
