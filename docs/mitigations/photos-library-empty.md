# `photos.library`

The Photos library option normalizes Photos access to denied, empty fetch results and hides asset locations. It covers Loupe's asset-count, album-count, and geotag-summary paths without inventing a synthetic media library.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `photos.library` |
| Implemented mitigation | `photos.library.inventory.empty` |
| Policy seeds | None |
| User-facing name | Photos library inventory |
| Status | Experimental |
| Surface | Photos |
| Classification | Permissioned personal media inventory; active hook mitigation |
| Affected APIs | `PHPhotoLibrary.authorizationStatus`, `PHPhotoLibrary.authorizationStatus(for:)`, `PHPhotoLibrary.requestAuthorization`, `PHAsset.fetchAssets`, `PHAsset.fetchAssets(with:)`, `PHAsset.fetchAssets(in:)`, `PHAsset.fetchKeyAssets(in:)`, `PHAssetCollection.fetchAssetCollections`, `PHFetchResult.count`, `PHAsset.location` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | Photos read/write access |

## Surface And Relevance

Photos metadata exposes image, video, audio, album, and shared-album counts plus geotagged location history. Loupe does not read pixels, but library metadata and photo locations can reveal routines, travel, home/work clusters, cloud-sharing behavior, and media habits.

## Mitigation Strategy

The mitigation reports Photos authorization as denied and completes authorization requests with denied status. Asset and collection fetch class methods are rerouted through original Photos fetch implementations with a false predicate, preserving `PHFetchResult` shape where possible while returning no rows. `PHFetchResult.count` returns zero, and `PHAsset.location` returns `nil`.

It does not generate fake assets, albums, coordinates, place names, creation dates, local identifiers, or shared-album state. Empty fetches are preferred over seed-derived exact counts because synthetic Photos libraries are easy to contradict through collection membership, change notifications, asset metadata, and user-visible picker behavior.

## Derivation And Lifetime

No policy seeds are declared because the mitigation owns no generated media-library profile and stores no state.

| Item | Value |
| --- | --- |
| Value shape | Denied Photos authorization, empty fetch results, zero fetch counts, nil asset locations |
| Derivation input | None |
| Storage behavior | None |
| Scope behavior | Runtime policy controls activation; no per-scope Photos profile is generated |
| Geotag behavior | Local asset location metadata is hidden by returning `nil` |

## Impact And Tradeoffs

This can break galleries, photo editors, scanners, social apps, backup tools, importers, search, memories, map views, and any app where the user expects real library access. It is strict privacy behavior for apps that should not inspect the library.

The mitigation does not cover the limited-library picker, Photos change notifications, direct resource/image-manager data requests, asset mutation APIs, or Core Location reverse-geocoding. It hides `PHAsset.location`, but it does not try to decide whether an arbitrary `CLGeocoder` request came from photo metadata.

## Validation

Expected observations after catalog selection and generation:

- Photos authorization probes report denied.
- Loupe-style image, video, audio, user-album, smart-album, and shared-album counts are zero.
- Geotagged asset count is zero because returned assets are empty and `PHAsset.location` is nil.
- No place-name lookup should be possible through the covered Photos paths.

No device validation has been recorded for this mitigation yet.

## Rollback And Pass-Through

Disabling this mitigation restores original Photos behavior. If Photos classes or all targeted selectors are unavailable, the installer registers a no-op. Fetch replacements return `nil` only when an original fetch implementation is unavailable; otherwise they ask Photos for an empty native fetch result.
