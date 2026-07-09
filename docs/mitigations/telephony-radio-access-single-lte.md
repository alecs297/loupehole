# `telephony.radio_access`

This option normalizes visible CoreTelephony radio access technology to one active LTE service when the original device already reports active cellular service.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `telephony.radio_access` |
| Implemented mitigation | `telephony.radio_access.coretelephony.single_lte` |
| Policy seeds | `telephony_radio_service_identifier` |
| Status | Experimental |
| Surface | Telephony |
| Affected APIs | `CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology`, `CTTelephonyNetworkInfo.currentRadioAccessTechnology` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None for Loupe's covered CoreTelephony radio state reads |

## Surface And Relevance

Service count and radio access technology expose no-SIM, single-SIM, dual-SIM/eSIM, LTE, 5G, 3G, and other network states. These values reveal cellular capability and current network context.

## Mitigation Strategy

The module hooks CoreTelephony radio getters:

- if `serviceCurrentRadioAccessTechnology` is nil or empty, it passes through to avoid reporting cellular service on no-service or non-cellular contexts;
- otherwise it returns one scoped opaque service key mapped to `CTRadioAccessTechnologyLTE`;
- if the deprecated `currentRadioAccessTechnology` originally returns a value, it returns LTE.

Carrier metadata and provider dictionaries are untouched.

## Derivation And Lifetime

`LH_POLICY_SEED(telephony_radio_service_identifier)` derives a 16-character lowercase hex service key with `LHMitigationDeriveASCIIString`. The key is stable until active seed, scope, or policy seed changes. No state blob is used.

## Impact And Gaps

This can affect diagnostics, network-quality decisions, carrier support, analytics, and risk scoring. It intentionally avoids changing nil or empty original service state, but it can still conflict with Network.framework, visible cellular settings, hardware profile, IP routing, or server-side carrier observations.

Notifications, notification payloads, subscriber provider metadata, MCC/MNC, carrier names, signal strength, cell IDs, and cellular interface state are not covered.

## Validation

Expected observations after integration:

- active multi-service or 5G radio dictionaries collapse to one LTE entry;
- nil or empty original dictionaries remain nil or empty;
- the deprecated single-service getter reports LTE only when it originally reported a technology.

## Rollback And Pass-Through

If `CTTelephonyNetworkInfo` or both selectors are unavailable, the module registers as no-op. If service-key derivation fails, the service dictionary passes through unchanged.
