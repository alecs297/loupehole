# `location.core_location`

This option coarsens `CLLocation` property reads and reports reduced accuracy authorization. It is not a full synthetic location service.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `location.core_location` |
| Implemented mitigation | `location.core_location.foundation.coarse` |
| Policy seeds | `location_coordinate_grid`, `location_motion_context` |
| Status | Experimental |
| Surface | Location |
| Affected APIs | `CLLocation.coordinate`, `altitude`, `horizontalAccuracy`, `verticalAccuracy`, `floor`, `speed`, `course`, `CLLocationManager.accuracyAuthorization` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | Location authorization is required for the location objects that expose these properties; accuracy authorization is a passive privacy-state read |

## Surface And Relevance

Precise coordinates, altitude, floor, speed, course, and accuracy reveal physical location and movement. Even a single high-precision sample can identify home, work, travel, or sensitive visits.

## Mitigation Strategy

The module hooks `CLLocation` getters and reduces precision:

- coordinates are snapped to a coarse latitude/longitude grid;
- horizontal accuracy is reported at no better than broad approximate-location scale;
- vertical accuracy and altitude are rounded;
- indoor floor is hidden by returning `nil`;
- speed and course are rounded, with near-stationary speed normalized to `0`;
- `CLLocationManager.accuracyAuthorization` reports reduced accuracy.

Authorization status, prompts, delegate callbacks, errors, timestamps, and manager lifecycle behavior pass through.

## Derivation And Lifetime

`location_coordinate_grid` selects scoped grid phases for coordinate, altitude, and accuracy buckets. `location_motion_context` selects scoped bucket phases for speed and course. There is no persisted location state or synthetic route.

## Impact And Gaps

This module can break maps, routing, delivery, rideshare, weather alerts, local search, fitness, emergency, and location-sharing features. It does not block location collection; it reduces precision when apps read covered properties.

The module does not cover authorization status, request callbacks, significant-change APIs, visits, geofencing, timestamp, source information, heading, region monitoring, IP geolocation, or server-side comparisons. It also does not model movement over time.

## Validation

Expected observations after integration:

- `CLLocation` coordinates are coarse rather than meter-level;
- full/reduced accuracy reads report reduced accuracy;
- floor is absent;
- speed and course values are broad.

## Rollback And Pass-Through

If `CLLocation`, `CLLocationManager`, or all selected selectors are unavailable, the module registers as no-op. Invalid coordinates, negative unavailable accuracy, speed, or course values retain their native unavailable shape.
