# `advertising.idfa`

The advertising ID option normalizes AdSupport's advertising identifier to the platform zero UUID and reports advertising tracking as disabled.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `advertising.idfa` |
| Implemented mitigation | `advertising.idfa.adsupport.zero` |
| Policy seeds | None |
| User-facing name | Advertising identifier |
| Status | Experimental |
| Surface | Advertising identity |
| Classification | Passive identifier read; active Objective-C hook mitigation |
| Affected APIs | `ASIdentifierManager.advertisingIdentifier`, `ASIdentifierManager.isAdvertisingTrackingEnabled` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | App Tracking Transparency controls access semantics outside this hook |

## References

- Apple AdSupport: `ASIdentifierManager`.
- Apple AdSupport: `advertisingIdentifier`.

## Surface And Relevance

The Identifier for Advertisers can be used as a cross-app advertising and attribution identifier when the platform allows it. The zero UUID is the native low-disclosure shape used when tracking is unavailable or limited.

## Mitigation Strategy

The mitigation hooks `ASIdentifierManager` and returns `00000000-0000-0000-0000-000000000000` for `advertisingIdentifier`. It also returns `NO` from `isAdvertisingTrackingEnabled` where that deprecated compatibility selector is present.

It does not request tracking authorization, change ATT prompts, spoof attribution frameworks, or alter any server-side advertising behavior.

## Derivation And Lifetime

No policy seed is declared because the value is the platform's common zero shape rather than a scoped synthetic identifier.

| Item | Value |
| --- | --- |
| Policy seed identifiers | None |
| Generated seed symbols | None |
| Helpers/state owner | None |
| Value shape | All-zero `NSUUID` and tracking-disabled boolean |
| Derivation input | None |
| Lifetime | Stable while the module is enabled |
| Temporal dependencies | None |

## Impact And Tradeoffs

Apps and SDKs that expect a nonzero advertising identifier observe the same shape as a tracking-denied device. Attribution, ad personalization, or analytics flows can lose precision.

## Validation

Expected observations:

- `advertisingIdentifier` returns the all-zero UUID.
- `isAdvertisingTrackingEnabled` returns `NO` when the selector is available.

Device validation is still required for ATT-adjacent call paths.

## Rollback And Pass-Through

Disabling the module restores original AdSupport behavior. If `ASIdentifierManager` or both selectors are unavailable, the module registers as a no-op.
