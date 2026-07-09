# `app_bundle.install_date`

The app install-date option normalizes Foundation creation-date reads for the protected app's sandbox container roots. It covers the app-container timeline signal described in App & Bundle, while leaving bundle version metadata untouched.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `app_bundle.install_date` |
| Implemented mitigation | `app_bundle.install_date.foundation.synthetic` |
| Policy seeds | `app_install_date`, `volume_creation_date` |
| User-facing name | App install date |
| Status | Experimental |
| Surface | App & Bundle |
| Classification | Passive app-container metadata surface; active Foundation hook mitigation |
| Affected APIs | `-[NSURL getResourceValue:forKey:error:]`, `-[NSURL resourceValuesForKeys:error:]`, `NSURLCreationDateKey` for app container roots |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None |

## Surface And Relevance

Apps can read the Documents directory creation date as an app-install timeline anchor. That timestamp can link launches in the same install and can be compared with previous-install logs, volume creation time, boot time, cache files, and server first-seen records.

## Mitigation Strategy

The mitigation hooks `NSURL` resource-value methods and only replaces `NSURLCreationDateKey` for the current app's standard container roots: `Documents`, `Library`, `Library/Caches`, and `Library/Application Support`. Other file URLs, other resource keys, and bundle Info.plist reads pass through.

The hook obtains the original Foundation result first. If the original API cannot return resource values, the hook preserves that failure instead of manufacturing a date.

## Derivation And Lifetime

The value owner declares:

```c
LH_POLICY_SEED(app_install_date)
LH_POLICY_SEED(volume_creation_date)
```

| Item | Value |
| --- | --- |
| Value owner | `src/mitigations/app_bundle/install_date/AppInstallDateValues.c` |
| Helper | `LHMitigationCopyStableTimeIntervalBetween` |
| Derivation input | active/practical seed + generated policy seed + active `LHScope` |
| Install range | Stable timestamp after the synthetic volume baseline, within a 90-day lookback, and at least one hour before first generation |
| State behavior | Persisted through mitigationkit stable-time state with schema version `1` |
| Coherence dependency | Reuses `volume_creation_date` |

## Impact And Tradeoffs

Apps that use container age for migrations, retention, onboarding, or diagnostics may observe a younger or older install than the real filesystem reports through lower-level APIs. Lower-level `stat`, `getattrlist`, directory enumeration, and unrelated file creation dates are not covered here.

Bundle metadata such as app version, build number, bundle ID, executable name, receipt data, and `DTSDKName` remains real because changing it without a full app-identity model is high risk.

## Validation

Expected observations after catalog selection and generation:

- Loupe's Documents creation-date path reports the synthetic app install date.
- The value remains stable across relaunches for the same seed and scope.
- The value is later than the synthetic volume creation date and earlier than the current wall clock.
- Non-container files and non-creation-date resource keys keep original behavior.

## Rollback And Pass-Through

If hook installation fails, the module registers as a no-op. If state loading, volume-baseline derivation, or date conversion fails, the hook returns the original Foundation result unchanged.
