# `telephony.radio_access`

This option reduces the passive CoreTelephony service inventory to one common service identifier, normalizes an originally available radio technology to LTE, and redacts available carrier metadata. It preserves original unavailable, empty, and already-redacted values rather than inventing a carrier or cellular connection.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `telephony.radio_access` |
| Implemented mitigation | `telephony.radio_access.coretelephony.single_lte` |
| Policy seeds | None; fixed normalization and redaction, with no derived identity |
| User-facing name | Cellular service information |
| Status | Experimental |
| Surface | Telephony |
| Classification | Passive service inventory, carrier metadata, and radio-state surface; Objective-C getter and provider-notifier setter hooks |
| Affected APIs | `CTTelephonyNetworkInfo.dataServiceIdentifier`, `serviceSubscriberCellularProviders`, `subscriberCellularProvider`, `serviceCurrentRadioAccessTechnology`, `currentRadioAccessTechnology`, both subscriber-provider notifier setters; `CTCarrier.carrierName`, `isoCountryCode`, `mobileCountryCode`, `mobileNetworkCode` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None for Loupe's covered CoreTelephony radio state reads |

## References

- Apple Developer: [`CTTelephonyNetworkInfo`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo).
- Apple Developer: [`serviceCurrentRadioAccessTechnology`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/servicecurrentradioaccesstechnology).
- Apple Developer: [`currentRadioAccessTechnology`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/currentradioaccesstechnology).
- Apple Developer: [`CTRadioAccessTechnologyLTE`](https://developer.apple.com/documentation/coretelephony/ctradioaccesstechnologylte).
- Apple Developer: [`dataServiceIdentifier`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/dataserviceidentifier).
- Apple Developer: [`serviceSubscriberCellularProviders`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/servicesubscribercellularproviders).
- Apple Developer: [`CTCarrier`](https://developer.apple.com/documentation/coretelephony/ctcarrier). The SDK header documents `--` for carrier/country strings and `65535` for MCC/MNC as the deprecated APIs' redaction values.
- Apple Developer: [`serviceSubscriberCellularProvidersDidUpdateNotifier`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/servicesubscribercellularprovidersdidupdatenotifier) and [`subscriberCellularProviderDidUpdateNotifier`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/subscribercellularproviderdidupdatenotifier).
- Apple Developer: [`CTServiceRadioAccessTechnologyDidChangeNotification`](https://developer.apple.com/documentation/coretelephony/ctserviceradioaccesstechnologydidchangenotification) and [`dataServiceIdentifierDidChange(_:)`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfodelegate/dataserviceidentifierdidchange(_:)). These identifier-bearing delivery paths remain outside hook coverage.

## Surface And Relevance

Service identifiers and dictionary counts expose SIM inventory and active data-service selection. Radio technology reveals current network context, while carrier name, ISO country, MCC, and MNC can reveal carrier and regional affiliation on systems where those fields remain available. Apps can cross-check these views by indexing both dictionaries with `dataServiceIdentifier`; changing only radio dictionary keys breaks that lookup.

## Mitigation Strategy

The getter hooks read the original service identifier, provider dictionary, and radio dictionary through an exception-safe internal-read guard. Internal CoreTelephony getter calls continue to see real service keys. Each app-facing read selects the original active data service when its identifier is available. Without an identifier, it selects a deterministically sorted key shared by the nonempty dictionaries, preferring a service with an available radio technology. This fallback does not create a data-service identifier when the original is nil or empty.

When the original views support that selection:

- the nonempty provider and radio dictionaries each expose only `0000000000000000`, hiding their original counts and keys;
- an originally available `dataServiceIdentifier` becomes that same key;
- the selected radio technology becomes LTE only if its original value is a nonempty, non-redacted string; empty and placeholder values remain unchanged;
- the legacy radio getter becomes LTE when it originally reports a technology and the modern selected service also reports an available technology; older systems without modern service selectors retain legacy-only normalization;
- the legacy provider getter selects the same original carrier object as the modern dictionary when both carriers have compatible metadata availability. Nil, empty, and redacted field shapes must agree; otherwise it keeps the original legacy carrier.

Nil and empty dictionaries remain exactly nil or empty independently of one another, without querying sibling getters for those already-unavailable primary results. A provisioned provider can still be reported while the radio dictionary is empty; this does not create an active radio. Invalid dictionaries, unexpected values, a missing active-service key, and inconsistent nonempty dictionary keys pass through together rather than selecting an unrelated SIM. An exception from an additional coherence read causes the successful primary getter to pass through; exceptions from the primary original call still propagate. Original sampling is not atomic across telephony transitions, so coherence is bounded to compatible original snapshots.

The four carrier getters redact nonempty available strings to `--` for carrier name and ISO country, and `65535` for MCC and MNC. Each original nil, empty, or existing placeholder string passes through unchanged. The module retains original `CTCarrier` objects and does not synthesize a random carrier/region tuple. `allowsVOIP` remains unchanged.

The two public provider-notifier setters install copied block wrappers. The service notifier maps an available callback identifier to the common key only when the current original service views support normalization. The legacy notifier selects a compatible active carrier using the same rule as the legacy getter; carrier getter redaction also applies to retained carrier objects. Wrappers preserve callback delivery count and execute on the framework's original queue. They do not schedule or fabricate callbacks, retain the telephony receiver, or replace nil payloads with a service.

Notifier getters continue to expose the installed copied wrapper, allowing both framework-internal getter dispatch and app-invoked blocks to use normalized payloads. Assigning that getter result back to the same property reuses the wrapper. Replacement installs a new copied block, nil clears the callback and mitigation association, and a throwing setter leaves the previous association in place. As with the native nonatomic properties, concurrent assignments are not made atomic by this mitigation. Notifiers already installed before injection are not retroactively wrapped.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifiers | None |
| Value shape | One common service key, original provider objects, LTE for available radio values, and Apple's carrier redaction strings |
| Derivation input | Compatible original CoreTelephony service and carrier reads; no randomness or seed-derived values |
| Helper/state owner | `src/mitigations/telephony/radio_access/TelephonyRadioProfileMitigation.m`; local selection/redaction helpers, thread-local original-read guard, and per-receiver notifier-wrapper associations |
| Storage behavior | No persisted state or cached telephony snapshot; associated copied wrappers hold a weak receiver reference |
| Lifetime | Reads track original provisioning and radio availability; callbacks live until replacement, clearing, or receiver destruction |
| Scope | Common normalization in all scope modes; no new identity or scope level |
| Dependencies | Modern service normalization requires successful hooks for both dictionaries and, when present, the data identifier; metadata redaction requires all four carrier getter hooks |

There are no `LH_POLICY_SEED` declarations or mitigationkit derivation helpers because this option reduces values to common fixed forms. It does not derive a replacement identifier from a policy seed alone, add a central profile, or share telephony state with other mitigations. Interface presence, traffic counters, routing, and server-observed carrier context remain separate surfaces; original no-service and transport availability remain the coherence boundary between them.

## Impact And Tradeoffs

This can affect diagnostics, network-quality decisions, carrier support, analytics, and risk scoring. A single common service key hides additional subscriptions and radio diversity. Redaction prevents apps from making carrier or country decisions from the covered getters. It can still conflict with Network.framework, visible cellular settings, hardware profile, IP routing, or server-side carrier observations. Nil and empty carrier fields retain availability information by design. Already-redacted modern SDK results receive no invented replacement identity.

The provider callbacks are bounded to the public `CTTelephonyNetworkInfo` block properties. The module does not intercept the process-wide notification center, private CoreTelephony emitters, `delegate`, or `setDelegate:`. `CTServiceRadioAccessTechnologyDidChangeNotification.object` and `dataServiceIdentifierDidChange:` therefore still carry real service identifiers. Directly indexing a normalized dictionary with those raw identifiers can fail; consumers that re-read `dataServiceIdentifier` receive the normalized current key. Legacy RAT notifications have no service-identifier payload to rewrite, but their timing and frequency remain original.

A delegate proxy would alter weak delegate identity and lifetime semantics; returning the app delegate from a hooked getter could also let framework-internal dispatch bypass the proxy. A safe public interception preserving those contracts has not been established. Notification and delegate identifier delivery remain a documented privacy and compatibility gap, not claimed coverage. KVO/private carrier storage, private signal strength and cell IDs, cellular interfaces, and independent carrier observations also remain uncovered.

## Validation

Expected observations after integration:

- An active dual-service/5G device exposes one common key in both covered dictionaries, and `dataServiceIdentifier` indexes each successfully.
- Changing the original active data service changes the selected original carrier without exposing a different synthetic identifier.
- Nil and empty dictionaries, radio strings, identifiers, and carrier fields remain nil or empty; an empty selected radio value never becomes LTE.
- Available carrier strings use common redaction values; already-redacted fields retain their exact placeholders.
- Provider notifier payloads agree with the current normalized getters, including when the framework obtains the callback through its public getter. Nil clearing, replacement, and getter-to-setter reassignment retain their documented behavior.
- Original getters that call other hooked getters still see real keys internally; exceptions unwind the original-read guard.
- Incompatible service dictionaries and partial installation pass through the affected coherence group.
- Direct identifier-bearing RAT notification and delegate consumers still expose the documented gap.

Focused verification:

```sh
sh src/scripts/verify/verify_telephony_coherence.sh
```

The host verifier uses fixture `CTTelephonyNetworkInfo` and `CTCarrier` classes with method replacement to exercise getter relationships, callback dispatch, weak receiver lifetime, preserved shapes, exceptions, and incomplete hook installation. It also syntax-checks the source against the installed iOS SDK for arm64/iOS 15. These checks pass locally; they do not confirm device behavior, real notification sequences, or CoreTelephony's private implementation. Integration still requires the normal `make audit`, `make package`, and on-device checks, especially dual-SIM switching, SIM removal, airplane mode, and SDK-dependent carrier redaction.

## Rollback And Pass-Through

Selectors are checked for actual method availability before installation. If the modern dictionary/identifier hook group cannot be installed completely, its replacements pass through; on modern systems the legacy RAT also passes through in that case. If any of the four carrier getters cannot be hooked, all installed carrier-field replacements pass through and the legacy carrier selection remains original. Each notifier setter wraps only when its corresponding normalization group is enabled. Original nil results, unexpected shapes, missing original implementations, and incompatible snapshots retain the documented fallback.

If no hook can install, the module registers as no-op. Disabling the option before runtime installation leaves CoreTelephony behavior original; removing the runtime requires restarting the host process. This implementation does not dynamically remove installed wrappers or hooks from a running process.
