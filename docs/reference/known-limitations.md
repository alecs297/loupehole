# Known limitations and threat-model boundaries

## Present limitation: coverage is selective

Loupehole currently compiles 32 experimental mitigations in the default build. The surface inventory remains broader and deeper than those modules: each compiled mitigation covers only the exact APIs and behavior documented on its mitigation page. Inventory coverage is research coverage, not runtime coverage.

## Platform-control boundary

Location, permission-gated motion and sensor access, contacts, Photos, and music-library inventory are intentionally not compiled as mitigations in the default build. Those domains already have granular iOS permission controls that users can deny directly, and the current project scope treats pass-through or system denial as less fingerprintable than partial synthetic inventories for these surfaces. Permission-free device-motion getters remain in the default build because covered Core Motion data paths can expose live movement and sensor-bias signals without an explicit user permission grant.

Bluetooth, Calendar, and Reminders remain candidates for mitigation work because fair app functionality can require permission while still not justifying unrelated inventory access. Their behavior should be evaluated by their mitigation pages and revisited with surface-specific design work.

Local-network service discovery is not compiled as a mitigation. Bonjour and DNS-SD are functional discovery protocols: returning real results exposes nearby devices and service names, while returning synthetic or empty results breaks the feature and creates an obvious behavioral difference. Loupehole treats Local Network permission denial or pass-through as less misleading than a partial discovery shim.

## Cross-check limitation

A covered high-level API can be compared with an uncovered low-level API. Current examples:

- Foundation volume and app install dates can be compared with filesystem metadata APIs that are not yet normalized.
- Synthetic boot time and Foundation uptime do not normalize every monotonic clock, process age, log time, or mach-time path.
- Scoped and generic identity values do not normalize all account, StoreKit, OS-version, anti-abuse, bundle metadata, previous-install, or generic Keychain signals.
- Bonjour and DNS-SD service discovery are intentionally pass-through. Earlier attempts to suppress local discovery showed that preserving the API's useful behavior while hiding its fingerprintable local-device context is not a coherent mitigation boundary.
- DNS resolver server IPs are intentionally pass-through. Earlier DNS server-address hooks around SystemConfiguration and BIND resolver state caused guarded file-descriptor crashes on device. The old implementation and crash logs were not recovered; no specific root cause is established. [Resolver research](../surfaces/dns-resolvers.md) explains why modifying directly read resolver addresses can change actual query destinations and why copied-output hooks miss that collector.
- Interface counters agree across covered `getifaddrs` and raw 32/64-bit dumps at an equal clock sample, but routing-socket/ioctl, internal, and dynamically resolved paths remain uncovered. Synthetic traffic is not real throughput or billing usage; app-owned baselines can become invalid at rollover, reboot, or policy/seed transitions.
- Gateway shaping covers supported IPv4 and link-local IPv6 observations, not a complete route topology. Destinations/netmasks, global IPv6 gateways, and `AF_LINK` gateway routes remain real.
- Cellular-service getters and provider notifier wrappers use one bounded service/redaction policy, but RAT notifications, data-service delegate callbacks, private subscription state, real reachability, and server/carrier observations can disagree.
- Memory shaping covers supported current-task `task_info` imports and VM reads, not alternate task-port names, direct Mach messages, every private accounting API, or hardware RAM constants. Component sums retain rounding/noise discrepancies; substantial real workload remains visible.
- Network, memory, device-motion, audio, camera, power, pasteboard, and WebView modules can still be cross-checked against unimplemented delegate callbacks, lower-level APIs, arbitrary JavaScript, or server-side behavior.

These are documented gaps, not claims of invisibility.

## Loader and platform limitation

Hook behavior depends on iOS version, ABI/compiler behavior, Theos/MobileSubstrate-compatible backend behavior, call-site form, and app implementation language. An intercepted Objective-C selector does not prove every Swift, C, inlined, direct, or imported-symbol path is covered.

Imported rebinding supports validated indirect slots, classic bind streams, and ordinary `DYLD_CHAINED_PTR_64` / `64_OFFSET` file-backed chains. Authenticated arm64e/cache fixups, inaccessible/mismatched backing files, nonzero-addend or unaligned pointers, optimized direct branches, and dynamically obtained addresses remain outside that guarantee. Installation does not resolve an already-running lazy-binding race. Host delivery/composition tests are not evidence of actual loader/device compatibility.

## Compatibility limitation

Apps may rely on genuine system values for analytics, licensing, account recovery, timeline logic, diagnostics, device management, local network, accessibility behavior, media behavior, and anti-abuse. A mitigation can be privacy-improving and still be incompatible with an app. Per-bundle policy and pass-through behavior exist to keep this risk controllable.

## Hardware-profile limitation

The project does not presently present a full alternative hardware identity. Hardware model, display properties, CPU/GPU capabilities, camera lineup, and WebKit claims must be changed only as a coherent profile family. One-off hardware spoofing is outside the safe default model.

[CPU load research](../surfaces/cpu-load.md) is not an installed mitigation. Processor/task/thread CPU accounting, timed benchmark throughput, CPU/cache sysctls, and Mach clocks remain untreated. Memory shaping deliberately preserves task CPU times.

## No anti-detection guarantee

Avoiding fixed project markers and minimizing injected side effects can reduce self-identification, but it does not guarantee resistance to jailbreak detection, integrity checks, loader detection, behavioral analysis, or server-side correlation. Loupehole’s stated purpose is fingerprinting-surface normalization, not anti-tamper evasion.

## Persistence limitation

State and seed persistence establish useful stability but also create lifecycle complexity. Package upgrades, resets, uninstall behavior, rootless paths, failed writes, and schema changes require tests. Persistence should be minimal, private, and documented; it is not a reason to retain unrelated target-app data.
