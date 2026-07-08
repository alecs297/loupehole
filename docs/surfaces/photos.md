# Photos

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/PhotosProvider.swift`

Loupe category: Photos
Loupe tier: active permissioned photo-library inventory, with optional external
reverse-geocoding of geotag clusters after additional app-level consent
Permission required: Photos read/write authorization for Loupe's library reads;
place-name lookup additionally depends on Loupe's `photosGeocoding` consent
toggle
Primary relevance: library size, media mix, album topology, geotagged-photo
location history, cloud/shared album state, and sensitive personal media
metadata.

Loupe's Photos provider counts accessible assets and collections, scans photo
and video geotags, and optionally turns clustered coordinates into place names
using Apple's geocoding service. It does not request image pixels or
full-resolution media data, but the metadata alone is high privacy impact.

## Official Links

- [`PHPhotoLibrary`](https://developer.apple.com/documentation/photos/phphotolibrary)
- [`PHPhotoLibrary.authorizationStatus(for:)`](https://developer.apple.com/documentation/photos/phphotolibrary/authorizationstatus%28for%3A%29)
- [`PHPhotoLibrary.requestAuthorization(for:handler:)`](https://developer.apple.com/documentation/photos/phphotolibrary/requestauthorization%28for%3Ahandler%3A%29)
- [`PHAuthorizationStatus`](https://developer.apple.com/documentation/photos/phauthorizationstatus)
- [`PHAuthorizationStatus.limited`](https://developer.apple.com/documentation/photos/phauthorizationstatus/limited)
- [`PHAccessLevel`](https://developer.apple.com/documentation/photos/phaccesslevel)
- [`PHAccessLevel.readWrite`](https://developer.apple.com/documentation/photos/phaccesslevel/readwrite)
- [`PHAsset`](https://developer.apple.com/documentation/photos/phasset)
- [`PHAsset.fetchAssets(with:options:)`](https://developer.apple.com/documentation/photos/phasset/fetchassets%28with%3Aoptions%3A%29)
- [`PHAsset.fetchAssets(with:)`](https://developer.apple.com/documentation/photos/phasset/fetchassets%28with%3A%29)
- [`PHAsset.mediaType`](https://developer.apple.com/documentation/photos/phasset/mediatype)
- [`PHAsset.location`](https://developer.apple.com/documentation/photos/phasset/location)
- [`PHAsset.creationDate`](https://developer.apple.com/documentation/photos/phasset/creationdate)
- [`PHFetchOptions`](https://developer.apple.com/documentation/photos/phfetchoptions)
- [`PHAssetCollection`](https://developer.apple.com/documentation/photos/phassetcollection)
- [`PHAssetCollection.fetchAssetCollections(with:subtype:options:)`](https://developer.apple.com/documentation/photos/phassetcollection/fetchassetcollections%28with%3Asubtype%3Aoptions%3A%29)
- [`PHAssetCollectionType`](https://developer.apple.com/documentation/photos/phassetcollectiontype)
- [`PHAssetCollectionSubtype.albumRegular`](https://developer.apple.com/documentation/photos/phassetcollectionsubtype/albumregular)
- [`PHAssetCollectionSubtype.albumCloudShared`](https://developer.apple.com/documentation/photos/phassetcollectionsubtype/albumcloudshared)
- [`CLGeocoder.reverseGeocodeLocation(_:completionHandler:)`](https://developer.apple.com/documentation/corelocation/clgeocoder/reversegeocodelocation%28_%3Acompletionhandler%3A%29)
- [`CLPlacemark`](https://developer.apple.com/documentation/corelocation/clplacemark)
- [`NSPhotoLibraryUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryusagedescription)
- [`NSPhotoLibraryAddUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryaddusagedescription)

## Loupe Signals

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `geotaggedCount` | `PHAsset.fetchAssets(with: options:)`, then count assets whose `PHAsset.location` is non-nil | Photos read/write authorization | Active permissioned library metadata scan | Include | High. The number of geotagged photos/videos reveals device and camera habits, travel behavior, and metadata-retention posture. |
| `recentLocations` | Most recent distinct geotag grid cells from assets sorted by `creationDate`, optionally reverse-geocoded | Photos authorization; Apple geocoding only after Loupe app-level consent | Active permissioned library scan; optional active external lookup | Include | Very high when place names appear. Recent places can reveal home, travel, workplace, medical visits, events, or routines. |
| `frequentLocations` | Most frequent geotag grid cells across accessible assets, optionally reverse-geocoded and counted | Photos authorization; Apple geocoding only after Loupe app-level consent | Active permissioned library scan; optional active external lookup | Include | Very high. Frequent places summarize long-term location history and can reveal home/work clusters. |
| `imageCount` | `PHAsset.fetchAssets(with: .image, options: nil).count` | Photos read/write authorization | Active permissioned library inventory | Include | Medium to high. Library size is stable, personal, and useful when joined with video, audio, album, and geotag counts. |
| `videoCount` | `PHAsset.fetchAssets(with: .video, options: nil).count` | Photos read/write authorization | Active permissioned library inventory | Include | Medium. Video count reveals capture habits and media-library shape. |
| `audioCount` | `PHAsset.fetchAssets(with: .audio, options: nil).count` | Photos read/write authorization | Active permissioned library inventory | Include | Low to medium. Usually small, but unusual audio assets can narrow the cohort. |
| `userAlbumCount` | `PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil).count` | Photos read/write authorization | Active permissioned collection inventory | Include | Medium. User-created album count reveals organization habits and library maturity. |
| `smartAlbumCount` | `PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil).count` | Photos read/write authorization | Active permissioned collection inventory | Include | Low to medium. Mostly system-shaped, but availability and count can vary with OS/library features. |
| `sharedAlbumCount` | `PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: nil).count` | Photos read/write authorization | Active permissioned collection inventory | Include | Medium to high. Shared iCloud albums reveal cloud/social use and may be rare in some app populations. |

Loupe clusters geotags by rounding latitude and longitude to a roughly 1 km
grid, then considers the ten most recent and ten most frequent clusters. If the
`photosGeocoding` consent toggle is off, Loupe still reports the geotag count
but shows recent/frequent place names as `(not looked up)` when geotags exist.

## Permission and Activity Classification

Photos is active and permissioned. Loupe's permission center checks
`PHPhotoLibrary.authorizationStatus(for: .readWrite)` and requests
`PHPhotoLibrary.requestAuthorization(for: .readWrite)` when the status is
`notDetermined`. The upstream Info.plist uses `NSPhotoLibraryUsageDescription`.

Limited Photos access matters. If the user grants limited library access, asset
and collection results are constrained to the app-visible subset. That limited
selection is itself a privacy state and can make counts look much smaller than
the full library.

Loupe does not read pixel buffers, thumbnails, originals, edited image data, or
full-resolution video data. Its collection is still sensitive because library
metadata, counts, album counts, creation ordering, and embedded geotags can be
personal enough to identify or profile a user.

The geotag scan is active local enumeration of permissioned library metadata.
The optional place-name lookup is active external collection: Loupe sends
representative coordinates to Apple's geocoding service only after the
additional `CollectionConsent.photosGeocoding` toggle is enabled. This does not
require Location permission because the coordinates come from photo metadata,
not the device's current location.

No Contacts, Camera, Microphone, Bluetooth, Local Network, Calendar, Reminders,
or Music permission is required for Loupe's Photos provider. Camera permission
would be relevant to capture, not to this library metadata inventory.

## Fingerprinting Value

The highest-value Photos signals are recent and frequent geotag summaries. A
photo library can preserve months or years of location history. Even when Loupe
rounds to about 1 km cells, place clusters can reveal home, work, school,
travel, family locations, holidays, medical facilities, religious sites, or
political events.

Geotagged count is a strong metadata-retention signal. Some users have almost
no geotagged assets, while others have thousands. The count can reveal whether
the user takes many photos with location enabled, imports camera media, strips
metadata, travels often, or has used the same library for many years.

Asset counts are useful because they are stable and personal. Exact image,
video, and audio counts can link sessions after reinstall or across apps with
Photos permission. They also correlate with storage usage, device age, iCloud
Photos use, backup behavior, and media habits.

Album counts reveal organization and cloud-sharing behavior. User albums and
shared albums can be distinctive. Shared albums also expose that the user uses
iCloud sharing, participates in shared libraries or albums, or has a social
photo workflow.

Limited-library state can become a fingerprint too. A user who grants only a
small curated set may produce unusual low counts and stable geotag summaries
that identify the chosen subset rather than the full library.

## Mitigation Strategy Ideas

### `photos.authorization-state`

Cover Photos authorization and limited-library state as policy-visible context:

- `PHPhotoLibrary.authorizationStatus(for:)`
- `PHPhotoLibrary.requestAuthorization(for:)`
- limited-library picker and change notifications where practical
- fetch behavior for denied, limited, add-only, and read/write states

Compatibility default should pass through. Photo editors, galleries, importers,
backup tools, social apps, document scanners, messaging apps, and camera apps
often need the real authorization state and real fetch results.

Strict mode can prefer denied or limited access for apps that do not genuinely
need the library. If the app is already authorized, a hook that only rewrites
the status without constraining fetch results is incoherent. The app-visible
authorization status and returned assets must agree.

### `photos.asset-counts`

Hook asset fetches and count surfaces together:

- `PHAsset.fetchAssets(with:options:)`
- `PHAsset.fetchAssets(with:)`
- `PHFetchResult.count`
- media-type predicates and fetch options that can reveal the same counts

Compatibility default should pass through. Strict mode can bucket counts or
return a small limited-library-style subset, but only if the returned fetch
results, pagination, collection membership, and later per-asset reads are
consistent with those counts.

Avoid seed-derived exact counts. A stable fake count tuple such as
`4317 images, 286 videos, 2 audio assets` can become a new identifier. Coarse
bins or explicit empty/limited states are safer.

### `photos.geotag-summary`

Cover photo-location metadata as a group:

- `PHAsset.location`
- creation-date ordering used to infer recent places
- reverse-geocoding requests made from photo coordinates
- any derived recent/frequent place labels exposed by a target app

Compatibility default should pass through for maps, memories, search, travel,
photo organization, backup, and apps where location metadata is a user-visible
feature.

Strict mode should remove location metadata or reduce it to broad, coherent
regions. Returning synthetic exact places is risky: place names must agree with
coordinates, photo dates, timezone, locale, current location profile, map
behavior, and any visible media content.

If reverse geocoding is allowed, synthetic coordinates may be sent to Apple.
For privacy-first profiles, prefer not looking up place names at all or
returning no geotags rather than sending generated high-cardinality coordinates
to an external service.

### `photos.album-counts`

Hook asset-collection fetches and collection counts:

- `PHAssetCollection.fetchAssetCollections(with:subtype:options:)`
- album, smart-album, and shared-album collection fetch results
- collection membership counts when a target app cross-checks album contents

Default should pass through. Strict mode can normalize to a small common album
shape, but the collection list, localized titles, asset membership, and media
counts must agree. Hiding only shared album count while the shared album
collections remain fetchable is an easy contradiction.

### `photos.geocoding-consent`

Loupe's own `photosGeocoding` consent is not an Apple TCC permission, but it is
important for privacy classification. Any mitigation or test harness that
models Loupe should preserve this distinction:

```text
Photos permission grants local library metadata access
Loupe geocoding consent controls sending photo coordinates to Apple
Location permission is not involved in photo-geotag lookup
```

For protected apps, the analogous mitigation is to block or mediate external
reverse-geocoding of library-derived coordinates, even when local Photos access
is allowed.

## Derivation Considerations

Photos values are a library profile, not independent counters:

```text
authorization state determines accessible scope
accessible asset count determines media-type counts
asset creation dates determine recent geotag ordering
geotag clusters determine recent and frequent place summaries
album counts constrain collection fetch results
shared albums constrain iCloud/social photo state
```

The safest strict values are denied, limited, empty, or coarse buckets. Exact
synthetic library shapes should be avoided unless Loupehole can return
coherent `PHFetchResult` objects, asset identifiers, collection membership,
metadata, and change notifications across all relevant APIs.

Geotags should be generated from a location-history profile if they are
generated at all. They must agree with current-location policy, locale, time
zone, travel timeline, imported photo dates, and any place names returned by
geocoding. Do not derive random place names or coordinates directly from the
seed.

Counts should change slowly. A photo library can grow, but exact counts should
not jump between reads unless the mitigation also models inserts, deletes,
limited-library changes, or iCloud sync events.

Limited-library profiles should remain stable for their documented lifetime.
Rotating the visible subset per launch can look like user action, sync churn,
or a broken Photos authorization state.

Purpose labels and derivation salts should remain internal and seed-bound.
Returned album names, place names, asset identifiers, and geocoding behavior
must not expose readable project names, mitigation names, seeds, or profile IDs.

## Impact and Tradeoffs

Photos mitigation has high functional risk. Apps use real library access for
selection, upload, editing, backup, search, memories, social sharing, scanning,
and attachment workflows. Denying or filtering can break the purpose of a photo
app outright.

Limited-library behavior is often the best privacy-compatible tradeoff because
it uses a platform model users understand. Hook-based strict filtering must be
at least as coherent as the platform's limited-library semantics or apps will
notice mismatched counts, missing assets, stale change notifications, or broken
collection membership.

Geotag hiding improves privacy significantly. The tradeoff is that map views,
photo search, memories, travel albums, location-based sorting, and "nearby"
features may degrade. Returning broad or empty location metadata is usually
safer than returning fake precise histories.

Album-count spoofing can confuse user-visible UI. A gallery that says there are
zero user albums while the user sees albums in a picker or share sheet creates a
trust and detection problem.

Reverse-geocoding is a separate privacy boundary. Even if Photos access is
granted, sending photo-derived coordinates to a server can reveal sensitive
historical places. Loupe's extra consent toggle is the right model to preserve
in documentation and future testing.

## Relevance

Photos is a P0 permissioned fingerprint category because it exposes historical
personal data after a single library authorization. It is not silent, but users
often grant Photos access to social, editing, marketplace, messaging, and
document apps without realizing counts and geotags can become a fingerprint.

The highest-priority surfaces are geotag summaries, image/video counts, and
authorization or limited-library state. Album counts and shared album state are
P1 because they add stable personal-library shape and cloud/social context.

Loupehole should treat Photos as a permissioned inventory profile. Default
behavior should be pass-through or platform limited-library behavior. Strict
profiles can later hide geotags and bucket counts only if fetch results,
metadata, collection lists, authorization state, and optional geocoding all
remain coherent.
