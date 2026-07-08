# Telephony Fingerprint Category

Upstream source: `.research/upstream/loupe/code/Loupe/Providers/TelephonyProvider.swift`

Loupe category: Telephony
Loupe tier: passive local cellular service state
Permission required: none for Loupe's collected CoreTelephony radio-access
technology and service-count values
Primary relevance: cellular capability, active SIM/eSIM count, current radio
technology, and network-profile coherence.

This category covers Loupe's current CoreTelephony read on iOS. The provider
counts entries in `serviceCurrentRadioAccessTechnology` and emits one radio
access technology value per active service. On non-iOS platforms, Loupe emits a
placeholder instead of cellular data.

## Official Links

- Apple CoreTelephony [`CTTelephonyNetworkInfo`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo)
- Apple CoreTelephony [`serviceCurrentRadioAccessTechnology`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/servicecurrentradioaccesstechnology)
- Apple CoreTelephony [Radio Access Technology Constants](https://developer.apple.com/documentation/coretelephony/radio-access-technology-constants)
- Apple CoreTelephony [`CTRadioAccessTechnologyNR`](https://developer.apple.com/documentation/coretelephony/ctradioaccesstechnologynr)
- Apple CoreTelephony [`CTRadioAccessTechnologyNRNSA`](https://developer.apple.com/documentation/coretelephony/ctradioaccesstechnologynrnsa)
- Apple CoreTelephony [`currentRadioAccessTechnology`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/currentradioaccesstechnology)
- Apple CoreTelephony [`serviceSubscriberCellularProviders`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/servicesubscribercellularproviders)
- Apple CoreTelephony [`RadioAccessTechnologyDidChangeMessage`](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/radioaccesstechnologydidchangemessage)

Loupe uses `serviceCurrentRadioAccessTechnology`, not the older single-service
`currentRadioAccessTechnology` property. The carrier/provider APIs are adjacent
surfaces, but the provider comment notes that carrier name is redacted on iOS
16+ while service count and radio technology remain visible.

## Loupe Signals and Decisions

| Loupe signal | Provider source | Platforms | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- | --- |
| `simCount` | If `CTTelephonyNetworkInfo().serviceCurrentRadioAccessTechnology` is non-nil, `radio.count`; otherwise `0` | iOS | None | Passive active cellular-service count | Include as a coarse summary | Medium. Dual SIM, eSIM, no-SIM, data-only, and inactive-service states narrow device and user context. |
| `rat.<index>` | Sorted `serviceCurrentRadioAccessTechnology` dictionary values, stripped of the `CTRadioAccessTechnology` prefix for display | iOS | None | Passive current radio access technology read | Include | Medium. LTE, 5G NR/NSA, WCDMA, Edge, GPRS, and related values reveal cellular capability, current network state, and mobility context. |
| service identifier prefix in card title | `entry.key.prefix(6)` from the sorted radio dictionary, used only in the localized display name | iOS | None | Passive service-identifier-derived label | Include as a UI leakage caveat | Low to medium. The signal key is `rat.<index>`, but the visible card title can expose a stable-looking service identifier prefix if exported or captured. |
| `unavailable` | Non-iOS placeholder: "Not available on macOS" | macOS | None | Platform placeholder | Exclude | Not a device fingerprint value. It only states that Loupe's CoreTelephony provider is unavailable on that platform. |

Loupe does not emit carrier name, mobile country code, mobile network code,
ISO country code, allows-VOIP, subscriber provider details, phone number, IMSI,
ICCID, or network measurements in this provider.

## Permission and Activity Classification

No included Telephony signal requires Contacts, Location, Bluetooth, Local
Network, Motion, Photos, Microphone, or another user-granted runtime permission.
The provider reads CoreTelephony state available to the app.

The category is passive in Loupe's collection path. It creates a
`CTTelephonyNetworkInfo` object and reads local service radio-technology state.
It does not scan cellular networks, initiate a call, query the carrier, send
traffic, or request Location permission.

The values are live state. Radio technology can change as the device moves
between 5G, LTE, 3G, no service, airplane mode, or Wi-Fi-only conditions. Loupe
collects a snapshot; an app could also subscribe to CoreTelephony change
messages as an adjacent active-observation path.

## Fingerprinting Value

`simCount` is coarse, but useful. A single active service is common on phones,
zero active services is common on Wi-Fi-only hardware or no-SIM conditions, and
two active services can reveal dual-SIM or eSIM use. That state can be stable
enough to help link sessions and should agree with device model capability.

Per-service radio technology adds context. LTE versus 5G NR/NSA can reveal
hardware generation, carrier deployment, plan capability, current coverage, and
mobility context. Older values such as WCDMA, Edge, or GPRS may be rare in some
regions and can narrow a network or travel state.

The sorted service map also leaks shape. Even if Loupe emits `rat.0` and
`rat.1`, the count and order reveal the number of active services. The card
title uses a prefix from the service identifier, so exported UI text or
screenshots may carry a small piece of the underlying service key.

Carrier name is not collected here and may be redacted on newer iOS versions,
but radio state still correlates with carrier and location signals. Network
path, IP geolocation, locale, time zone, device model, and Location-permission
results can all contradict a fake telephony profile.

## Mitigation Strategy Ideas

### `telephony.radio_profile`

Hook CoreTelephony radio state as a profile:

- `CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology`
- deprecated `currentRadioAccessTechnology` where apps still use it
- radio-access-technology change notifications and userInfo where practical
- adjacent service-provider APIs if a future policy covers carrier metadata

Compatibility default should pass through. Apps may use telephony state for
network quality decisions, carrier support flows, diagnostics, analytics,
fraud/risk scoring, or feature gating.

Strict mode can return a common cellular profile, such as one active service on
LTE or a cohort-appropriate 5G value, but only when the selected device profile
supports cellular. Wi-Fi-only iPads, Macs, simulators, and non-cellular devices
should not report active iPhone-style radio services.

### `telephony.service_count`

Treat service count and RAT entries as one tuple. If `simCount == 0`, there
should be no `rat.<index>` entries. If two RAT entries exist, `simCount` should
be `2`, the returned dictionary should have two service keys, and notification
payloads should match the same shape.

Strict privacy mode can normalize dual-SIM/eSIM state to a common single active
service, but this may conflict with visible cellular settings, carrier UI,
network behavior, or apps that know the device is dual-SIM capable.

### `telephony.carrier_metadata`

Carrier details are excluded from Loupe's current signals, but future coverage
should consider them as the same profile. If a mitigation later covers
`serviceSubscriberCellularProviders`, carrier country, MCC/MNC, or VOIP
capability, those fields must agree with radio technology, locale, time zone,
network path, and IP/cellular routing behavior.

Do not invent a carrier tuple independently from the radio profile. A 5G NR
radio state with an impossible carrier/region/device combination is more
fingerprintable than pass-through.

## Derivation Considerations

Telephony values should be generated from the hardware, region, carrier, and
network profile rather than from independent random choices. A coherent record
should contain:

```text
device class and cellular capability
SIM/eSIM service count
service identifier shape
radio access technology per active service
carrier/region metadata if covered
network path and cellular availability state
timeline for radio changes, airplane mode, and no-service events
```

Radio technology is live state. It should not rotate on every read. If a
profile models movement from LTE to 5G, or service loss and recovery, the event
should be plausible in time and should match Network framework path state,
expensive/constrained flags, IP addresses, and app-observed connectivity.

The service identifier keys in the returned dictionary should be opaque and
stable within a profile epoch. They should not expose readable mitigation names,
project strings, salts, or profile IDs. If the UI label uses a key prefix, that
prefix must be treated as observable output.

For non-iOS platforms, preserve the unavailable shape. Returning synthetic iOS
telephony values on macOS would create an obvious platform contradiction.

## Impact and Tradeoffs

Telephony spoofing can change app behavior. Apps may reduce media quality,
defer uploads, change onboarding, select carrier support content, flag fraud
risk, or diagnose connectivity based on radio and service count.

Normalizing dual-SIM/eSIM state can improve privacy but may conflict with apps
that expose line selection, messaging/calling workflows, or carrier-specific
support. Returning no service can also break network-quality assumptions when
the app is clearly online over cellular.

Partial spoofing is high risk. If `serviceCurrentRadioAccessTechnology` says
LTE but Network.framework reports no cellular interface, local IP state shows
Wi-Fi only, or the hardware profile is a Wi-Fi-only iPad, the synthetic profile
is easy to detect.

The safest default is pass-through, with strict normalization available only as
part of a coherent device/network/carrier profile.

## Exclusion Note

Loupe's Telephony provider excludes these adjacent surfaces:

- carrier name and subscriber-provider details
- MCC, MNC, ISO country code, and `allowsVOIP`
- phone number, IMSI, ICCID, line labels, and account identifiers
- signal strength, cell tower IDs, location-derived network measurements, and
  radio scans
- the non-iOS `unavailable` placeholder as a fingerprint value

`simCount` is a coarse, non-granular surface, but it is included because dual
SIM/eSIM and no-service state are meaningful context and must match the number
of RAT entries. Carrier metadata is excluded here because Loupe does not emit it
and newer iOS behavior may redact parts of it.

## Relevance

Telephony is a medium-priority passive-native category. It is strongest on
cellular iOS devices with dual-SIM/eSIM or uncommon radio states, and it is a
major coherence dependency for Network, Locale & Region, Device Identity, and
Location surfaces.

Mitigation should not be a standalone random RAT replacement. It belongs in a
coherent device/network profile, with pass-through as the default until that
profile can cover related APIs and live connectivity state.
