# `identity.device_name`

The device-name option reduces user-assigned device-name entropy by returning a generic device-class name through `UIDevice.name`.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `identity.device_name` |
| Implemented mitigation | `identity.device_name.uidevice.generic` |
| Policy seeds | None; this mitigation returns a low-entropy cohort constant |
| User-facing name | Device name |
| Status | Experimental |
| Surface | Device identity |
| Classification | Passive identity surface; active UIKit hook mitigation |
| Affected APIs | `UIDevice.name` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None; user-assigned name access may also depend on entitlement behavior on modern iOS |

## References

- Apple Developer: `UIDevice`.
- Apple Developer: `UIDevice.name`.
- Apple Developer: `UIDevice.userInterfaceIdiom`.

## Surface And Relevance

`UIDevice.name` can expose a personalized device name on some OS versions, platforms, or entitlemented builds. Personalized names can reveal owner, household, or local-network naming choices.

## Mitigation Strategy

The mitigation hooks `-[UIDevice name]` and returns `iPad` when `userInterfaceIdiom` reports a pad idiom, otherwise `iPhone`. It does not derive a per-user string, add numeric suffixes, or return owner-like names.

The hostname mitigation uses the same vocabulary so `UIDevice.name` and hostname-like values do not expose two unrelated naming schemes.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifiers | None |
| Helper/state owner | Local module idiom check only |
| Value shape | `NSString` value `iPad` or `iPhone` |
| Derivation input | Current `UIDevice.userInterfaceIdiom` |
| Storage behavior | No mitigation-owned state blob |
| Lifetime | Common cohort value changes only when the device class observed by UIKit changes |

## Impact And Tradeoffs

Apps that show the device name in sync pickers, device-management flows, diagnostics, or support UI will see the generic name. Entitlemented apps that legitimately need the real user-assigned name need this module disabled or scoped out.

Adjacent OS-version and hardware-model values are not changed here.

## Validation

Expected observations after catalog selection and generation:

- `UIDevice.name` returns `iPhone` or `iPad`, not a personalized device name.
- The value is stable across relaunches on the same device class.
- IDFV, OS version, hardware model, and other `UIDevice` properties keep their own documented behavior.

## Rollback And Pass-Through

If `UIDevice` or the selector is unavailable, the module registers as a no-op. Disabling this mitigation restores the original `UIDevice.name` behavior.
