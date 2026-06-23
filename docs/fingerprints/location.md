# Location

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/LocationProvider.swift`

Loupe category: Location
Loupe tier: active permissioned location collection, with continuous active
collection in stream mode
Permission required: Location authorization for coordinates and motion-derived
location fields; `authorization` status itself is a passive permission-state
read
Primary relevance: precise physical location, reduced-accuracy privacy state,
movement context, indoor floor hints, and coherence with locale, time zone,
network, photos, and maps-like behavior.

This category is high privacy impact. Loupe asks for When In Use location
authorization through its permission center, then takes a one-shot Core
Location sample in `collect()` or starts continuous updates in `stream()`.
Unlike most passive native surfaces, these values describe the user's current
physical position and behavior.

## Official Links

- [`CLLocationManager`](https://developer.apple.com/documentation/corelocation/cllocationmanager)
- [Requesting authorization to use location services](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)
- [`CLLocationManager.authorizationStatus()`](https://developer.apple.com/documentation/corelocation/cllocationmanager/authorizationstatus%28%29)
- [`CLLocationManager.authorizationStatus`](https://developer.apple.com/documentation/corelocation/cllocationmanager/authorizationstatus-swift.property)
- [`CLLocationManager.requestWhenInUseAuthorization()`](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestwheninuseauthorization%28%29)
- [`CLLocationManager.requestLocation()`](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestlocation%28%29)
- [`CLLocationManager.startUpdatingLocation()`](https://developer.apple.com/documentation/corelocation/cllocationmanager/startupdatinglocation%28%29)
- [`CLLocationManager.desiredAccuracy`](https://developer.apple.com/documentation/corelocation/cllocationmanager/desiredaccuracy)
- [`CLLocationManager.distanceFilter`](https://developer.apple.com/documentation/corelocation/cllocationmanager/distancefilter)
- [`CLLocationManager.accuracyAuthorization`](https://developer.apple.com/documentation/corelocation/cllocationmanager/accuracyauthorization)
- [`CLAccuracyAuthorization`](https://developer.apple.com/documentation/corelocation/claccuracyauthorization)
- [`CLLocation`](https://developer.apple.com/documentation/corelocation/cllocation)
- [`CLLocation.coordinate`](https://developer.apple.com/documentation/corelocation/cllocation/coordinate)
- [`CLLocation.altitude`](https://developer.apple.com/documentation/corelocation/cllocation/altitude)
- [`CLLocation.horizontalAccuracy`](https://developer.apple.com/documentation/corelocation/cllocation/horizontalaccuracy)
- [`CLLocation.verticalAccuracy`](https://developer.apple.com/documentation/corelocation/cllocation/verticalaccuracy)
- [`CLLocation.floor`](https://developer.apple.com/documentation/corelocation/cllocation/floor)
- [`CLLocation.speed`](https://developer.apple.com/documentation/corelocation/cllocation/speed)
- [`CLLocation.course`](https://developer.apple.com/documentation/corelocation/cllocation/course)
- [`NSLocationWhenInUseUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocationwheninuseusagedescription)
- [`NSLocationAlwaysAndWhenInUseUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocationalwaysandwheninuseusagedescription)

## Loupe Signals

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `authorization` | `CLLocationManager.authorizationStatus` rendered as `notDetermined`, `denied`, `restricted`, `authorizedAlways`, or `authorizedWhenInUse` | None to read; prompt only when requesting access | Passive permission-state read | Include | Medium. It reveals whether the user granted, denied, restricted, or has not yet answered location access for this app. |
| `accuracyAuthorization` | `CLLocationManager.accuracyAuthorization` rendered as `full`, `reduced`, or `unknown` | Location authorization state influences meaning | Passive privacy-state read | Include | Medium to high. Reduced accuracy reveals the user's privacy choice; full accuracy enables precise coordinate collection. |
| `coordinate` | `CLLocation.coordinate` from a one-shot `requestLocation()` sample or stream update, formatted to 5 decimals | Location authorization | Active permissioned location sample | Include | Very high. Five decimal places can resolve to roughly meter-level precision and can identify home, work, travel, or sensitive visits. |
| `altitude` | `CLLocation.altitude` | Location authorization | Active permissioned location sample | Include | Medium. It narrows physical environment and must agree with coordinate, floor, vertical accuracy, and terrain. |
| `horizontalAccuracy` | `CLLocation.horizontalAccuracy` | Location authorization | Active permissioned location sample | Include | Medium. It reveals precise vs coarse collection quality and can detect synthetic coordinates that do not match the reported privacy mode. |
| `verticalAccuracy` | `CLLocation.verticalAccuracy` | Location authorization | Active permissioned location sample | Include | Low to medium. It is often unavailable or coarse, but it constrains altitude and indoor/outdoor plausibility. |
| `floor` | `CLLocation.floor?.level` | Location authorization and mapped indoor availability | Active permissioned location sample | Include | High when present. Indoor floor level is sparse and can reveal a mapped building, office, mall, station, hospital, or other sensitive place. |
| `speed` | `CLLocation.speed` | Location authorization | Active permissioned location sample | Include | Medium to high. It reveals walking, driving, stationary, transit-like, or unknown movement state. |
| `course` | `CLLocation.course` | Location authorization | Active permissioned location sample | Include | Medium. Direction of travel is low value alone, but useful with speed, coordinate deltas, heading, map behavior, and stream timing. |

Loupe configures the manager with `kCLLocationAccuracyBest` and
`kCLDistanceFilterNone`. The one-shot sampler returns a cached current location
when available, otherwise calls `requestLocation()` and times out after four
seconds. The stream path calls `startUpdatingLocation()` and yields every
delegate update until stopped.

## Permission and Activity Classification

Location is active and permissioned once Loupe tries to collect coordinates or
movement fields. The permission center requests When In Use authorization with
`requestWhenInUseAuthorization()`, and Loupe's Info.plist contains an
`NSLocationWhenInUseUsageDescription` string for that prompt.

`authorization` is the exception: reading current authorization state is a
passive local permission-state read and does not itself prompt the user.
`accuracyAuthorization` is also a passive local read, but it is only meaningful
as a privacy-state companion to the app's location authorization.

The one-shot `collect()` path is active permissioned sampling. It asks Core
Location for a location fix using best accuracy and no distance filter. The
system may use GPS, Wi-Fi, Bluetooth, cellular, barometer, motion, cached
location, or other platform signals behind the Core Location abstraction.

The `stream()` path is active continuous collection. It starts standard location
updates and can observe movement over time. This increases privacy impact beyond
a single coordinate because a tracker can infer routes, dwell time, commutes,
visits, speed changes, and behavioral schedule.

No separate Photos, Contacts, Bluetooth, Local Network, Motion, or Health
permission is required for Loupe's Location provider. Those domains may still
become coherence constraints when other providers expose related state.

## Fingerprinting Value

Coordinates are among the highest-value fingerprinting signals in the whole
inventory. A precise current location can directly identify a person through
home, work, school, medical, religious, political, nightlife, or travel context.
Even reduced-accuracy location can reveal city, neighborhood, commute region,
or sensitive venue area.

Location is also linkable. Two app sessions from the same uncommon place can be
joined, and repeated samples can form a behavioral route. Stream mode makes this
much stronger because speed, course, coordinate deltas, and timing can reveal
walking, driving, transit, exercise, or stationary patterns.

`accuracyAuthorization` is valuable because it reveals the user's privacy
posture. A user who selects Reduced Accuracy may be distinguishable in some
app populations, and an app can test whether the reported coordinate precision
matches the stated accuracy authorization.

Altitude, vertical accuracy, and floor are smaller fields but strong context
signals. Floor level is especially sensitive when available because it implies
indoor mapped spaces and can distinguish floors inside a building. Altitude can
help distinguish terrain, buildings, flights, bridges, transit, and synthetic
coordinate mistakes.

Authorization status is not physical location, but it is still useful to a
tracker. Denied, restricted, not-determined, always, and when-in-use states tell
an app how privacy-aware the user is and whether future collection is possible.

## Mitigation Strategy Ideas

### `location.authorization-state`

Cover permission-state reads as a policy surface:

- `CLLocationManager.authorizationStatus()`
- instance `CLLocationManager.authorizationStatus`
- delegate authorization-change callbacks
- any framework wrappers that mirror the same authorization state

Compatibility default should pass through. Apps use location authorization to
decide whether to show maps, delivery tracking, navigation, local search,
geofencing, weather, rideshare, reminders, privacy instructions, and settings
deep links.

Strict mode can normalize to denied or not-determined only when the protected
app should not use location at all. Do not report authorized while blocking all
location updates unless delegate errors, prompts, and app-visible behavior also
match that state.

### `location.accuracy-authorization`

Treat precise vs reduced accuracy as part of the location profile, not as a
separate random value. If reported accuracy is `reduced`, the coordinate should
be coarse enough to match. If reported accuracy is `full`, returning a broad
city-level coordinate may look suspicious to apps that expect precise behavior.

Compatibility default should pass through. Strict mode can prefer reduced
accuracy when the app can function with approximate location, but that choice
must be reflected in horizontal accuracy, coordinate precision, map viewport,
and any location prompt copy observed by the app.

### `location.coordinate`

Hook `CLLocationManager` update paths as a group:

- one-shot `requestLocation()` delegate results
- standard location updates
- cached `CLLocationManager.location`
- significant-change and visit-like APIs if future coverage includes them
- authorization and error callbacks that explain missing location

Compatibility default should pass through for navigation, delivery, rideshare,
fitness, emergency, weather alerts, maps, find-my-device, local search, and
apps where the user expects location features to work.

Strict mode can return a stable coarse location profile. Good strict profiles
are low entropy: country/region, broad city, or a common point within a large
area. Avoid seed-derived exact coordinates, unique fake homes, or per-read
random jitter that becomes a new identifier or produces impossible movement.

### `location.altitude-floor`

Altitude, vertical accuracy, and floor should come from the selected coordinate
profile. If the coordinate is coarse or synthetic, the safest floor value is
usually `nil` and the safest altitude is a plausible coarse terrain value with
matching vertical accuracy.

Do not synthesize rare indoor floor levels unless the profile intentionally
models an indoor mapped venue. A floor value without a coordinate near a mapped
building is easy to detect and can be more identifying than no floor.

### `location.motion-context`

Speed and course should be tied to the location timeline. A stationary profile
should use speed `0` or unknown and course unknown. A moving profile should
update coordinates, speed, course, timestamp, and horizontal accuracy together.

Default should pass through for any app using live movement. Strict mode can
normalize to stationary when the protected app only wants a coarse region, but
that must agree with repeated reads and stream updates.

## Derivation Considerations

Location values form a temporal and geographic tuple:

```text
authorization state explains whether updates arrive
accuracy authorization constrains coordinate precision
coordinate determines plausible altitude and floor
coordinate history determines plausible speed and course
time zone, locale, network, photos, weather, and map behavior constrain place
```

Synthetic coordinates should come from a profile-level location domain, not
directly from raw hash output. A deterministic point generated from the seed can
become a stable hidden identifier if it is too precise. Prefer pass-through,
denied, approximate, or population-shaped coarse locations.

If the profile supports movement, store a coherent location timeline. It should
advance at plausible speeds, preserve timestamps, respect horizontal accuracy,
and avoid jumps that would imply impossible travel. Stream updates must match
future property reads and notification behavior.

Location must agree with other surfaces. A Brussels time zone, Belgian locale,
Wi-Fi subnet, recent photo geotags, weather region, map content, and reported
coordinate can disagree in real travel scenarios, but unexplained contradictions
are strong synthetic-profile markers.

Permission state should not rotate per launch. A user granting or denying
location is sticky and app-visible through Settings, prompts, delegate changes,
and feature availability. Rotating authorization status without a real prompt
or settings change is easy to detect.

Purpose labels and derivation salts should remain internal and seed-bound.
Returned coordinates, place names, error messages, and floor labels must not
expose readable project names, mitigation names, seeds, or profile IDs.

## Impact and Tradeoffs

Location mitigation has high compatibility risk because many apps have location
as their core feature. Passing through preserves maps, routing, local search,
weather, delivery, fitness, safety, and location-sharing behavior, but exposes
the most sensitive data in this inventory.

Returning denied or unavailable protects privacy strongly, but it changes app
flows and can disable features. Some apps may block use, repeatedly prompt,
open Settings, degrade content, or treat missing location as risk.

Coarse synthetic location reduces precision but still leaks region and can
create contradictions. Apps may compare the coordinate to IP geolocation,
timezone, locale, map tiles, server-side observations, payment country, cellular
network, photo geotags, or previous sessions.

Speed and course spoofing can be user-visible in navigation, maps, ride,
fitness, delivery, and transit apps. A profile that says the user is stationary
while the map, route, or server-side movement indicates travel is easy to
detect.

Floor and altitude should be conservative. Hiding floor is usually safer than
inventing one. Altitude changes may affect fitness, hiking, skiing, aviation,
accessibility, emergency, or indoor-positioning features, so pass-through is
the compatibility default.

## Relevance

Location is a P0 permissioned fingerprint category. It is not silent like IDFV,
display, locale, or accessibility, but once granted it exposes direct physical
identity and live behavioral context.

The highest-priority surfaces are `coordinate`, authorization state,
accuracy authorization, and live update behavior. Altitude, floor, speed, and
course are secondary as standalone values, but important because they constrain
whether a synthetic location profile looks physically plausible.

Loupehole should default to pass-through or explicit denial for location until
it can provide coherent approximate-location profiles. Strict spoofing must
cover permission reads, one-shot callbacks, stream callbacks, cached locations,
accuracy, movement, and cross-category place coherence together.
