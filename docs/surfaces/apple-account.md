# Apple Account

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/AppleAccountProvider.swift`

Loupe category: Apple Account
Loupe tier: passive account/storefront state
Permission required: none
Primary relevance: durable account correlation, App Store region coherence, and
separation between device locale, network location, and Apple account region.

This category covers two app-readable Apple account signals. Loupe does not ask
for a TCC permission, does not open iCloud documents, and does not perform an
external account probe. It reads the local iCloud ubiquity identity token and
the current StoreKit storefront, then reports either the observed value or an
availability sentinel.

## Official and Equivalent Links

- [`FileManager.ubiquityIdentityToken`](https://developer.apple.com/documentation/foundation/filemanager/ubiquityidentitytoken)
- [`NSUbiquityIdentityDidChange`](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nsubiquityidentitydidchange)
- [`Storefront`](https://developer.apple.com/documentation/storekit/storefront)
- [`Storefront.current`](https://developer.apple.com/documentation/storekit/storefront/current)
- [`Storefront.countryCode`](https://developer.apple.com/documentation/storekit/storefront/countrycode)
- [`SKStorefront`](https://developer.apple.com/documentation/storekit/skstorefront)
- [`SKCloudServiceController.requestStorefrontCountryCode(completionHandler:)`](https://developer.apple.com/documentation/storekit/skcloudservicecontroller/requeststorefrontcountrycode%28completionhandler%3A%29)

Apple documents the public Foundation and StoreKit surfaces used here. The
older `SKStorefront` and `SKCloudServiceController` links are included as
equivalent StoreKit country-code surfaces because a mitigation that changes only
`Storefront.current` can leave legacy account-region reads inconsistent.

## Loupe Signals

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `ubiquityToken.hash` | `FileManager.default.ubiquityIdentityToken`, archived with `NSKeyedArchiver` and hashed with SHA-256 | None | Passive local account-state read | Include | High when present. It is an app-visible iCloud identity token derived from the signed-in account state, and Loupe turns it into a stable hash instead of showing the raw token object. |
| `ubiquityToken.hash == absent` | Same API returning `nil` | None | Passive local account-availability read | Include as the absent state of the same surface | Medium. Absence can reveal no iCloud sign-in, disabled iCloud Drive/documents, account restrictions, or platform state. |
| `storefront.country` | `await Storefront.current`, then `Storefront.countryCode` | None | Passive StoreKit account/storefront read | Include | Medium to high. The App Store storefront country can differ from device locale, time zone, SIM country, IP region, and travel location. |
| `storefront.country == unavailable` | Same StoreKit API returning `nil` | None | Passive StoreKit availability read | Include as the unavailable state of the same surface | Medium. Unavailability can distinguish account, simulator, platform, store, or policy state. |

## Permission and Activity Classification

No Loupe Apple Account signal requires Contacts, Location, Bluetooth, Local
Network, Motion, Photos, Music, iCloud Documents entitlement approval, or
another user-granted runtime permission. The reads depend on the user's system
account configuration, but Loupe does not show a permission prompt.

`FileManager.ubiquityIdentityToken` is a passive local Foundation read. It can
change when the user signs in or out of iCloud, or when document syncing state
changes, and Apple exposes a notification for that change.

`Storefront.current` is an asynchronous StoreKit property, but Loupe uses it as
a passive account/storefront lookup. It does not make a purchase, request media
library access, or ask for Apple Music authorization.

## Fingerprinting Value

The iCloud ubiquity token hash is the strongest signal on this page because it
is tied to account state rather than hardware state. Even though Loupe hashes
the archived token before display, the hash remains a stable equality marker as
long as the underlying token remains stable. A tracker does not need the raw
token if the same digest appears again.

The absent token state is also meaningful. Many devices will have iCloud
available, so `absent` can indicate a narrower account setup, enterprise
restriction, simulator state, or a user who disabled iCloud Drive/documents.

The storefront country is lower-cardinality than an account token, but it is a
useful account-region anchor. It can reveal a country associated with purchases
or App Store availability, even when the current time zone, locale region,
network path, VPN, or SIM metadata says something else. It also influences
in-app product availability and storefront-specific behavior.

`unavailable` is not just missing data. It can identify account state, platform
limitations, test environments, or StoreKit failures, and must be handled as
part of the same surface instead of silently replacing it with a country.

## Mitigation Strategy Ideas

### `account.ubiquity-token`

Hook `FileManager.ubiquityIdentityToken` and equivalent Objective-C Foundation
paths that expose the same token. Treat the identity-change notification as part
of the surface: if a synthetic token changes, notification behavior should not
contradict property reads.

Compatibility default should pass through. Apps that use iCloud documents or
ubiquitous containers compare this token to detect account changes and may
reset document state when it changes or becomes nil.

Strict mode can normalize to `nil` for apps that only use the token as a
fingerprinting equality marker. That is lower risk than inventing a rare,
high-cardinality synthetic object, but it may make the app believe iCloud
documents are unavailable. A synthetic token is possible only if it preserves
object equality, archiving behavior, notification timing, and account lifetime
semantics.

Do not return readable project names, salts, profile identifiers, or generated
strings through an object that can be archived or described. If the hook cannot
construct a platform-plausible token object, pass through or return nil under an
explicit strict policy.

### `account.storefront-country`

Hook StoreKit storefront reads as a family:

- `Storefront.current`
- `Storefront.countryCode`
- legacy `SKStorefront.countryCode`
- `SKCloudServiceController.requestStorefrontCountryCode`
- purchase or transaction country-code fields when they are used as current
  account-region evidence

Compatibility default should pass through. Storefront country affects product
availability, pricing, compliance, entitlement flows, and region-specific
content.

Strict mode can choose a common storefront country from the selected locale or
account profile. The value should be an ISO 3166-1 alpha-3 country code because
that is what StoreKit reports. Do not derive a rare or rotating country per app;
a stable but unusual account-region tuple can become a stronger fingerprint.

If storefront access is unavailable on the real platform, preserve the
unavailable shape unless the policy intentionally models a signed-in account.
Returning a country while other StoreKit APIs fail in account-like ways is easy
to detect.

## Derivation and Coherence Considerations

Apple account values should belong to an account/profile state domain, not to
the hardware profile and not to per-read randomization. A useful state record
contains:

```text
iCloud token state: present or absent
iCloud token replacement, if strict mode can safely synthesize one
StoreKit storefront country or unavailable state
profile/account epoch
related locale, time-zone, SIM, network, and currency assumptions
```

The ubiquity token state must be stable for its profile lifetime. It should
change only on an account/profile reset, an explicit synthetic account-change
event, or pass-through platform account changes. Do not rotate it per launch or
per process.

The storefront country must agree with account-facing StoreKit behavior. It
does not have to match current time zone or locale, because real users travel
and use foreign storefronts, but mismatches should be stable and explainable.
For example, `BEL` as a storefront with `Europe/Brussels`, French/Dutch
languages, and Belgian currency assumptions is ordinary; a random storefront
that changes every launch is not.

Absence and unavailable states are first-class values. A profile that reports no
iCloud token should not also emit iCloud-document success paths that prove the
account is present. A profile that reports no current storefront should not
emit a StoreKit country through a legacy API.

Purpose labels and derivation salts should remain internal and seed-bound.
Returned API values must not expose readable mitigation names or Loupehole
state labels.

## Impact and Tradeoffs

Hiding or changing the ubiquity token can make an app believe the user signed
out of iCloud, disabled iCloud documents, or switched accounts. That can trigger
document resync, local cache invalidation, account-change UI, or data-loss
prevention flows. Pass-through is safest for apps that actually use iCloud.

Normalizing storefront country can break purchases, pricing, regional catalog
availability, tax/compliance handling, subscription eligibility, and server-side
StoreKit checks. It is safer for apps that only read StoreKit country as a
fingerprinting or analytics value.

Returning synthetic present values has more detection risk than reducing detail
to a common unavailable or nil state, because apps can compare several StoreKit
and Foundation surfaces. However, forcing nil/unavailable can visibly degrade
functionality. Per-app policy needs a compatibility path.

The safest mitigation is coherent reduction: either pass through, or model a
small account profile whose token presence, StoreKit country, locale, region,
currency, and account-change timing agree.

## Exclusion Note

No coarse hardware/model constants appear in Loupe's Apple Account provider, so
there are no hardware-style exclusions for this page.

Do not add generic "signed into Apple account" or "iCloud available" booleans as
separate mitigation targets unless a provider emits them. In this category,
those states are represented through the included `ubiquityToken.hash` present
or absent result and the included `storefront.country` available or unavailable
result.

## Relevance

Apple Account is relevant because it exposes account-tied state without a user
permission prompt. `ubiquityToken.hash` is a P0 research surface when present:
it can act as a durable equality marker beyond hardware and app-container
metadata. `storefront.country` is P1: it is lower-cardinality, but it anchors
account region and constrains locale, currency, purchase, and travel narratives.

Mitigation work should keep this category separate from hardware identity. The
right model is an account/profile layer that can pass through for compatibility
or reduce account observability coherently for strict privacy profiles.
