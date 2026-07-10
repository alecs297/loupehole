# `network.interface_inventory`

The interface inventory option shapes local interface disclosure across low-level interface lists, scoped proxy dictionaries, and Network.framework path/interface queries so apps see a coherent common network shape instead of precise tunnel names, local addresses, MAC-shaped link identifiers, and live interface usage counters.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `network.interface_inventory` |
| Implemented mitigation | `network.interface_inventory.composite.common` |
| Policy seeds | `network_interface_ipv4_host`, `network_interface_ipv6_suffix`, `network_interface_link_mac`, `network_interface_counter_profile` |
| User-facing name | Network interface inventory |
| Status | Experimental |
| Surface | Network |
| Classification | Passive local interface read; active C hook mitigation |
| Affected APIs | `getifaddrs`, `freeifaddrs`, `CFNetworkCopySystemProxySettings`, `SCDynamicStoreCopyProxies`, `SCDynamicStoreCopyProxiesWithOptions`, `nw_path_enumerate_interfaces`, `nw_path_uses_interface_type`, `nw_interface_get_name`, `nw_interface_get_type`, `nw_path_is_expensive`, `nw_path_is_constrained` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None |

## Surface and Relevance

Interface rows, scoped proxy dictionaries, and path snapshots reveal local IPv4 and IPv6 addresses, link-layer identifiers, tunnel-like interface names, traffic counters, error counters, line speed, administrative-change time, path interface classes, and VPN-like proxy scopes. These values can identify a network, expose VPN posture, reveal Wi-Fi/cellular usage patterns, and contradict Wi-Fi, DNS, proxy, and telephony claims.

## Mitigation Strategy

The mitigation hooks `getifaddrs`/`freeifaddrs` directly and through imported-symbol rebinding. On success it filters sensitive tunnel rows out of the returned list, rewrites non-loopback IPv4 addresses to `192.168.1.X`, rewrites IPv4 netmasks to `/24`, rewrites IPv4 broadcast/destination addresses to `192.168.1.255`, rewrites non-loopback IPv6 addresses to link-local-shaped `fe80::` values, rewrites visible `AF_LINK` MAC bytes to locally administered unicast values, and shapes `struct if_data` counters in the same returned list.

The same sensitive-interface policy is applied to scoped proxy dictionaries returned by CFNetwork and SystemConfiguration: entries under `__SCOPED__` whose keys contain `tap`, `tun`, `utun`, `ppp`, or `ipsec` are removed while unrelated proxy keys are preserved. Network.framework path enumeration suppresses `other` and loopback interfaces, `nw_path_uses_interface_type` returns false for those types, direct `nw_interface_get_name` reads of sensitive or virtual interfaces return common names such as `en0`, and direct `nw_interface_get_type` reads of those interfaces are normalized to Wi-Fi so virtual interface names and classes are not exposed as a separate local signal. `nw_path_is_expensive` and `nw_path_is_constrained` currently pass through because they describe route policy rather than a stable interface identifier.

Interfaces whose names begin with `tap`, `tun`, `utun`, `ppp`, or `ipsec` are removed from cloned lists returned to target apps. Proxy-scope filtering and counter shaping are intentionally merged into this module so one mitigation owns the local interface disclosure lifecycle. This is stricter than the compatibility default documented in the surface inventory and assumes system apps are not injected.

Non-loopback byte counters are generated from a per-interface seeded base and a seeded rate multiplied by current uptime since `kern.boottime`; packet counters are derived from the synthetic byte counts using seeded average packet sizes. Small error counters are reduced to tiny seeded values, collisions are cleared, non-loopback baud rates are normalized to common Wi-Fi/cellular-like values, and `ifi_lastchange` is aligned to the observed boot time.

## Derivation and Lifetime

| Policy seed identifier | Meaning |
| --- | --- |
| `network_interface_ipv4_host` | Per-interface host byte for `192.168.1.X` |
| `network_interface_ipv6_suffix` | Per-interface link-local suffix bytes |
| `network_interface_link_mac` | Per-interface locally administered MAC bytes |
| `network_interface_counter_profile` | Per-interface counter base, growth rate, packet-size profile, and small error-count profile |

The interface name is used as derivation context, so each visible interface receives stable scoped addresses and counter profiles without reusing one value everywhere. Counter values require no persisted state; they grow as uptime advances.

## Impact and Tradeoffs

This can break diagnostics, local peer discovery, WebRTC, VPN status checks, exact data-usage displays, and apps that bind sockets to the returned address or expect tunnel interfaces to be enumerable. It does not alter actual socket routing, DNS, routing-socket/sysctl interface inventories, NetworkExtension state, or server-observed network behavior.

## Validation

Expected observations:

- Non-loopback IPv4 addresses read through `getifaddrs` are in `192.168.1.20` through `192.168.1.199`.
- IPv4 broadcast/destination addresses are `192.168.1.255`.
- Non-loopback IPv6 addresses read through `getifaddrs` are link-local-shaped.
- `AF_LINK` MAC bytes are locally administered unicast values when visible.
- Tunnel-like `tap`/`tun`/`utun`/`ppp`/`ipsec` rows are absent from the returned `getifaddrs` list.
- `ifi_ibytes` and `ifi_obytes` grow over time from a seeded per-interface profile.
- Packet counters follow the synthetic byte counters, small error counters are low seeded values, and non-loopback `ifi_baudrate` values are common coarse rates.
- `CFNetworkCopySystemProxySettings` and SystemConfiguration proxy-copy results omit `__SCOPED__` keys containing `tap`, `tun`, `utun`, `ppp`, or `ipsec`.
- Network.framework interface enumeration omits `other` and loopback path interfaces, `nw_interface_get_name` does not expose tunnel-like names, and `nw_path_uses_interface_type` returns false for those types.

Device validation is required for framework wrappers that call other interface inventory paths, apps that use `if_data64` / non-`getifaddrs` counter paths, and private Network.framework entry points not covered by the public C symbols listed above.

## Rollback and Pass-Through

Disabling the module restores original `getifaddrs` output, original `ifa_data` values, original scoped proxy dictionaries, and original Network.framework path/interface accessors. Original errors pass through. If no hook can be installed, the module registers as a no-op.
