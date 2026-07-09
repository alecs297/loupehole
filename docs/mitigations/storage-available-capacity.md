# `storage.available_capacity`

The available-capacity option reduces exact free-space entropy exposed through Foundation URL resource values. It covers passive storage metadata while preserving the real storage-pressure class.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `storage.available_capacity` |
| Implemented mitigation | `storage.available_capacity.foundation.bucketed` |
| Policy seeds | None; this module buckets original values rather than deriving synthetic capacity |
| User-facing name | Available storage capacity |
| Status | Experimental |
| Surface | Storage |
| Classification | Passive local volume metadata; active Foundation hook mitigation |
| Affected APIs | `-[NSURL getResourceValue:forKey:error:]`, `-[NSURL resourceValuesForKeys:error:]`, `NSURLVolumeAvailableCapacityKey`, `NSURLVolumeAvailableCapacityForImportantUsageKey`, `NSURLVolumeAvailableCapacityForOpportunisticUsageKey` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None |

## References

- Apple Developer: `URLResourceKey.volumeAvailableCapacityKey`.
- Apple Developer: `URLResourceKey.volumeAvailableCapacityForImportantUsageKey`.
- Apple Developer: `URLResourceKey.volumeAvailableCapacityForOpportunisticUsageKey`.
- Apple Developer: `NSURL getResourceValue:forKey:error:`.
- Apple Developer: `NSURL resourceValuesForKeys:error:`.

## Surface And Relevance

Foundation volume capacity keys expose exact byte counts for available storage and storage the system may make available for important or opportunistic usage. Exact values can link launches, reinstalls, and web/native sessions because local media, app data, caches, and purgeable content shape the tuple.

## Mitigation Strategy

The mitigation hooks the two Foundation resource-value methods already used by the storage surface. It calls the original implementation first, then buckets only values returned for the three available-capacity keys. Unsupported keys, nil values, errors, write attempts, and nonnumeric values pass through unchanged.

The bucket function is monotonic and rounds down. Values below 512 MiB pass through to avoid hiding urgent storage pressure. Larger values are rounded into broad MiB/GiB buckets, reducing exact byte entropy without claiming more free space than the filesystem reported.

`NSURLVolumeTotalCapacityKey`, volume UUID, names, lower-level filesystem calls, and WebKit quota surfaces are untouched.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifiers | None |
| Helper/state owner | Local module logic only |
| Value shape | `NSNumber` byte counts returned by Foundation |
| Derivation input | Original Foundation value |
| Storage behavior | No mitigation-owned state |
| Lifetime | Tracks the original value's lifetime, with precision reduced per read |
| Dependencies | Total capacity is passed through and still bounds real filesystem behavior |

Because this module does not invent exact synthetic capacity, it does not declare a policy seed. If strict synthetic capacity is added later, available, important, opportunistic, total capacity, WebKit quota, and filesystem statistics should be modeled as one tuple.

## Impact And Tradeoffs

Underreporting capacity can make apps behave conservatively, but the module never overreports. Apps that need exact free bytes may still see behavior changes. Apps comparing Foundation output with `statfs`, `fstatfs`, `getattrlist`, app container size, or WebKit storage estimates can still observe the real lower-level values.

## Validation

Expected observations:

- Loupe's available, important, and opportunistic capacity display strings show bucketed byte counts when Foundation returns numeric values.
- Low-space values below 512 MiB pass through.
- Unsupported resource keys and errors preserve original behavior.
- The tuple ordering remains monotonic when the original Foundation tuple is monotonic.

## Rollback And Pass-Through

If hook installation fails, the module registers as a no-op. If the original call fails, returns nil, returns a nonnumeric value, or the query is for an unrelated key, the original result is returned unchanged. Disabling the mitigation affects only the three documented Foundation capacity keys.
