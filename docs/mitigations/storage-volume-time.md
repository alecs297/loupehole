# `storage.volume_creation_time`

The volume creation-time option normalizes Foundation URL resource metadata for the current volume. It covers a passive storage/timeline surface, while the mitigation actively hooks `NSURL` resource-value methods for the volume creation date key.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `storage.volume_creation_time` |
| Implemented mitigation | `storage.volume_creation_time.foundation.synthetic` |
| Policy seeds | `volume_creation_date` |
| User-facing name | Volume creation time |
| Status | Experimental |
| Surface | Storage lifetime |
| Classification | Passive temporal/storage surface; active hook mitigation |
| Affected APIs | `-[NSURL getResourceValue:forKey:error:]`, `-[NSURL resourceValuesForKeys:error:]`, `NSURLVolumeCreationDateKey` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None; these APIs do not trigger an iOS permission prompt |

## References

- Apple Developer: [`URLResourceKey.volumeCreationDateKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/volumecreationdatekey?language=objc).
- Apple Developer: [`NSURL getResourceValue:forKey:error:`](https://developer.apple.com/documentation/foundation/nsurl/getresourcevalue%28_%3Aforkey%3A%29?language=objc).
- Apple Developer: [`NSURL resourceValuesForKeys:error:`](https://developer.apple.com/documentation/foundation/nsurl/resourcevalues%28forkeys%3A%29?language=objc).
- Apple Developer: [`URLResourceKey`](https://developer.apple.com/documentation/foundation/urlresourcekey).

## Surface And Relevance

Foundation URL resource APIs can expose volume-level metadata through resource keys. `NSURLVolumeCreationDateKey` returns the volume creation date when the volume supports that value.

Volume creation time can reveal device setup, restore, migration, or storage history. Apps can compare it with boot time, app install time, file metadata, and cache timestamps to decide whether a timeline looks continuous across reinstalls or device changes.

## Mitigation Strategy

The selected mitigation hooks `NSURL` methods that return resource values:

- `getResourceValue:forKey:error:` returns a synthetic `NSDate` when the key is `NSURLVolumeCreationDateKey`.
- `resourceValuesForKeys:error:` calls the original implementation, then replaces or inserts `NSURLVolumeCreationDateKey` in the returned dictionary when that key was requested.

Other resource keys pass through unchanged. The hook reads the storage mitigation's value owner and converts the Unix timestamp to `NSDate`. Hook code does not embed the date itself.

If the `NSURL` class or both selectors are unavailable, the mitigation registers as a no-op for this module.

## Derivation And Lifetime

The storage mitigation declares:

```c
LH_POLICY_SEED(volume_creation_date)
```

| Item | Value |
| --- | --- |
| Value owner | `src/mitigations/storage/volume_creation_time/VolumeCreationTimeValues.c` |
| State key | Managed by `LHMitigationCopyStablePastTime` with `LHGeneratedPolicySeed_volume_creation_date`. |
| Volume helper | `LHMitigationCopyStablePastTime` with `LHGeneratedPolicySeed_volume_creation_date` |
| Value shape | `double` Unix timestamp returned to Foundation as an `NSDate`. |
| Derivation input | active/practical seed + generated policy seed + active `LHScope`. |
| Volume range | Created between 30 days and 2 years before first generation for the active scope. |
| Storage behavior | The mitigationkit stable-time helper keeps the generated volume time stable across relaunches for the same scope. |
| Temporal dependency | The boot-time mitigation also declares `volume_creation_date` and derives its boot time after this baseline. |

The volume creation date is owned by this mitigation. Other mitigations that need to agree with it must declare the same `volume_creation_date` policy seed identifier and reproduce the documented relative range.

## Impact And Tradeoffs

Only the Foundation URL resource-value surface is implemented here. Lower-level file and filesystem metadata APIs such as `stat`, `fstat`, `lstat`, `getattrlist`, and direct filesystem queries remain separate future mitigation work. Apps that compare Foundation output with those lower-level surfaces may still find mismatches until those modules exist.

The main detection risk is a contradictory timeline. A volume creation date after boot time, after app install time, or after files that supposedly live on the volume would be suspicious. The boot-time mitigation handles the first hard ordering by deriving its own boot time after the same documented `volume_creation_date` baseline.

## Validation

Manual Loupe validation passed on 2026-06-18. Expected observations:

- Loupe's Foundation volume creation date path reports a synthetic date.
- The synthetic volume creation time remains stable across relaunches for the same seed and scope.
- The value is earlier than the synthetic boot time when the boot-time mitigation is selected.
- Other requested URL resource keys preserve original behavior.

## Rollback And Pass-Through

If derivation fails for `getResourceValue:forKey:error:`, the hook calls the original method. If no original method is available, it returns `NO` for that query rather than inventing an unrelated date.

For `resourceValuesForKeys:error:`, the hook obtains the original dictionary first. If derivation fails, it returns that original dictionary unchanged. When derivation succeeds, only `NSURLVolumeCreationDateKey` is replaced or inserted.

Disabling this mitigation should affect only Foundation volume creation date queries. Boot-time and IDFV behavior are controlled by their own options.
