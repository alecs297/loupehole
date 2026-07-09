# `sensors.activity`

This option reduces Core Motion activity confidence without rewriting the activity labels themselves.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `sensors.activity` |
| Implemented mitigation | `sensors.activity.coremotion.confidence_shaped` |
| Policy seeds | `motion_activity_confidence` |
| Status | Experimental |
| Surface | Motion & Sensors |
| Affected APIs | `CMMotionActivity.unknown`, `stationary`, `walking`, `running`, `automotive`, `cycling`, `confidence` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | Motion & Fitness authorization is required by the manager/query paths that create these objects |

## Surface And Relevance

Activity labels reveal whether the user appears stationary, walking, running, cycling, or automotive. They become stronger when joined with time, location, pedometer, altitude, and visible app behavior.

## Mitigation Strategy

The module hooks `CMMotionActivity` property getters. Boolean activity labels pass through from the original object so they stay coherent with nearby pedometer, location, and raw motion streams. `confidence` is downshifted through a seed- and scope-derived finite profile based on the original confidence value:

- original low confidence remains low;
- original medium confidence remains medium for one scoped profile and otherwise becomes low;
- original high confidence becomes medium for one scoped profile and otherwise becomes low.

The mitigation does not intercept `CMMotionActivityManager` query or update callbacks. It changes the activity object after delivery.

## Derivation And Lifetime

`LH_POLICY_SEED(motion_activity_confidence)` selects the scoped confidence downshift profile with `LHMitigationDeriveBoundedU64`. There is no state blob; the profile is stable until seed, scope, or policy seed changes.

## Impact And Gaps

This preserves more app functionality than forcing a synthetic activity state, but it still reduces confidence for fitness, navigation, safety, journaling, accessibility, and trip-detection features.

Manager availability, authorization state, query timing, update lifecycle, historical activity arrays, and full motion timelines remain outside this module.

## Validation

Expected observations after integration:

- activity boolean getters match the original object;
- confidence reports low or medium according to the scoped profile;
- manager-level authorization and callback delivery still follow the original framework behavior.

## Rollback And Pass-Through

If `CMMotionActivity` or all selectors are unavailable, the module registers as no-op. Label getters pass through when an original implementation is available; missing originals fall back to native false/low shapes.
