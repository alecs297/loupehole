# `account.ubiquity_token`

The ubiquity-token option hides the app-visible iCloud ubiquity identity token by normalizing `NSFileManager.ubiquityIdentityToken` to absent.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `account.ubiquity_token` |
| Implemented mitigation | `account.ubiquity_token.filemanager.nil` |
| Policy seeds | None; this mitigation returns the platform absent shape |
| User-facing name | iCloud ubiquity token |
| Status | Experimental |
| Surface | Apple Account |
| Classification | Passive account-state read; active Foundation hook mitigation |
| Affected APIs | `NSFileManager.ubiquityIdentityToken` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None |

## Surface And Relevance

The ubiquity identity token reflects iCloud account state. Loupe hashes the archived token, but the hash is still a durable equality marker while the token remains stable.

## Mitigation Strategy

The mitigation hooks `-[NSFileManager ubiquityIdentityToken]` and returns `nil`. It does not attempt to construct a synthetic token object because object equality, archiving, notification behavior, and account-change lifetime are difficult to model safely.

StoreKit storefront country and account-region APIs are not covered by this module.

## Derivation And Lifetime

No state or seed-derived values are used. The mitigation returns the documented absent shape for every covered read while enabled.

## Impact And Tradeoffs

Apps may interpret `nil` as no iCloud account, no iCloud Drive availability, a sign-out event, or document-sync unavailability. Apps that use iCloud documents or account-change detection need this module disabled or scoped out.

`NSUbiquityIdentityDidChange` notification behavior is not synthesized.

## Validation

Expected observations after catalog selection and generation:

- `NSFileManager.defaultManager.ubiquityIdentityToken` returns `nil`.
- Loupe reports the ubiquity token hash as absent.
- StoreKit storefront country remains original or unavailable according to the platform.

## Rollback And Pass-Through

If `NSFileManager` or the selector is unavailable, the module registers as a no-op. Disabling this module restores the real ubiquity identity token behavior.
