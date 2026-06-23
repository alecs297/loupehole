# Music Library

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/MusicLibraryProvider.swift`

Loupe category: Music Library
Loupe tier: active permissioned media-library inventory and Apple Music account
capability check
Permission required: Media Library / Apple Music authorization on iOS; provider
is unavailable on macOS in Loupe's current code
Primary relevance: music taste, library size, playlist habits, recent listening
or collection changes, Apple Music subscription capability, and iCloud Music
Library state.

Loupe's Music Library provider counts local media-library items and surfaces
top genres and artists. It does not play audio or inspect audio samples, but
the metadata is personal taste data. The provider is iOS-only; Loupe's macOS
path returns a placeholder saying the category is unavailable.

## Official Links

- [`MPMediaLibrary`](https://developer.apple.com/documentation/mediaplayer/mpmedialibrary)
- [`MPMediaLibrary.authorizationStatus()`](https://developer.apple.com/documentation/mediaplayer/mpmedialibrary/authorizationstatus%28%29)
- [`MPMediaLibrary.requestAuthorization(_:)`](https://developer.apple.com/documentation/mediaplayer/mpmedialibrary/requestauthorization%28_%3A%29)
- [`MPMediaLibraryAuthorizationStatus`](https://developer.apple.com/documentation/mediaplayer/mpmedialibraryauthorizationstatus)
- [`MPMediaQuery`](https://developer.apple.com/documentation/mediaplayer/mpmediaquery)
- [`MPMediaQuery.songs()`](https://developer.apple.com/documentation/mediaplayer/mpmediaquery/songs%28%29)
- [`MPMediaQuery.albums()`](https://developer.apple.com/documentation/mediaplayer/mpmediaquery/albums%28%29)
- [`MPMediaQuery.playlists()`](https://developer.apple.com/documentation/mediaplayer/mpmediaquery/playlists%28%29)
- [`MPMediaQuery.artists()`](https://developer.apple.com/documentation/mediaplayer/mpmediaquery/artists%28%29)
- [`MPMediaQuery.items`](https://developer.apple.com/documentation/mediaplayer/mpmediaquery/items)
- [`MPMediaQuery.collections`](https://developer.apple.com/documentation/mediaplayer/mpmediaquery/collections)
- [`MPMediaItem`](https://developer.apple.com/documentation/mediaplayer/mpmediaitem)
- [`MPMediaItem.genre`](https://developer.apple.com/documentation/mediaplayer/mpmediaitem/genre)
- [`MPMediaItem.artist`](https://developer.apple.com/documentation/mediaplayer/mpmediaitem/artist)
- [`MPMediaItem.dateAdded`](https://developer.apple.com/documentation/mediaplayer/mpmediaitem/dateadded)
- [`MPMediaItem.persistentID`](https://developer.apple.com/documentation/mediaplayer/mpmediaitem/persistentid)
- [`MPMediaItemCollection`](https://developer.apple.com/documentation/mediaplayer/mpmediaitemcollection)
- [`SKCloudServiceController`](https://developer.apple.com/documentation/storekit/skcloudservicecontroller)
- [`SKCloudServiceController.authorizationStatus()`](https://developer.apple.com/documentation/storekit/skcloudservicecontroller/authorizationstatus%28%29)
- [`SKCloudServiceController.requestCapabilities(completionHandler:)`](https://developer.apple.com/documentation/storekit/skcloudservicecontroller/requestcapabilities%28completionhandler%3A%29)
- [`SKCloudServiceCapability`](https://developer.apple.com/documentation/storekit/skcloudservicecapability)
- [Determining a person's Apple Music capabilities](https://developer.apple.com/documentation/storekit/determining-a-person-s-apple-music-capabilities)
- [Requesting access to Apple Music Library](https://developer.apple.com/documentation/storekit/requesting-access-to-apple-music-library)
- [`NSAppleMusicUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapplemusicusagedescription)

## Loupe Signals

| Loupe signal | Provider source | Platforms | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- | --- |
| `songCount` | `MPMediaQuery.songs().items?.count` | iOS | Media Library / Apple Music authorization | Active permissioned media-library inventory | Include | Medium to high. Library size is stable and personal, especially when joined with album, artist, playlist, and recent-added counts. |
| `albumCount` | `MPMediaQuery.albums().collections?.count` | iOS | Media Library / Apple Music authorization | Active permissioned media-library inventory | Include | Medium. Album count reveals collection shape and music-library maturity. |
| `playlistCount` | `MPMediaQuery.playlists().collections?.count` | iOS | Media Library / Apple Music authorization | Active permissioned media-library inventory | Include | High when nonzero or unusual. Playlists reveal organization habits and can be stable across devices. |
| `artistCount` | `MPMediaQuery.artists().collections?.count` | iOS | Media Library / Apple Music authorization | Active permissioned media-library inventory | Include | Medium to high. Distinct artist count narrows library shape and constrains top artist data. |
| `topGenres` | Count songs by `MPMediaItem.genre`, take top three names and counts | iOS | Media Library / Apple Music authorization | Active permissioned taste-profile scan | Include | Very high. Genre taste can reveal age, culture, language, religion, politics, subculture, mood, and niche interests. |
| `topArtists` | Count songs by `MPMediaItem.artist`, take top three names and counts | iOS | Media Library / Apple Music authorization | Active permissioned taste-profile scan | Include | Very high. Top artists are direct taste data and may be rare enough to identify a user in small cohorts. |
| `recentlyAdded` | Count songs whose `MPMediaItem.dateAdded` is within the last 30 days | iOS | Media Library / Apple Music authorization | Active permissioned temporal library scan | Include | Medium. Recent additions reveal current behavior and can link sessions near a release, import, sync, or subscription event. |
| `appleMusic` | `SKCloudServiceController.requestCapabilities`, mapped to catalog playback, subscription eligibility, and iCloud Music Library flags | iOS | Apple Music / media-library authorization and account state | Active permissioned account-capability check | Include | Medium to high. Subscription eligibility, catalog playback, and iCloud Music Library state reveal account and service posture. |
| `unavailable` | macOS fallback signal saying MediaPlayer library APIs are unavailable | macOS | None | Passive placeholder | Exclude | Not a user fingerprint by itself. It is a platform availability marker and should be tracked with platform/profile coherence, not as a Music Library mitigation. |

Loupe uses `MPMediaQuery` collections and items directly. It reads only metadata
needed for counts, top genres, top artists, and recent-added totals. The Apple
Music capability signal is built from `SKCloudServiceCapability` flags.

## Permission and Activity Classification

Music Library is active and permissioned on iOS. Loupe's permission center
checks `MPMediaLibrary.authorizationStatus()` and calls
`MPMediaLibrary.requestAuthorization(_:)` if the status is `notDetermined`.
The upstream Info.plist uses `NSAppleMusicUsageDescription`.

The one-shot `collect()` path is active local media-library enumeration. It does
not capture audio, play tracks, inspect audio buffers, or upload songs. The
privacy impact comes from library metadata and taste summaries.

The Apple Music capability check is an active account or service capability
query through StoreKit. It can expose whether the user can play catalog music,
is eligible for a subscription, or can add to iCloud Music Library. Treat it as
permissioned account-state collection, not as passive device metadata.

The provider is unavailable on macOS in Loupe's current implementation. The
macOS placeholder should not be treated as a user-level music fingerprint,
though it still contributes to platform coherence if an app compares feature
availability across APIs.

No Photos, Microphone, Bluetooth, Local Network, Contacts, Calendar, Reminders,
Location, or Motion permission is required for Loupe's Music Library provider.
Playback, recording, Shazam-style recognition, and streaming analytics are
separate surfaces outside this page.

## Fingerprinting Value

Top artists and top genres are the highest-value signals. They reveal taste and
identity more directly than most device settings. Niche artists, religious
music, political podcasts stored as music, regional genres, children's music,
language-specific collections, or medical/therapy audio can disclose sensitive
personal facts.

Counts are useful because they are stable. Song, album, playlist, and artist
counts can link sessions across app reinstalls or across apps that receive media
library permission. They also reveal whether the user syncs a local library,
uses Apple Music heavily, imports files, or has a sparse/no-library profile.

Playlist count can be especially personal. Playlists often reflect activities,
moods, workouts, relationships, events, trips, or long-lived organization
habits. Loupe only counts playlists, but an app with the same permission could
read more detail.

Recently added count is temporal. It can reveal a new device, library import,
recent subscription use, a music-discovery period, or interest in current
events/releases. Combined with top genres/artists, it can link sessions during
the same 30-day window.

Apple Music capabilities reveal account posture. Catalog playback,
subscription eligibility, and iCloud Music Library capability can distinguish
subscribers, family/account configurations, regional availability, restrictions,
or users who do not use Apple's music services.

## Mitigation Strategy Ideas

### `music.authorization-state`

Cover Media Library and Apple Music authorization as one policy surface:

- `MPMediaLibrary.authorizationStatus()`
- `MPMediaLibrary.requestAuthorization(_:)`
- `SKCloudServiceController.authorizationStatus()`
- Settings-driven authorization changes where practical

Compatibility default should pass through. Music players, DJ apps, library
managers, CarPlay/media apps, playlist tools, and import/export utilities need
real authorization and real library behavior.

Strict mode can prefer denied or restricted for apps that should not inspect
music taste. If status is rewritten to denied, media queries should return no
library data and Apple Music capability requests should not imply usable access.

### `music.library-counts`

Hook `MPMediaQuery` item and collection results together:

- `songs()`, `albums()`, `playlists()`, and `artists()`
- `MPMediaQuery.items`
- `MPMediaQuery.collections`
- `MPMediaItemCollection` membership when a target app cross-checks counts

Compatibility default should pass through. Strict mode can return empty,
limited, or coarse bucketed counts. Do not generate exact seed-derived count
tuples because they become durable identifiers.

If counts are synthetic, the query result objects must be coherent. A song
count of `0` with non-empty artist collections, or a playlist count that changes
without collection changes, is easy to detect.

### `music.taste-profile`

Treat genre and artist exposure as the most sensitive part of the category.
Coverage should include:

- `MPMediaItem.genre`
- `MPMediaItem.artist`
- album artist and composer fields if future provider coverage expands
- persistent IDs or query predicates that let an app rebuild the same top lists

Compatibility default should pass through for actual music apps. Strict mode
should return no accessible items, generic empty values, or a tiny common cohort
profile only when the app does not need real taste data.

Avoid synthetic niche artists or genres. A fake top-three list can be more
identifying than the real one if it is rare, unrealistic, or stable across many
apps. Empty or permission-denied is usually safer than invented taste.

### `music.recently-added`

Hook `MPMediaItem.dateAdded` and any date-based query path that can reveal
recent additions. The value should be consistent with the visible song list and
library count changes.

Compatibility default should pass through. Strict mode can bucket recent-added
counts or normalize to `0`, but only if visible item dates agree. Do not report
zero recently added songs while exposing items whose `dateAdded` falls in the
last 30 days.

### `music.apple-music-capabilities`

Cover Apple Music account and capability surfaces:

- `SKCloudServiceController.requestCapabilities`
- `SKCloudServiceCapability` flags
- `SKCloudServiceController.authorizationStatus()`
- MusicKit authorization and subscription-state equivalents if future coverage
  includes them

Compatibility default should pass through. Apps use these flags to decide
whether to show subscription offers, catalog playback, add-to-library, or
fallback UI.

Strict mode can return no capabilities or a common non-subscriber posture, but
that must agree with media-library authorization, MusicKit account state,
storefront, playback attempts, subscription UI, and server-observed entitlements.

## Derivation Considerations

Music values form a media-library and account tuple:

```text
authorization state determines query access
song count constrains album, artist, playlist, and top-list counts
top genres and artists derive from visible items
date-added values constrain recently added count
Apple Music capabilities constrain account and playback behavior
platform availability constrains whether the provider exists
```

The safest strict profiles are denied, empty, or coarse. Exact synthetic music
libraries are expensive to make coherent because apps can enumerate items,
collections, persistent IDs, metadata fields, artwork, playback availability,
cloud status, and predicates.

Taste values should not be generated from the seed as free-form strings. If a
compatibility profile needs a synthetic library, choose from a small,
population-shaped profile table and keep the tuple low entropy. For most
privacy profiles, hiding taste data is safer than inventing taste data.

Counts should be stable for the selected profile epoch and change only through
modeled library events. A recent-added count should decay or change according
to dates, not jump randomly across launches.

Apple Music capability flags must agree with subscription/account surfaces.
For example, exposing `addToCloudMusicLibrary` while returning no iCloud Music
Library state elsewhere, or hiding catalog playback while playback succeeds, is
a contradiction.

Purpose labels and derivation salts should remain internal and seed-bound.
Returned artists, genres, playlist shapes, media identifiers, and capability
profiles must not expose readable project names, mitigation names, seeds, or
profile IDs.

## Impact and Tradeoffs

Music Library mitigation can break real music features quickly. Apps may use
media queries to display a user's library, build playlists, search songs,
import tracks, sync metadata, control playback, or decide whether Apple Music
catalog playback is available.

Denying access is privacy-strong and coherent, but it can disable the main
purpose of music apps. Pass-through is the compatibility default for media
apps, while strict denial is more appropriate for apps that only request music
access for profiling or ad personalization.

Count bucketing is less invasive than hiding the whole library, but partial
coverage is risky. If an app can enumerate actual items after receiving a
bucketed count, the mismatch is obvious and may break UI.

Taste-profile spoofing is ethically and technically delicate. Fake artists and
genres can affect recommendations, content filters, child-safety settings,
regional assumptions, or cultural inferences. They can also create a new
high-cardinality identity if generated carelessly.

Apple Music capability spoofing can affect purchases, subscriptions, playback,
cloud-library modification, trial offers, and eligibility flows. A conservative
policy should pass through for apps that transact with Apple Music and normalize
only for non-music apps.

## Relevance

Music Library is a P1 permissioned fingerprint category. It is lower priority
than Location or Photos for physical privacy, but it exposes taste, account
state, and stable library shape behind a single prompt.

The highest-priority surfaces are top artists, top genres, song count, and
Apple Music capability flags. Playlist, album, artist, and recently-added
counts are also relevant because they make the library tuple more stable and
personal.

Loupehole should treat Music Library as a permissioned personal-data inventory.
Default behavior should be pass-through for real music apps and denied or empty
for strict profiles. Any future spoofing should model authorization, query
results, item metadata, recent-added dates, and StoreKit/MusicKit capability
state together.
