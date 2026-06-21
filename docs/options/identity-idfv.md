# `identity.idfv`

The IDFV option replaces the app-visible vendor identifier with a scoped UUID
resolved by policy state. It covers a passive identity surface, but the
mitigation itself is an active Objective-C method hook.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `identity.idfv` |
| Implemented mitigation | `identity.idfv.uidevice.scoped_uuid` |
| Policy value | `identifier_for_vendor` |
| User-facing name | Vendor identifier |
| Status | Experimental |
| Surface | Device identity |
| Classification | Passive fingerprinting surface; active hook mitigation |
| Affected APIs | `UIDevice.identifierForVendor` |
| Default behavior | Enabled when the mitigation is selected |
| Permission requirement | None; this API does not trigger an iOS permission prompt |

## References

- Apple Developer: [`UIDevice.identifierForVendor`](https://developer.apple.com/documentation/uikit/uidevice/identifierforvendor).
- Apple Developer: [`NSUUID`](https://developer.apple.com/documentation/foundation/nsuuid), the Objective-C UUID object returned by the hooked property.

## Surface and Relevance

### Original API Behavior

`UIDevice.identifierForVendor` returns an optional UUID managed by iOS for the
current app's vendor. Apple documents it as a device identifier unique to the
app's vendor, with reset behavior tied to removal and reinstall of that
vendor's apps.

### Fingerprinting Relevance

Apps and SDKs can treat IDFV as a stable native identifier for analytics,
anti-abuse, attribution, or account recovery. By itself it is vendor-scoped, but
when combined with boot time, storage lifetime, device profile, locale, and
network signals it can help link sessions or reinstalls.

## Mitigation Strategy

The mitigation hooks `-[UIDevice identifierForVendor]`. The replacement asks
`LHPolicyEngineCopyValue` for `LHPolicyValueID_identifier_for_vendor` as a UTF-8
UUID string, converts that string to `NSUUID`, and returns the object to the
caller.

Hook code does not derive or embed UUID bytes. Generation is owned by
`LHPolicyResolve_identifier_for_vendor`, which keeps value construction in the
policy layer and leaves the hook as a thin adapter.

Non-IDFV APIs are untouched. If the target class or selector is unavailable, the
mitigation registers as a no-op for this module.

## Derivation and Lifetime

- State owner: `packages/tweak/sources/identity/idfv/IDFVPolicyValue.c`.
- State key label: `identifier_for_vendor.state`.
- Value label: `identifier_for_vendor.value`.
- Value shape: a lowercase UUID string accepted by `NSUUID`.
- Derivation input: active instance seed plus active `LHScope`.
- Storage behavior: the resolver uses `LHPolicyEngineLoadOrCreateState`, so a
  writable state provider keeps the UUID stable across relaunches for the same
  scope.
- Lifetime: per-scope stable until state is reset, the active seed changes, or a
  scope input such as the app-install marker rotates.
- Temporal dependencies: none directly.
- Value dependencies: should use the same scope policy as the first temporal
  mitigation group so identity and lifetime values rotate together.

## Impact and Tradeoffs

Apps that expect multiple apps from the same vendor to share one IDFV need a
vendor-group or shared-scope configuration. Per-app scope gives stronger unlinking
between apps, but may differ from Apple's normal vendor-level sharing behavior.

The main detection risk is uniqueness through inconsistent scoping. A random
UUID is still a stable identifier if it is reused too broadly or exposed
alongside a timeline that rotates on a different schedule.

## Validation

Manual Loupe validation passed on 2026-06-18. Expected observations:

- `UIDevice.identifierForVendor` differs from the real device/vendor value after
  injection.
- The returned UUID remains stable across relaunches for the same seed and
  scope.
- Different app scopes receive different values unless a shared scope is
  selected.
- The policy query verifier can request `identifier_for_vendor` without the hook
  generating the UUID itself.

## Rollback and Pass-Through

If policy lookup fails, the generated string cannot be parsed as an `NSUUID`, or
the replacement cannot obtain a usable value, the hook calls the original
`identifierForVendor` implementation. If no original implementation is
available, it returns `nil` rather than inventing a second fallback value.

Disabling this mitigation should affect only `UIDevice.identifierForVendor`.
Other identity, storage, and temporal APIs keep their own documented behavior.
