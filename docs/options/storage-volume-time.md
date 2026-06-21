# `storage.volume_creation_time`

The volume creation-time option normalizes Foundation URL resource metadata for
the current volume. It covers a passive storage/timeline surface, while the
mitigation actively hooks `NSURL` resource-value methods for the volume creation
date key.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `storage.volume_creation_time` |
| Implemented mitigation | `storage.volume_creation_time.foundation.synthetic` |
| Policy value | `volume_creation_time` |
| User-facing name | Volume creation time |
| Status | Experimental |
| Surface | Storage lifetime |
| Classification | Passive temporal/storage surface; active hook mitigation |
| Affected APIs | `-[NSURL getResourceValue:forKey:error:]`, `-[NSURL resourceValuesForKeys:error:]`, `NSURLVolumeCreationDateKey` |
| Default behavior | Enabled when the mitigation is selected |
| Permission requirement | None; these APIs do not trigger an iOS permission prompt |

## References

- Apple Developer: [`URLResourceKey.volumeCreationDateKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/volumecreationdatekey?language=objc).
- Apple Developer: [`NSURL getResourceValue:forKey:error:`](https://developer.apple.com/documentation/foundation/nsurl/getresourcevalue%28_%3Aforkey%3A%29?language=objc).
- Apple Developer: [`NSURL resourceValuesForKeys:error:`](https://developer.apple.com/documentation/foundation/nsurl/resourcevalues%28forkeys%3A%29?language=objc).
- Apple Developer: [`URLResourceKey`](https://developer.apple.com/documentation/foundation/urlresourcekey).

## Surface and Relevance

### Original API Behavior

Foundation URL resource APIs can expose volume-level metadata through resource
keys. `NSURLVolumeCreationDateKey` returns the volume creation date when the
volume supports that value.

### Fingerprinting Relevance

Volume creation time can reveal device setup, restore, migration, or storage
history. Apps can compare it with boot time, app install time, file metadata,
and cache timestamps to decide whether a timeline looks continuous across
reinstalls or device changes.

## Mitigation Strategy

The selected mitigation hooks `NSURL` methods that return resource values:

- `getResourceValue:forKey:error:` returns a synthetic `NSDate` when the key is
  `NSURLVolumeCreationDateKey`.
- `resourceValuesForKeys:error:` calls the original implementation, then
  replaces or inserts `NSURLVolumeCreationDateKey` in the returned dictionary
  when that key was requested.

Other resource keys pass through unchanged. The hook asks
`LHPolicyEngineCopyValue` for `LHPolicyValueID_volume_creation_time` as a time
interval, then converts that Unix timestamp to `NSDate`. Hook code does not
derive or embed the date.

If the `NSURL` class or both selectors are unavailable, the mitigation registers
as a no-op for this module.

## Derivation and Lifetime

- State owner:
  `packages/tweak/sources/state_domains/temporal_lifetime/TemporalLifetimeState.c`.
- State key label: `temporal_lifetime.state`.
- Boot anchor label: `temporal_lifetime.boot_anchor`.
- Volume offset label: `temporal_lifetime.volume_before_boot_offset`.
- Value shape: `double` Unix timestamp returned to Foundation as an `NSDate`.
- Derivation input: active instance seed plus active `LHScope`.
- Volume age: generated from the same synthetic boot anchor, then shifted earlier
  by at least 7 days plus a seed-derived offset inside a 180-day window.
- Storage behavior: the temporal state domain uses
  `LHPolicyEngineLoadOrCreateState`, so writable state keeps the generated
  timeline stable across relaunches for the same scope.
- Value dependencies: must stay earlier than `system.boot_time`.
- Temporal dependencies: `volumeCreationTime < bootTime < now`; the same state
  blob also reserves `profileEpoch <= volumeCreationTime` for later timeline
  surfaces.

## Impact and Tradeoffs

Only the Foundation URL resource-value surface is implemented here. Lower-level
file and filesystem metadata APIs such as `stat`, `fstat`, `lstat`,
`getattrlist`, and direct filesystem queries remain separate future mitigation
work. Apps that compare Foundation output with those lower-level surfaces may
still find mismatches until those modules exist.

The main detection risk is a contradictory timeline. A volume creation date
after boot time, after app install time, or after files that supposedly live on
the volume would be suspicious. This mitigation shares the temporal state used
by boot time so the first hard ordering is true by construction.

## Validation

Manual Loupe validation passed on 2026-06-18. Expected observations:

- Loupe's Foundation volume creation date path reports a synthetic date.
- The synthetic volume creation time remains stable across relaunches for the
  same seed and scope.
- The value is earlier than the synthetic boot time.
- Other requested URL resource keys preserve original behavior.

## Rollback and Pass-Through

If policy lookup fails for `getResourceValue:forKey:error:`, the hook calls the
original method. If no original method is available, it returns `NO` for that
query rather than inventing an unrelated date.

For `resourceValuesForKeys:error:`, the hook obtains the original dictionary
first. If policy lookup fails, it returns that original dictionary unchanged.
When policy lookup succeeds, only `NSURLVolumeCreationDateKey` is replaced or
inserted.

Disabling this mitigation should affect only Foundation volume creation date
queries. Boot-time and IDFV behavior are controlled by their own options.
