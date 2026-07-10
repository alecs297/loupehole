# `network.wifi_identity`

The Wi-Fi identity option replaces current-network SSID and BSSID reads with scoped synthetic values while preserving Apple's original visibility gate.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `network.wifi_identity` |
| Implemented mitigation | `network.wifi_identity.nehotspot.scoped` |
| Policy seeds | `network_wifi_ssid`, `network_wifi_bssid` |
| User-facing name | Wi-Fi identity |
| Status | Experimental |
| Surface | Network |
| Classification | Permission/entitlement-gated current Wi-Fi read; active hook mitigation |
| Affected APIs | `NEHotspotNetwork.SSID`, `NEHotspotNetwork.BSSID`, `NEHotspotNetwork.signalStrength`, `NEHotspotNetwork.securityType`, `CNCopyCurrentNetworkInfo` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | Does not bypass Access Wi-Fi Information, Location, Hotspot Helper, or NetworkExtension visibility gates |

## References

- Apple NetworkExtension: `NEHotspotNetwork`.
- Apple SystemConfiguration: `CNCopyCurrentNetworkInfo`.

## Surface and Relevance

SSID and BSSID reveal the currently joined Wi-Fi network and access point. The pair can identify a home, workplace, hotel, school, or router, and can be compared with local IP, interface, DNS, VPN, and Bonjour observations.

## Mitigation Strategy

The mitigation hooks current-network properties on `NEHotspotNetwork` and rewrites CaptiveNetwork dictionaries returned by `CNCopyCurrentNetworkInfo`.

It only rewrites values after the original API has already exposed a current network object or dictionary. If the platform returns `nil` or `NULL`, the mitigation preserves that denial or unavailable shape.

The synthetic SSID is a 12-character lowercase alphanumeric string. The synthetic BSSID is a valid locally administered unicast MAC-shaped value. Signal strength is normalized to a common mid-strength value when the original value is in the documented `[0, 1]` range, and security type is normalized to a common personal-network shape.

## Derivation and Lifetime

| Policy seed identifier | Meaning |
| --- | --- |
| `network_wifi_ssid` | Scoped synthetic current-network SSID |
| `network_wifi_bssid` | Scoped synthetic current-network BSSID |

Values are derived from active seed, scope, and policy seed. They rotate when active seed, scope, or policy seed changes.

## Impact and Tradeoffs

Accessory setup apps, hotspot helpers, enterprise Wi-Fi tools, diagnostics, and apps that verify the exact joined SSID may misbehave. This mitigation does not alter real routing, DNS, local network discovery, Wi-Fi association, or server-observed egress.

## Validation

Expected observations:

- `NEHotspotNetwork` SSID/BSSID getters return scoped synthetic values when a network is visible.
- `CNCopyCurrentNetworkInfo` dictionaries use matching `SSID`, `BSSID`, and `SSIDDATA` values.
- APIs that would originally return no current network still return no current network.

Device validation is required for entitlement-gated paths and deprecated CaptiveNetwork behavior on current SDKs.

## Rollback and Pass-Through

Disabling the module restores original current-network values. If the class, selector, symbol, or derivation path is unavailable, the module passes through or registers as a no-op.
