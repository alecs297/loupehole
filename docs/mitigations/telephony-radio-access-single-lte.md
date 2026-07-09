# `telephony.radio_access`

This option normalizes visible CoreTelephony radio access technology to one active LTE service when the original device already reports active cellular service.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `telephony.radio_access` |
| Implemented mitigation | `telephony.radio_access.coretelephony.single_lte` |
| Policy seeds | None |
| User-facing name | Radio access technology |
| Status | Experimental |
| Surface | Telephony |
| Classification | Passive cellular radio-state surface; active Objective-C hook mitigation |
| Affected APIs | `CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology`, `CTTelephonyNetworkInfo.currentRadioAccessTechnology` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None for Loupe's covered CoreTelephony radio state reads |

## References

- Apple Developer: [`CTTelephonyNetworkInfo`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo).
- Apple Developer: [`serviceCurrentRadioAccessTechnology`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/servicecurrentradioaccesstechnology).
- Apple Developer: [`currentRadioAccessTechnology`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/currentradioaccesstechnology).
- Apple Developer: [`CTRadioAccessTechnologyLTE`](https://developer.apple.com/documentation/coretelephony/ctradioaccesstechnologylte).

## Surface And Relevance

Service count and radio access technology expose no-SIM, single-SIM, dual-SIM/eSIM, LTE, 5G, 3G, and other network states. These values reveal cellular capability and current network context.

## Mitigation Strategy

The module hooks CoreTelephony radio getters:

- if `serviceCurrentRadioAccessTechnology` is nil or empty, it passes through to avoid reporting cellular service on no-service or non-cellular contexts;
- otherwise it returns one zero-shaped service key mapped to `CTRadioAccessTechnologyLTE`;
- if the deprecated `currentRadioAccessTechnology` originally returns a value, it returns LTE.

Carrier metadata and provider dictionaries are untouched.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifiers | None |
| Value shape | Single LTE radio-access string or one-entry service dictionary |
| Derivation input | Original CoreTelephony radio-access result |
| Storage behavior | No mitigation-owned state |
| Lifetime | Tracks whether the original API reports active service |
| Dependencies | Carrier metadata, interface state, and server-observed network context remain outside coverage |

No state or seed-derived value is used. Active service dictionaries collapse to a single common zero-shaped service identifier; nil and empty original dictionaries remain nil or empty.

## Impact And Tradeoffs

This can affect diagnostics, network-quality decisions, carrier support, analytics, and risk scoring. It intentionally avoids changing nil or empty original service state, but it can still conflict with Network.framework, visible cellular settings, hardware profile, IP routing, or server-side carrier observations.

Notifications, notification payloads, subscriber provider metadata, MCC/MNC, carrier names, signal strength, cell IDs, and cellular interface state are not covered.

## Validation

Expected observations after integration:

- active multi-service or 5G radio dictionaries collapse to one zero-key LTE entry;
- nil or empty original dictionaries remain nil or empty;
- the deprecated single-service getter reports LTE only when it originally reported a technology.

## Rollback And Pass-Through

If `CTTelephonyNetworkInfo` or both selectors are unavailable, the module registers as no-op. Disabling the mitigation restores original CoreTelephony radio-access reads.
