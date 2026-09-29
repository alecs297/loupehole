# Network Traffic Accounting

Source reviewed: supplied device-information binary analysis, data-consumption,
speed-test, SDK utilization, and gateway collector paths; Apple Libinfo and XNU.
This extends Network research rather than describing a Loupe provider.

Loupe category: Network (binary-analysis extension)
Loupe tier: passive systemwide interface accounting; active speed-test sampling
Permission required: None for the analyzed local counter reads; OS/sandbox
availability varies
Primary relevance: Wi-Fi/cellular usage history, workload correlation, local
gateway identity, and cross-API consistency.

The counter surface includes cumulative interface bytes, packets, and adjacent
error/timing fields. It is not per-process network accounting, a billing API,
or a measure of actual network throughput after mitigation. Gateway inspection
is adjacent network-identity research; actual routing remains functional state.

## Official Links

- Apple [getifaddrs implementation](https://github.com/apple-oss-distributions/Libinfo/blob/main/gen.subproj/getifaddrs.c)
- Apple [interface counter layouts](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/net/if.h)
- Apple [routing message ABI](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/net/route.h)
- Apple [interface-list and route sysctl output](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/net/rtsock.c)
- Apple [getifaddrs manual](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getifaddrs.3.html)

These sources explain Darwin semantics. They do not establish every target-iOS
layout, SDK wrapper path, or injected hook's reachability.

## Binary-Analysis Signals and Decisions

| Signal | Collector source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| Wi-Fi bytes | `getifaddrs`, `AF_LINK`, sum `en*` receive/transmit counters | None | Passive cumulative interface state | Include | Systemwide usage history, not just this app's traffic. |
| Cellular bytes | Same path, sum all matching `pdp_ip*` rows | None | Passive cumulative interface state | Include | Usage history across multiple logical cellular interfaces. |
| Billing-period totals | App saves a counter baseline and subtracts it later | None | Durable app-owned derived state | Include as a lifecycle constraint | Reboot, rollover, policy changes, or stale baselines can produce invalid deltas. |
| Speed-test deltas | Repeated counter reads around an active test | No prompt for counter reads | Active traffic plus passive sampling | Include as a compatibility constraint | Synthetic counter growth does not describe test throughput. |
| SDK network utilization | Analyzed SDK sums the same interface family | None | Passive SDK collection | Include | Confirms the need to cover common API semantics, not a collector-specific caller. |
| Raw 32/64-bit counters | Adjacent `NET_RT_IFLIST` / `NET_RT_IFLIST2`; not established as direct calls in the binary | Availability varies | Passive lower-level accounting | Include as a cross-check | Can bypass `getifaddrs`-only shaping and expose width inconsistencies. |
| Gateway addresses | Two-stage `CTL_NET/PF_ROUTE/AF_INET/NET_RT_FLAGS/RTF_GATEWAY` dump and parse | None for the analyzed read | Passive route inventory | Include | Local router identity; must be compared with local addresses and DNS. |

## Permission and Collection Class

Reading local interface counters does not itself browse the LAN or require
Local Network permission. The speed-test feature may send real traffic, but
its local accounting read is a separate passive operation. No target binary
or on-device run was supplied to validate the analysis dynamically.

## Fingerprinting Value

Exact cumulative totals expose activity from other apps and prior sessions.
Counter deltas disclose current workload, while interface names and the
presence of multiple rows add topology context. `pdp_ip*` count is not a reliable
SIM count: preserve that distinction when comparing telephony observations.

Legacy Darwin `if_data` counters are 32-bit; `if_data64` has wider accounting
fields. Saturating a legacy synthetic counter makes it stop permanently after
long uptime. It also conflicts with a growing 64-bit view. Natural modulo
rollover is preferable to saturation, but applications must handle it properly.

## Mitigation Strategy Ideas

Use one mitigation-owned counter model, keyed by original interface name and
active seed/scope, for every covered public and raw view. Derive before name
aliasing. Use one clock sample per dump, preserve interface membership and
kernel filtering, and support subsecond deltas rather than rounding all reads
to whole seconds. Never mutate live kernel counters or the app's saved billing
state. Do not hook release functions or return replacement list allocations.

Raw sysctl adapters must preserve length-only probes, caller capacity, returned
length, errors, unrelated MIBs, and writes. Validate message tags, versions,
lengths, sockaddr padding, compressed masks, and names before committing.
Nested implementation calls need a guard against double shaping.

For gateways, normalize supported observation outputs with the same address,
name, and MAC derivation as interface lists. Do not rewrite actual routing or
manufacture a complete route table from a partial parser. Unchanged route
destinations, unsupported families, DNS, and server-side observations remain
potential contradictions.

## Derivation Considerations

Implemented details and exact policy-seed ownership belong to
[network.interface_inventory](../mitigations/network-interface-inventory.md).
Its counter stream has no persisted state and uses the observed boot-time
timeline. Clock changes, reboot, changed active scope/seed, and protection
transitions can reset apparent history. Keeping an old app baseline is not
evidence that the new counter model failed to install.

## Impact and Tradeoffs

Synthetic usage breaks exact data-consumption displays and speed-test
accounting. Gateway shaping can mislead diagnostics or callers that use the
reported address to connect to a router. Import rebinding has ABI and image
format limits; dynamically resolved, internal, routing-socket, and ioctl paths
are not automatically covered.

## Relevance

Data consumption is the priority extension from this binary analysis. The
implemented module now covers bounded 32/64-bit interface dumps and supported
gateway observations. This is experimental source coverage, not proof that
the supplied collector or an SDK's private wrapper is intercepted on iOS.

Validation needs equal-time cross-view comparisons, Wi-Fi and multiple
cellular-row aggregation, rapid sampling, rollover, original failure/short
buffer behavior, ownership checks, seed/scope changes, app baselines, reboots,
network/VPN transitions, and disabled-policy behavior. Actual DNS and full
route topology are explicit gaps, not part of this accounting mitigation.
