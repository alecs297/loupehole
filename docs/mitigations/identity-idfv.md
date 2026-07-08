# `identity.idfv`

The IDFV option replaces the app-visible vendor identifier with a scoped UUID derived by the selected mitigation. It covers a passive identity surface, while the mitigation itself is an active Objective-C method hook.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `identity.idfv` |
| Implemented mitigation | `identity.idfv.uidevice.scoped_uuid` |
| Policy seeds | `identifier_for_vendor` |
| User-facing name | Vendor identifier |
| Status | Experimental |
| Surface | Device identity |
| Classification | Passive fingerprinting surface; active hook mitigation |
| Affected APIs | `UIDevice.identifierForVendor` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None; this API does not trigger an iOS permission prompt |

## References

- Apple Developer: [`UIDevice.identifierForVendor`](https://developer.apple.com/documentation/uikit/uidevice/identifierforvendor).
- Apple Developer: [`NSUUID`](https://developer.apple.com/documentation/foundation/nsuuid), the Objective-C UUID object returned by the hooked property.

## Surface And Relevance

`UIDevice.identifierForVendor` returns an optional UUID managed by iOS for the current app's vendor. Apple documents it as a device identifier unique to the app's vendor, with reset behavior tied to removal and reinstall of that vendor's apps.

Apps and SDKs can treat IDFV as a stable native identifier for analytics, anti-abuse, attribution, or account recovery. By itself it is vendor-scoped, but when combined with boot time, storage lifetime, device profile, locale, and network signals it can help link sessions or reinstalls.

## Mitigation Strategy

The mitigation hooks `-[UIDevice identifierForVendor]`. The replacement derives a UUID string with `LHMitigationDeriveUUIDString`, converts that string to `NSUUID`, and returns it to the caller.

Hook code does not embed UUID bytes. Its only policy seed declaration is:

```c
LH_POLICY_SEED(identifier_for_vendor)
```

Non-IDFV APIs are untouched. If the target class or selector is unavailable, the mitigation registers as a no-op for this module.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifier | `identifier_for_vendor` |
| Generated seed symbol | `LHGeneratedPolicySeed_identifier_for_vendor` |
| Helper | `LHMitigationDeriveUUIDString` |
| Value shape | Lowercase RFC 4122 version 4 UUID string accepted by `NSUUID`. |
| Derivation input | active/practical seed + generated policy seed + active `LHScope`. |
| Storage behavior | No mitigation-owned state blob; stability comes from seed and scope. |
| Lifetime | Stable until the active seed, policy seed, or scope changes. |
| Temporal dependencies | None directly. |

IDFV scope choice matters. Per-app scope gives stronger unlinking between apps, while vendor-group scope better matches Apple's normal vendor sharing behavior when the vendor input is available.

## Impact And Tradeoffs

Apps that expect multiple apps from the same vendor to share one IDFV need vendor-group or shared-scope configuration. Per-app scope may differ from Apple's normal vendor-level sharing behavior.

The main detection risk is uniqueness through inconsistent scoping. A synthetic UUID is still a stable identifier if it is reused too broadly or exposed alongside a timeline that rotates on a different schedule.

## Validation

Manual Loupe validation passed on 2026-06-18. Expected observations:

- `UIDevice.identifierForVendor` differs from the real device/vendor value after injection.
- The returned UUID remains stable across relaunches for the same seed and scope.
- Different app scopes receive different values unless a shared scope is selected.
- The mitigation-value verifier can derive a UUID through generated policy seed bytes.

## Rollback And Pass-Through

If derivation fails, the generated string cannot be parsed as an `NSUUID`, or the replacement cannot obtain a usable value, the hook calls the original `identifierForVendor` implementation. If no original implementation is available, it returns `nil` rather than inventing a second fallback value.

Disabling this mitigation should affect only `UIDevice.identifierForVendor`. Other identity, storage, and temporal APIs keep their own documented behavior.
