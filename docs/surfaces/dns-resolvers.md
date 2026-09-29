# DNS Resolver Inventory

Source reviewed: supplied device-information binary analysis, "DNS IP
addresses" (`sub_10013d808`), plus Apple resolver headers and implementation.
This is a binary-analysis extension to Network, not a reviewed Loupe provider.

Loupe category: Network (binary-analysis extension)
Loupe tier: passive local resolver-configuration inventory
Permission required: None for the analyzed local configuration reads; API and
sandbox availability vary by OS
Primary relevance: network and resolver identity, VPN context, and coherence
with interface addresses and gateways.

This page includes configured nameserver addresses and their observable list
shape. It excludes DNS answers, query interception, resolver replacement, and
Bonjour/DNS-SD discovery. Actual resolution is a functional constraint, not a
target for synthetic values. DNS inventory remains explicitly untreated:
there is no current DNS mitigation and no device-validation evidence from this
investigation. Apple source establishes design constraints, not verified
behavior on every supported iOS release.

## Official Links

- Apple [resolver ABI and versioned symbols](https://github.com/apple-oss-distributions/libresolv/blob/main/resolv.h)
- Apple [resolver initialization, cleanup, and server-copy APIs](https://github.com/apple-oss-distributions/libresolv/blob/main/res_init.c)
- Apple [nameserver selection and query transport](https://github.com/apple-oss-distributions/libresolv/blob/main/res_send.c)
- Apple [DNS handles, notification lifecycle, and copied server addresses](https://github.com/apple-oss-distributions/libresolv/blob/main/dns.c)
- Apple [EXC_GUARD crash interpretation](https://developer.apple.com/documentation/xcode/exc_guard)

## Binary-Analysis Signals and Decisions

| Signal | Collector source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| Nameserver count | Direct `nscount` read after `res_9_ninit` | None | Passive resolver-state inspection | Include; untreated | List shape distinguishes resolver configurations. |
| Legacy IPv4 server addresses | Direct `nsaddr_list` reads, formatted with `inet_ntoa` | None | Passive resolver-state inspection | Include; untreated | Addresses can identify local infrastructure, resolver operators, or VPN configuration. |
| Copied IPv4/IPv6 server addresses | Adjacent `res_9_getservers` and private `dns_server_list_address`; not observed in this collector | None for local reads; availability varies | Adjacent inventory research | Include as a boundary candidate only | Broader address-family coverage, but outputs can also serve functional networking. |
| SystemConfiguration DNS inventory | Adjacent configuration APIs, not observed as direct collector calls | None for local reads; availability varies | Adjacent configuration research | Include; untreated | Resolver scopes and configuration can disclose network context. |

The supplied analysis describes an asynchronous collector that allocates a
`0x228`-byte state buffer, calls `res_9_ninit`, reads the count and address array
directly, builds a string array, then calls `res_9_nclose`, `res_9_ndestroy`, and
`free`. This allocation size is a fact about the analyzed binary, not a layout
contract for a future hook. No equivalent IPv6 conversion was identified.

## Permission and Collection Class

No TCC prompt is associated with the analyzed local inventory path. Local
Network authorization for discovery or traffic must not be inferred from a
resolver-configuration read.

Collection is passive with respect to DNS queries: the analyzed path does not
send a lookup. Initialization and cleanup still manage library resources, so a
passive observation does not imply a resource-free mitigation boundary.

## Fingerprinting Value

Nameserver addresses can expose a home or enterprise network, custom DNS
operator, filtering setup, or VPN environment. Count, order, and address-family
shape add configuration context. These values are correlation signals, not
proof of a particular location or VPN.

Resolver observations can be compared with interface subnets, gateways, proxy
scopes, network transitions, and actual DNS behavior. A synthetic local-network
view alongside real resolver inventory remains a documented coverage gap.

## Mitigation Strategy Ideas

### Prior Failure Evidence

Commit `ddc4fc5` records that earlier SystemConfiguration/BIND server-address
hooks caused guarded file-descriptor crashes and were removed. The same limit
is documented in [known limitations](../reference/known-limitations.md).
Review of available history, reflogs, and unreachable blobs did not recover
the original DNS hook implementation or a crash report. The exact failing
design, guarded FD, and root cause remain unknown. Do not describe a suspected
state-copy or cleanup bug as an established explanation.

### Resolver State and FD Lifecycle

Apple's implementation couples inventory to functional state. Initialization
sets up addresses and configuration notifications. `res_9_nclose` closes
`_vcsock` and cached nameserver sockets, clearing their FD slots.
`res_9_ndestroy` calls close again, cancels notifications, frees extension and
random state, and clears initialization status. Close followed by destroy is
not inherently a double-close error on correctly initialized, uncorrupted
state. Corrupt FD fields can make cleanup close an unrelated descriptor;
this is a hazard, not the recovered cause of the prior crashes.

Query code compares public addresses with cached addresses and uses
`nsaddr_list` when selecting destinations. Rewriting that array changes
functional resolution even if private FD fields are untouched. Empty counts,
shadow states, or restoring addresses only around selected query calls do not
establish a complete lifecycle or resolution guarantee.

### Candidate Boundaries

- `res_9_getservers` copies into a caller-provided buffer, while
  `dns_server_list_address` returns a separate allocation. These offer narrower
  ownership boundaries, but the analyzed binary bypasses both. Returned
  addresses may also configure a caller's own resolver.
- SystemConfiguration and `dns_configuration_copy` results feed functional
  resolver construction. Imported-symbol rebinding alone does not distinguish
  inventory consumers from functional library consumers.
- `inet_ntoa` receives an address by value and loses pointer provenance.
  Formatting hooks, including `inet_ntop`, cannot generally establish whether
  an address came from DNS inventory or functional networking. Matching an IP
  or timing window is insufficient, especially when DNS and gateway IPs agree.

No generic candidate was justified that covers direct state reads while
preserving resolver lifecycle, FD ownership, server state, and resolution.
Keep pass-through. A copied-output experiment needs evidence of an
observation-only caller and must state that direct state reads remain exposed.

## Derivation Considerations

No DNS policy seeds, helpers, or synthetic state are implemented. A future
mitigation must own its declarations and combine generated policy seed bytes
with the active seed and scope under the existing mitigation pattern.

Any future output must agree with covered interface and gateway observations,
preserve unavailable results, and define count, order, family, scope, and
network-change lifetime together. Avoid per-read rotation or invented usable
DNS endpoints. Coherent derivation cannot itself prove that consumers will
leave actual resolution unchanged.

## Impact and Tradeoffs

DNS configuration supports diagnostics, custom resolvers, enterprise split
DNS, VPNs, and network changes. Masking it can redirect queries, break internal
names, introduce timeouts, or make diagnostics misleading. Lifecycle changes
can additionally leak resources or trigger guarded-FD crashes.

Separate output allocation reduces ownership coupling but does not prove
functional isolation. Private APIs and source snapshots need target-version
verification; compilation is not evidence of device compatibility.

## Relevance

DNS resolver inventory is relevant network research, with implementation
deferred. The supplied binary's direct state reads prevent a copied-output
hook from addressing its observed disclosure. No device run or crash
reproduction was performed in this investigation.

Future validation must establish:

- The prior failing implementation and symbolicated crash report, when
  recoverable, without inventing a root cause when they remain unavailable.
- Target-iOS ABI, symbols, import coverage, and actual collector behavior,
  including failure handling and IPv4/IPv6 configuration.
- Unchanged resolver state, query destinations, FD ownership, allocation
  ownership, and notification cleanup across repeated initialization,
  reinitialization, close/destroy, and concurrent inventory/query workloads.
- Unchanged resolution across Wi-Fi/cellular transitions, offline recovery,
  VPN and split-DNS configurations, custom servers, and disabled policy.
- Coherent inventory values across covered API shapes and interface/gateway
  reads, with explicit pass-through for uncovered or unsafe paths.

Until those boundaries and device results are demonstrated, DNS stays
untreated and must not be counted as implemented mitigation coverage.
