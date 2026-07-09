# `location.core_location`

This option applies continuous seed-derived perturbations to `CLLocation` property reads and reports reduced accuracy authorization. It is not a full synthetic location service.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `location.core_location` |
| Implemented mitigation | `location.core_location.foundation.seeded_jitter` |
| Policy seeds | `location_coordinate_grid`, `location_motion_context` |
| Status | Experimental |
| Surface | Location |
| Affected APIs | `CLLocation.coordinate`, `altitude`, `horizontalAccuracy`, `verticalAccuracy`, `floor`, `speed`, `course`, `CLLocationManager.accuracyAuthorization` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | Location authorization is required for the location objects that expose these properties; accuracy authorization is a passive privacy-state read |

## Surface And Relevance

Precise coordinates, altitude, floor, speed, course, and accuracy reveal physical location and movement. Even a single high-precision sample can identify home, work, travel, or sensitive visits.

## Mitigation Strategy

The module hooks `CLLocation` getters and maps original numeric values through small deterministic sine perturbations:

- coordinates receive bounded latitude/longitude perturbations and are clamped or wrapped into valid ranges;
- horizontal accuracy is reported at no better than approximate-location scale;
- vertical accuracy keeps a non-precise minimum;
- altitude, speed, and course are shaped from the original values;
- indoor floor is hidden by returning `nil`;
- `CLLocationManager.accuracyAuthorization` reports reduced accuracy.

Authorization status, prompts, delegate callbacks, errors, timestamps, and manager lifecycle behavior pass through.

## Derivation And Lifetime

`location_coordinate_grid` selects scoped perturbation profiles for coordinate, altitude, and accuracy fields. `location_motion_context` selects scoped perturbation profiles for speed and course. There is no persisted location state or synthetic route.

## Impact And Gaps

This module can break maps, routing, delivery, rideshare, weather alerts, local search, fitness, emergency, and location-sharing features. It does not block location collection; it reduces precision when apps read covered properties.

The module does not cover authorization status, request callbacks, significant-change APIs, visits, geofencing, timestamp, source information, heading, region monitoring, IP geolocation, or server-side comparisons. It also does not model movement over time.

## Validation

Expected observations after integration:

- `CLLocation` coordinates are seed-shaped rather than meter-level exact values;
- full/reduced accuracy reads report reduced accuracy;
- floor is absent;
- speed and course values are smoothly perturbed.

## Rollback And Pass-Through

If `CLLocation`, `CLLocationManager`, or all selected selectors are unavailable, the module registers as no-op. Invalid coordinates, negative unavailable accuracy, speed, or course values retain their native unavailable shape.
