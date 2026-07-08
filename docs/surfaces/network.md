# Network Fingerprint Category

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/NetworkProvider.swift`

Helper reviewed: `.research/upstream/loupe/code/Loupe/Support/IfAddrsHelper.swift`

Loupe category: Network
Loupe tier: passive local network state, with active local monitoring in stream mode
Permission required: none for Loupe's reads
Primary relevance: local network identity, current path state, interface/address
correlation, VPN/proxy posture, and coherence with host-name and device-profile
surfaces.

Loupe's Network provider does not make an outbound request. It reads local
kernel/network state with `gethostname`, `getifaddrs`, `getnameinfo`,
`NWPathMonitor`, and `CFNetworkCopySystemProxySettings`.

## Official Links

- Apple Network `NWPathMonitor`: <https://developer.apple.com/documentation/network/nwpathmonitor>
- Apple Network `NWPath.isExpensive`: <https://developer.apple.com/documentation/network/nwpath/isexpensive>
- Apple Network `NWPath.isConstrained`: <https://developer.apple.com/documentation/network/nwpath/isconstrained>
- Apple Network `NWPath.availableInterfaces`: <https://developer.apple.com/documentation/network/nwpath/availableinterfaces>
- Apple Network `NWInterface`: <https://developer.apple.com/documentation/network/nwinterface>
- Apple Network `NWInterface.InterfaceType`: <https://developer.apple.com/documentation/network/nwinterface/interfacetype>
- Apple CFNetwork `CFNetworkCopySystemProxySettings`: <https://developer.apple.com/documentation/cfnetwork/cfnetworkcopysystemproxysettings%28%29>
- Apple CFNetwork global proxy settings constants: <https://developer.apple.com/documentation/cfnetwork/global-proxy-settings-constants>
- Apple NetworkExtension framework: <https://developer.apple.com/documentation/networkextension>
- Apple technote TN3179, local network privacy: <https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy>
- Apple archived iOS `gethostname(3)` manual page: <https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/gethostname.3.html>
- Apple archived iOS `getifaddrs(3)` manual page: <https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getifaddrs.3.html>
- Apple archived iOS `getnameinfo(3)` manual page: <https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getnameinfo.3.html>
- Apple Foundation `ProcessInfo.hostName`: <https://developer.apple.com/documentation/foundation/processinfo/hostname>

Apple documents the public Network, CFNetwork, Foundation, and BSD/POSIX
surfaces used here. The `__SCOPED__` proxy dictionary key that Loupe scans is an
observed key inside the proxy settings dictionary, not a first-class public
constant in Apple's global proxy settings list. Treat it as a practical
compatibility target that may drift across OS releases.

## Loupe Signals and Decisions

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `hostname` | `IfAddrsHelper.hostname()` -> `gethostname` | None | Passive local hostname read | Include | Medium. Can mirror a user-visible device or host name and must agree with `kern.hostname`, `uname.nodename`, `ProcessInfo.hostName`, and any device-name mitigation. |
| `isExpensive` | `NWPath.isExpensive` from a sampled `NWPathMonitor` path | None | Passive path-state read; stream mode is active local monitoring | Include | Low to medium. Usually indicates cellular, hotspot, or another costly path. Useful when joined with IP, interface, data-saver, and session timing signals. |
| `isConstrained` | `NWPath.isConstrained` from the same path | None | Passive path-state read; stream mode is active local monitoring | Include | Low to medium. Exposes Low Data Mode or equivalent constrained-path policy, which can reveal user/network preference and explain app behavior changes. |
| `availableInterfaces` | `NWPath.availableInterfaces.map { NWInterface.InterfaceType }` | None | Passive path interface inventory | Include | Medium. Reports interface classes such as `wifi`, `cellular`, `wiredEthernet`, `loopback`, and `other`; multi-interface combinations narrow context and must match address/proxy state. |
| `vpnActive` | `CFNetworkCopySystemProxySettings()["__SCOPED__"]` keys containing `tap`, `tun`, `ppp`, or `ipsec` | None | Passive proxy-settings heuristic | Include, with heuristic caveat | Medium to high when true. VPN use is a rare security/network posture and may be used for blocking, risk scoring, or cohort reduction. |
| `vpnInterfaces` | Sorted scoped proxy keys whose names match Loupe's VPN tokens | None | Passive scoped proxy key enumeration | Include as the detailed form of `vpnActive` | High when present. Interface names and counts reveal more than the boolean and can disclose tunnel style. Loupe deliberately excludes `utun` from the VPN heuristic to avoid false positives from non-VPN Apple features. |
| `addr.<index>.<interface>.<family>` | `getifaddrs` for up/running IPv4 and IPv6 interfaces, converted with `getnameinfo(..., NI_NUMERICHOST)` | None | Passive interface address enumeration | Include | High. Local, cellular, VPN, loopback, link-local, and IPv6 addresses can link sessions, reveal subnet context, and contradict path or proxy claims. |

Loupe emits one `addr.*` signal per current address. The signal key includes the
enumeration index, interface name, and address family, so both the address value
and the shape/order of the interface set are observable.

## Permission and Activity Classification

No included Network signal requires Contacts, Location, Bluetooth, Motion,
Photos, Local Network, or another user-granted runtime permission. Loupe reads
local process and kernel networking state. It does not browse Bonjour services,
connect to nearby devices, send multicast probes, open sockets to LAN peers, or
make internet requests.

Local Network privacy still matters as a boundary: an app that actively
discovers or communicates with devices on the local network can trigger Apple's
Local Network permission flow. This Loupe provider does not do that. Its risk is
silent local observability, not permission-gated network interaction.

The one-shot `collect()` path samples one `NWPath` and times out after 1.2
seconds if no path arrives. The `stream()` path starts an `NWPathMonitor` and
yields every path update, so it is active local monitoring even though it is not
an external network probe.

## Fingerprinting Value

The highest-value Network signals are interface addresses and VPN/proxy keys.
Local IP addresses can reveal a home, office, carrier, hotspot, VPN, or IPv6
prefix context. Even private RFC1918 addresses are useful because subnet shape,
address family, interface naming, and address churn can link short sessions.

`vpnActive` is a compact but meaningful boolean. A true value is rarer than a
normal Wi-Fi or cellular path and can be operationally important: finance,
streaming, enterprise, anti-abuse, and region-policy apps may react to VPN use.
`vpnInterfaces` is more sensitive than the boolean because it exposes the
matching scoped proxy keys that produced the heuristic result.

`availableInterfaces`, `isExpensive`, and `isConstrained` are lower entropy by
themselves, but they are strong consistency checks. A profile that claims
`wifi` only while showing a cellular address, an expensive path, or a VPN scoped
key is easy to detect. Low Data Mode and expensive-path state also influence
real URLSession, Network.framework, and app policy behavior.

The local hostname is medium-value. On modern iOS it may be generic, but it can
still mirror user-assigned naming, enterprise naming, local network identity, or
kernel host-name surfaces. It is especially useful to trackers when combined
with device name, `kern.hostname`, app install state, and local IP data.

## Mitigation Strategy Ideas

### Hostname

Mitigation ID idea: `network.hostname`

Hook equivalent host-name reads as one surface:

- `gethostname`
- `sysctl` / `sysctlbyname` for `kern.hostname`
- `uname.nodename`
- `ProcessInfo.hostName`
- any Network-provider or device-identity surface that reflects the same host
  name

Compatibility default should pass through. Strict mode can return a generic
cohort host name such as `iPhone` or `iPad`, selected with the same device-class
profile used by `UIDevice.name`. Avoid personalized names, owner initials,
serial-looking suffixes, rare punctuation, or seed-derived unique hostnames.

Do not change real network behavior just to hide a read. If the target app is a
network diagnostic, MDM, file-sharing, local-discovery, or enterprise tool that
needs the real host identity, pass through this surface.

### Path Cost and Constraint Flags

Mitigation ID idea: `network.path_policy`

Treat `NWPath.isExpensive`, `NWPath.isConstrained`, and equivalent path-policy
observations as a linked tuple. Compatibility default should pass through
because apps use these flags to avoid large downloads, reduce media quality,
defer sync, or respect Low Data Mode.

Strict mode may normalize to the common unconstrained, non-expensive path only
when the rest of the network profile also looks like ordinary Wi-Fi and the app
does not depend on real path policy. Do not report `isExpensive == false` while
exposing cellular-only interfaces or cellular addresses. Do not report
`isConstrained == false` if other visible behavior makes Low Data Mode obvious,
such as reduced fetch behavior or system-imposed path decisions.

### Available Interfaces and Interface Addresses

Mitigation ID ideas: `network.interface_types` and `network.interface_addresses`

Cover the native surfaces together:

- `NWPath.availableInterfaces`
- `NWPath.usesInterfaceType(_:)` if future coverage observes it
- `getifaddrs`
- `getnameinfo` only when converting addresses returned from a synthetic
  interface list
- reachability or socket helper paths that expose the same interface/address
  facts

Compatibility default should pass through. Many apps bind sockets, choose
interfaces, diagnose connectivity, or show local addresses to the user. Returning
an address that the kernel cannot actually bind is a functional break and a
strong synthetic-profile marker.

Strict mode can reduce precision for fingerprint-only apps by filtering or
coarsening the address list, but the whole tuple must remain plausible. Interface
types, interface names, address families, flags, local IPs, scoped proxy keys,
and path cost must tell the same story. Prefer dropping sensitive detail over
inventing a rare fake network.

Useful strict shapes are low entropy:

- Wi-Fi-only: `wifi`, `en0`, private IPv4 or IPv6 local address, not expensive,
  not constrained unless policy says otherwise.
- Cellular-only: `cellular`, `pdp_ip*`, expensive usually true, no Wi-Fi local
  subnet.
- Loopback-only/failure: `loopback` plus loopback addresses, only when the app
  already cannot reach a real path.

Avoid exposing deterministic but unique synthetic subnets across many apps. A
stable fake `192.168.x.y` derived directly from the seed can become a new
identifier.

### VPN Active Heuristic and Scoped Proxy Keys

Mitigation ID idea: `network.vpn_status`

Loupe's VPN boolean is derived from scoped proxy/interface keys, not from a
formal VPN-status API. Preserve that relationship:

```text
vpnInterfaces non-empty under Loupe's token rule => vpnActive true
vpnInterfaces empty under Loupe's token rule => vpnActive false
```

Compatibility default should pass through. Apps may require a corporate VPN,
avoid syncing on a VPN, apply security policy, or explain connection failures to
the user.

Strict mode can hide VPN posture by filtering `tap`, `tun`, `ppp`, and `ipsec`
keys out of the returned proxy settings dictionary and aligning any corresponding
`getifaddrs` output. It should not merely force `vpnActive` to `false` while
leaving scoped proxy keys or tunnel-like interface addresses visible.

Do not blindly remove `utun`. Loupe explicitly excludes `utun` from its VPN
heuristic because iOS can expose `utun` interfaces for non-VPN Apple features
such as iCloud Private Relay, Personal Hotspot relay, Handoff, AirDrop, and
other system networking paths. A policy that hides every `utun` can create false
negatives, break legitimate behavior, or erase useful non-VPN context.

If proxy settings are rewritten, keep the documented CFNetwork proxy keys and
value types intact. A malformed proxy dictionary can break URL loading or make
the hook more detectable than the original VPN signal.

## Derivation Considerations

Hostname values should be cohort constants or tiny common-set choices, not
per-user random strings. They must be generated with device identity and system
identity values so `UIDevice.name`, `kern.hostname`, `gethostname`,
`uname.nodename`, and `ProcessInfo.hostName` do not contradict one another.

Path flags should usually be pass-through or explicit policy constants. If they
are synthetic, derive only a low-entropy path profile and keep it aligned with
interface types, address families, proxy settings, and visible app behavior.
Do not rotate path flags independently from the interface/address tuple.

Interface addresses are live network state, not durable identity. If strict
mode needs synthetic values, derive them from the active seed, scope, and a
network epoch, then rotate or rebuild them when the real path changes enough
that the old tuple would be implausible. Keep families, flags, interface names,
and path policy coherent by construction.

Scoped proxy keys and interface names should use platform-shaped vocabulary.
Returned values must not expose readable project names, mitigation IDs, profile
names, salts, or other Loupehole implementation details. If synthetic tunnel
keys are ever needed for compatibility, choose common shapes and make the
corresponding boolean, proxy dictionary, and interface list agree.

Avoid deriving rare states for privacy theater. A seed-derived VPN-active
`true`, unusual tunnel name, or unique private subnet can identify the protected
profile more strongly than pass-through would have.

## Impact and Tradeoffs

Hostname normalization reduces passive identity leakage, but can confuse local
network diagnostics, device-management flows, sync tools, support screens, and
apps that help users choose a specific device on a network.

Path-policy normalization can save privacy but harm user intent. Apps are
supposed to respect expensive and constrained paths; hiding those flags may
trigger large downloads, higher bitrate media, background sync, or data use that
the user or network operator tried to avoid.

Interface and address spoofing has the highest compatibility risk in this
category. Apps may bind to addresses, select interfaces for peer-to-peer
connections, diagnose VPN or Wi-Fi state, or display local endpoint data.
Synthetic addresses that are not actually usable can break networking and
create obvious contradictions.

VPN hiding can protect a sensitive security posture, but it can also break
enterprise apps that require the VPN, frustrate support/debug flows, and
conflict with server-side observations. If traffic still exits through a VPN
while local reads claim no VPN, remote IP, latency, DNS, proxy behavior, and TLS
egress patterns may reveal the contradiction.

Proxy dictionary rewriting must be narrow. `CFNetworkCopySystemProxySettings`
feeds legitimate proxy selection logic, not just fingerprinting code. Preserve
unrelated keys and value types, and prefer pass-through when the hook cannot
distinguish fingerprinting from functional proxy use.

## Relevance

Network is relevant for v1 planning because every included signal is readable
without a runtime permission prompt, and several are high-value correlation or
policy signals. Interface addresses and scoped VPN/proxy keys are the strongest
privacy surfaces. Hostname is important because it overlaps with the Device
Identity category. Path flags and available interface types are lower entropy
but critical for coherence.

This page should feed future option docs for host-name normalization,
interface/address reduction, path-policy handling, and VPN/proxy-status
handling. Network mitigations should remain conservative by default: pass
through functional networking state unless a strict profile can return a
complete, plausible, internally consistent tuple.
