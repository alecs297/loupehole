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
| Affected APIs | Imported calls to `getifaddrs`, read-only `sysctl` / `__sysctl` route/interface queries described below, `if_nameindex`, `if_indextoname`, `if_nametoindex`, `CFNetworkCopySystemProxySettings`, `SCDynamicStoreCopyProxies`, `SCDynamicStoreCopyProxiesWithOptions`, `nw_path_enumerate_interfaces`, `nw_path_uses_interface_type`, `nw_interface_get_name`, `nw_interface_get_type`, `nw_path_is_expensive`, `nw_path_is_constrained` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None |

## Surface and Relevance

Interface rows, scoped proxy dictionaries, and path snapshots reveal local IPv4 and IPv6 addresses, link-layer identifiers, tunnel-like interface names, traffic counters, error counters, line speed, administrative-change time, path interface classes, and VPN-like proxy scopes. These values can identify a network, expose VPN posture, reveal Wi-Fi/cellular usage patterns, and contradict Wi-Fi, DNS, proxy, and telephony claims.

## Mitigation Strategy

The mitigation covers the BSD interface family through imported-symbol rebinding only. It leaves lists returned by `getifaddrs` and `if_nameindex` platform-owned, preserves their list shape, and does not hook either release function. On covered `getifaddrs` calls it rewrites non-loopback IPv4 addresses to `192.168.1.X`, rewrites IPv4 netmasks to `/24`, rewrites IPv4 broadcast/destination addresses to `192.168.1.255`, rewrites non-loopback IPv6 addresses to link-local-shaped `fe80::` values, clears tunnel-row IPv6 scope IDs that could format back into sensitive names, rewrites visible `AF_LINK` MAC bytes to locally administered unicast values, and shapes `struct if_data` counters in place. Sensitive tunnel rows remain in the raw list but lose `IFF_UP` and `IFF_RUNNING`; their `ifa_name`, `if_nameindex` name, `if_indextoname` result, and any embedded `sockaddr_dl` name are rewritten to the same scoped low-cardinality `en1` through `en3` alias. Direct sensitive-name probes through covered `if_nametoindex` imports report no matching interface. This avoids both precise tunnel-name disclosure and replacement allocations that unhooked release paths could not safely free.

The same sensitive-interface policy is applied to covered scoped proxy dictionaries returned by CFNetwork and SystemConfiguration: entries under `__SCOPED__` whose keys contain `tap`, `tun`, `utun`, `ppp`, or `ipsec` are removed while unrelated proxy keys are preserved. Covered Network.framework path enumeration suppresses `other` and loopback interfaces, `nw_path_uses_interface_type` returns false for those types, `nw_interface_get_name` reads of sensitive interfaces use the same `enN` alias, and `nw_interface_get_type` reads of those interfaces are normalized to Wi-Fi so virtual interface names and classes are not exposed as a separate local signal. `nw_path_is_expensive` and `nw_path_is_constrained` currently pass through because they describe route policy rather than a stable interface identifier.

The module does not patch process-wide C function entry points. Calls made directly inside system libraries or resolved dynamically with `dlsym` can pass through. Proxy-scope filtering and counter shaping are intentionally merged into this module so one mitigation owns the covered local interface disclosure lifecycle.

### Data Consumption

Non-loopback byte counters use one mitigation-owned 64-bit model per original interface name. A seeded base of 16 to less than 256 MiB grows at 64-512 bytes/second, with fractional-second growth and small upward steps every five minutes. Packet counts follow those byte counts using seeded average packet sizes. Errors and drops are tiny seeded values; collisions and receive/transmit timing are cleared. Nonzero line speeds become common Wi-Fi/cellular-like values, while MTU, interface type, and hardware capabilities are not invented.

The same model shapes `getifaddrs`' `struct if_data`, `NET_RT_IFLIST`'s `RTM_IFINFO`, and `NET_RT_IFLIST2`'s `RTM_IFINFO2` / `struct if_data64`. The covered MIB is `CTL_NET, PF_ROUTE, 0, family, query, index`, with family zero, IPv4, IPv6, or link and either interface-list query. Kernel family/index filtering is preserved. Multiple `en*` or `pdp_ip*` rows remain distinct, so an app can aggregate its usual Wi-Fi/cellular rows without learning genuine usage. The 32-bit view reports the low 32 bits of the full model, including natural rollover; it no longer saturates at `UINT32_MAX`. A caller that subtracts billing baselines without handling resets or rollover can still show an invalid total.

One clock snapshot is used for each list/dump. Elapsed time is wall time minus the observed `kern.boottime`; when the boot-time mitigation's hook is reached, that is its synthetic timeline. `ifi_lastchange` uses that same observed boot time. This is not a monotonic-clock guarantee: reboot, clock changes, scope/seed changes, and newly enabling protection can invalidate app-owned baselines. Loupehole neither reads nor edits those saved baselines. The synthetic rate does not describe real throughput and can understate speed-test traffic.

Raw list shaping stages the complete dump and only commits a validated result. It retains lengths, indexes, row order, multicast membership, and ownership. Local addresses, masks, broadcast addresses, names, MAC bytes, and interface flags follow the existing `getifaddrs` policy; address-message flags are preserved. Thread-local guards prevent an original `getifaddrs` implementation or a nested public/private sysctl path from shaping a list twice, especially after a tunnel name has been aliased. The route adapter has the same public/private nesting protection.

### Gateway Observations

Read-only IPv4/IPv6 `NET_RT_FLAGS` queries selecting `RTF_GATEWAY`, and `NET_RT_DUMP` / `NET_RT_DUMP2`, have a bounded route-message adapter. Supported IPv4 gateways become `192.168.1.1`; supported link-local IPv6 gateways become `fe80::1`. Local interface addresses, embedded names, and MAC bytes use the same original-name policy seeds as the interface lists. Sensitive tunnel scope identifiers are removed only within these covered address shapes. Length-only probes, message/header lengths, flags, indexes, errors, destinations, and netmasks are preserved.

This is not a reconstructed routing topology. `AF_LINK` gateway routes, global IPv6 gateways, unsupported messages, and malformed dumps pass through. Destination/netmask topology can still expose real prefixes and disagree with the shaped local subnet. No routing socket, route mutation, socket binding, or actual packet destination is changed. DNS resolver inventory remains untreated.

## Derivation and Lifetime

| Policy seed identifier | Meaning |
| --- | --- |
| `network_interface_ipv4_host` | Per-interface host byte for `192.168.1.X` |
| `network_interface_ipv6_suffix` | Per-interface link-local suffix bytes |
| `network_interface_link_mac` | Per-interface locally administered MAC bytes |
| `network_interface_counter_profile` | Per-interface counter base, growth rate, packet-size profile, and small error-count profile |
| `network_interface_name_alias` | Scoped low-cardinality alias for sensitive interface names across BSD and Network.framework views |

The original interface name is used as derivation context before the public name is rewritten, so each visible interface receives stable scoped addresses, counter profiles, and a consistent common alias without reusing one value everywhere. Counter values require no persisted state. If alias derivation is unavailable, the sensitive name falls back to the common `en0` alias rather than exposing the original tunnel token.

`InterfaceTrafficValues.c` owns the counter seed and shared 32/64-bit calculation; `InterfaceTrafficMitigation.c` owns raw interface parsing and the nesting guard; `RoutingTableMitigation.c` owns route parsing and uses the interface module's address/name/MAC seed declarations. These helpers stay inside this mitigation. Dependencies are Darwin interface/route ABIs, generated seed bytes, the active seed/scope, BSD clock reads, and the imported-symbol backend. The only retained state is the runtime policy, original function pointers, and transient nesting depth. There is no central value resolver or cross-mitigation state registry.

## Impact and Tradeoffs

This can break diagnostics, local peer discovery, WebRTC, VPN status checks, exact data-usage displays, inverse name/index assumptions, and apps that bind sockets to the returned address or expect tunnel interfaces to be enumerable. It does not alter actual socket routing, DNS, routing-socket/ioctl inventory, NetworkExtension state, or server-observed network behavior. Cellular traffic rows are not mapped to CoreTelephony service identifiers: multiple `pdp_ip*` interfaces do not prove multiple active SIMs, so traffic aggregation is not collapsed to the telephony module's one-service view.

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
- Supported raw interface dumps agree with the low-level list at the same clock snapshot; the 32-bit value equals the low 32 bits of the corresponding 64-bit value, including across rollover.
- Covered IPv4 and link-local IPv6 gateway observations use the common gateway and compatible local interface values, without modifying real routing.
- Packet counters follow the synthetic byte counters, small error counters are low seeded values, and non-loopback `ifi_baudrate` values are common coarse rates.
- `CFNetworkCopySystemProxySettings` and SystemConfiguration proxy-copy results omit `__SCOPED__` keys containing `tap`, `tun`, `utun`, `ppp`, or `ipsec`.
- Network.framework interface enumeration omits `other` and loopback path interfaces, `nw_interface_get_name` uses the same scoped alias for a sensitive original name, and `nw_path_uses_interface_type` returns false for those types.

Run `make interface-traffic-check routing-table-check` with the default selection. Darwin-host sanitizer fixtures exercise aggregation, fractional growth, rollover, list ownership, compressed masks, shared address/name/MAC derivation, nesting, route layouts, and malformed/truncated pass-through. The traffic check additionally installs the actual module through the actual backend in classic and chained native executables, comparing live `getifaddrs` and raw 32/64-bit counters with the shared model while freeing the platform-owned lists normally. `make imported-symbol-check` separately checks delivery and composition. These checks do not establish iOS injection or the supplied binary's behavior.

Device validation is required for SDK/framework wrappers, modern import formats, direct/dynamically resolved calls, billing baselines, subsecond speed-test intervals, Wi-Fi/cellular/VPN transitions, actual supported route layouts, routing-socket/ioctl inventory, and private Network.framework entry points. Unsupported raw layouts are deliberately uncovered.

## Rollback and Pass-Through

Disabling the module restores original interface/gateway reads, BSD name/index results, scoped proxy dictionaries, and Network.framework accessors on the next uninjected launch. Original errors and length-only queries pass through. Unsupported/malformed raw dumps or failed allocation, clock reads, and counter derivation leave the raw result unchanged. On `getifaddrs`, failed counter derivation preserves counters while independent address/name shaping may still apply. Uncovered direct/internal calls retain platform behavior and ownership. If no imported call site can be rebound, the module registers as a no-op. Changing protection or upgrading from the old saturated counter behavior can invalidate existing app baselines; disabling does not repair those app-owned values.
