# `network.interface_inventory`

The interface inventory option shapes local interface disclosure across low-level interface lists, scoped proxy dictionaries, and Network.framework path/interface queries so apps see a coherent common network shape instead of precise tunnel names, local addresses, MAC-shaped link identifiers, and live interface usage counters.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `network.interface_inventory` |
| Implemented mitigation | `network.interface_inventory.composite.common` |
| Policy seeds | `network_interface_ipv4_host`, `network_interface_ipv6_suffix`, `network_interface_link_mac`, `network_interface_counter_profile`, `network_interface_name_alias` |
| User-facing name | Network interface inventory |
| Status | Experimental |
| Surface | Network |
| Classification | Passive local interface read; active imported-symbol mitigation |
| Affected APIs | Imported calls to `getifaddrs`, `if_nameindex`, `if_indextoname`, `if_nametoindex`, `CFNetworkCopySystemProxySettings`, `SCDynamicStoreCopyProxies`, `SCDynamicStoreCopyProxiesWithOptions`, `nw_path_enumerate_interfaces`, `nw_path_uses_interface_type`, `nw_interface_get_name`, `nw_interface_get_type`, `nw_path_is_expensive`, `nw_path_is_constrained` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None |

## Surface and Relevance

Interface rows, scoped proxy dictionaries, and path snapshots reveal local IPv4 and IPv6 addresses, link-layer identifiers, tunnel-like interface names, traffic counters, error counters, line speed, administrative-change time, path interface classes, and VPN-like proxy scopes. These values can identify a network, expose VPN posture, reveal Wi-Fi/cellular usage patterns, and contradict Wi-Fi, DNS, proxy, and telephony claims.

## Mitigation Strategy

The mitigation covers the BSD interface family through imported-symbol rebinding only. It leaves lists returned by `getifaddrs` and `if_nameindex` platform-owned, preserves their list shape, and does not hook either release function. On covered `getifaddrs` calls it rewrites non-loopback IPv4 addresses to `192.168.1.X`, rewrites IPv4 netmasks to `/24`, rewrites IPv4 broadcast/destination addresses to `192.168.1.255`, rewrites non-loopback IPv6 addresses to link-local-shaped `fe80::` values, clears tunnel-row IPv6 scope IDs that could format back into sensitive names, rewrites visible `AF_LINK` MAC bytes to locally administered unicast values, and shapes `struct if_data` counters in place. Sensitive tunnel rows remain in the raw list but lose `IFF_UP` and `IFF_RUNNING`; their `ifa_name`, `if_nameindex` name, `if_indextoname` result, and any embedded `sockaddr_dl` name are rewritten to the same scoped low-cardinality `en1` through `en3` alias. Direct sensitive-name probes through covered `if_nametoindex` imports report no matching interface. This avoids both precise tunnel-name disclosure and replacement allocations that unhooked release paths could not safely free.

The same sensitive-interface policy is applied to covered scoped proxy dictionaries returned by CFNetwork and SystemConfiguration: entries under `__SCOPED__` whose keys contain `tap`, `tun`, `utun`, `ppp`, or `ipsec` are removed while unrelated proxy keys are preserved. Covered Network.framework path enumeration suppresses `other` and loopback interfaces, `nw_path_uses_interface_type` returns false for those types, `nw_interface_get_name` reads of sensitive interfaces use the same `enN` alias, and `nw_interface_get_type` reads of those interfaces are normalized to Wi-Fi so virtual interface names and classes are not exposed as a separate local signal. `nw_path_is_expensive` and `nw_path_is_constrained` currently pass through because they describe route policy rather than a stable interface identifier.

The module does not patch process-wide C function entry points. Calls made directly inside system libraries or resolved dynamically with `dlsym` can pass through. Proxy-scope filtering and counter shaping are intentionally merged into this module so one mitigation owns the covered local interface disclosure lifecycle.

Non-loopback byte counters are generated from a per-interface seeded base and a seeded rate multiplied by current uptime since `kern.boottime`; packet counters are derived from the synthetic byte counts using seeded average packet sizes. Small error counters are reduced to tiny seeded values, collisions are cleared, non-loopback baud rates are normalized to common Wi-Fi/cellular-like values, and `ifi_lastchange` is aligned to the observed boot time.

## Derivation and Lifetime

| Policy seed identifier | Meaning |
| --- | --- |
| `network_interface_ipv4_host` | Per-interface host byte for `192.168.1.X` |
| `network_interface_ipv6_suffix` | Per-interface link-local suffix bytes |
| `network_interface_link_mac` | Per-interface locally administered MAC bytes |
| `network_interface_counter_profile` | Per-interface counter base, growth rate, packet-size profile, and small error-count profile |
| `network_interface_name_alias` | Scoped low-cardinality alias for sensitive interface names across BSD and Network.framework views |

The original interface name is used as derivation context before the public name is rewritten, so each visible interface receives stable scoped addresses, counter profiles, and a consistent common alias without reusing one value everywhere. Counter values require no persisted state; they grow as uptime advances. If alias derivation is unavailable, the sensitive name falls back to the common `en0` alias rather than exposing the original tunnel token.

## Impact and Tradeoffs

This can break diagnostics, local peer discovery, WebRTC, VPN status checks, exact data-usage displays, inverse name/index assumptions, and apps that bind sockets to the returned address or expect tunnel interfaces to be enumerable. It does not alter actual socket routing, DNS, routing-socket/sysctl interface inventories, NetworkExtension state, or server-observed network behavior.

## Validation

Expected observations:

- Non-loopback IPv4 addresses read through `getifaddrs` are in `192.168.1.20` through `192.168.1.199`.
- IPv4 broadcast/destination addresses are `192.168.1.255`.
- Non-loopback IPv6 addresses read through `getifaddrs` are link-local-shaped.
- Sensitive IPv6 rows have no scope ID that can resolve back to a tunnel name.
- `AF_LINK` MAC bytes are locally administered unicast values when visible.
- Tunnel-like `tap`/`tun`/`utun`/`ppp`/`ipsec` rows retain platform ownership and list position, but covered `getifaddrs` calls report them under a common `enN` alias, including the `AF_LINK` embedded name, without `IFF_UP` or `IFF_RUNNING`, and with shaped address/counter data.
- Covered `if_nameindex` and `if_indextoname` calls use the same alias, while direct `if_nametoindex` probes for a sensitive original name fail as if that interface were absent.
- `ifi_ibytes` and `ifi_obytes` grow over time from a seeded per-interface profile.
- Packet counters follow the synthetic byte counters, small error counters are low seeded values, and non-loopback `ifi_baudrate` values are common coarse rates.
- `CFNetworkCopySystemProxySettings` and SystemConfiguration proxy-copy results omit `__SCOPED__` keys containing `tap`, `tun`, `utun`, `ppp`, or `ipsec`.
- Network.framework interface enumeration omits `other` and loopback path interfaces, `nw_interface_get_name` uses the same scoped alias for a sensitive original name, and `nw_path_uses_interface_type` returns false for those types.

Device validation is required for framework wrappers that call other interface inventory paths, dynamically resolved symbols, routing-socket/sysctl or ioctl inventory, apps that use `if_data64` / non-`getifaddrs` counter paths, and private Network.framework entry points not covered by the public C symbols listed above.

## Rollback and Pass-Through

Disabling the module restores original `getifaddrs` names and values, original BSD name/index results, original `ifa_data`, original scoped proxy dictionaries, and original Network.framework path/interface accessors. Original errors pass through. Uncovered direct/internal calls retain platform behavior and ownership. If no imported call site can be rebound, the module registers as a no-op.
