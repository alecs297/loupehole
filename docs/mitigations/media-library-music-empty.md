# `media_library.music`

The Music Library option normalizes MediaPlayer library access and Apple Music capability checks to denied, empty results. It covers Loupe's iOS music-library inventory and account-capability paths without generating synthetic taste data.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `media_library.music` |
| Implemented mitigation | `media_library.music.inventory.empty` |
| Policy seeds | None |
| User-facing name | Music library inventory |
| Status | Experimental |
| Surface | Music Library |
| Classification | Permissioned media-library and account-capability inventory; active hook mitigation |
| Affected APIs | `MPMediaLibrary.authorizationStatus`, `MPMediaLibrary.requestAuthorization`, `MPMediaQuery.items`, `MPMediaQuery.collections`, `MPMediaItem.genre`, `MPMediaItem.artist`, `MPMediaItem.dateAdded`, `SKCloudServiceController.authorizationStatus`, `SKCloudServiceController.requestCapabilities` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | Media Library / Apple Music |

## Surface And Relevance

Music Library access exposes song, album, playlist, and artist counts, top genres and artists, recent additions, and Apple Music account capabilities. Taste metadata and account posture are personal and can be stable enough to link sessions after permission grant.

## Mitigation Strategy

The mitigation reports Media Library and StoreKit cloud-service authorization as denied, completes Media Library authorization requests with denied status, returns empty arrays from `MPMediaQuery.items` and `MPMediaQuery.collections`, returns `nil` for direct genre/artist/date-added item fields, and completes Apple Music capability requests with no capability flags.

It does not synthesize artists, genres, playlists, song dates, persistent IDs, subscription state, or cloud-library capabilities. Empty/no-capability behavior is more coherent than a seed-derived fake taste profile.

## Derivation And Lifetime

No policy seeds are declared because the mitigation owns no synthetic music library, taste profile, or account-state value stream.

| Item | Value |
| --- | --- |
| Value shape | Denied media authorization, empty query arrays, nil taste/date fields, zero Apple Music capabilities |
| Derivation input | None |
| Storage behavior | None |
| Scope behavior | Runtime policy controls activation; no per-scope music profile is generated |
| Account behavior | StoreKit cloud-service capabilities complete with no flags |

## Impact And Tradeoffs

This can break music players, DJ apps, library managers, playlist tools, CarPlay/media integrations, import/export utilities, and Apple Music transaction flows. It is strict privacy behavior for apps that should not inspect library taste or account capabilities.

The mitigation does not cover MusicKit-only APIs, playback attempts, storefront identifiers, cloud-library mutation, artwork, persistent IDs, or query predicates beyond the item and collection result accessors. Those paths need separate validation before broader claims.

## Validation

Expected observations after catalog selection and generation:

- Media Library authorization probes report denied.
- Loupe-style song, album, playlist, and artist counts are zero.
- Top genre and artist summaries are empty because query items are empty and direct item fields return nil.
- Recently added count is zero.
- Apple Music capability flags are empty.

No device validation has been recorded for this mitigation yet.

## Rollback And Pass-Through

Disabling this mitigation restores original MediaPlayer and StoreKit behavior. If all targeted classes or selectors are unavailable, the installer registers a no-op. The replacement paths do not create synthetic fallback songs, artists, genres, or capabilities.
