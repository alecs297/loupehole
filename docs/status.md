# Current Status And Limits

Loupehole is in early development. The runtime, generator, package scaffold, Settings bundle, seed/scope/state machinery, and static verification scripts exist, and the default build selection currently compiles 32 experimental mitigation modules.

This status page is a handoff summary. For exact user-facing positioning, read the root [`README.md`](../README.md). For implemented behavior, read [`docs/mitigations/`](mitigations/). For research coverage and future planning, read [`docs/surfaces/`](surfaces/).

## What Exists

- Standalone arm64 iOS dylib build through the Theos build adapter under `src/packaging/theos/`.
- Rootless Debian package build with generated loader basename, generated filter, maintainer scripts, package policy storage, root seed storage, and PreferenceLoader UI.
- Static build graph driven by `config/mitigations.json` and `config/build.default.json`.
- Runtime support for install, app, vendor, and manual linked group scopes.
- Seed derivation, policy seed generation, opaque package names, state-provider modes, and mitigationkit value helpers.
- Verification targets for seed derivation, seed provider behavior, state provider behavior, mitigation values, package layout, Mach-O summary, string scan, exported symbols, Swift runtime absence, and debug-log absence.
- Focused Darwin-host surface checks for interface traffic, gateways, import rebinding/composition, process memory, and cellular-service coherence (`make surface-check`).

## Device-Information Analysis Follow-Up

Data consumption is the priority. The existing interface module now shares one per-original-interface counter model across `getifaddrs`, raw `NET_RT_IFLIST`, and raw `NET_RT_IFLIST2`; 32-bit counters wrap instead of permanently saturating. Fractional sampling and multiple Wi-Fi/cellular rows are supported. The same module shapes bounded gateway observations with its address/name/MAC seeds, without changing real routing or reconstructing route topology.

Adjacent work aligns supported CoreTelephony service/provider/data identifiers and redacts available carrier metadata without inventing missing services. Current-process memory precision uses one rounding quantum across supported `task_info` flavors, while shared system VM fields use matching noise contexts across legacy/64-bit views. No centralized coherence registry was introduced, and scope levels/default selection remain unchanged.

The hook backend now handles supported classic bind streams and ordinary 64-bit chained imports, preserving stacked import adapters and existing direct-hook trampolines. Authenticated/cache imports, unavailable backing files, and direct/dynamically resolved calls remain limits. Host fixtures test actual imported `getifaddrs`/`sysctl` delivery, but do not prove MobileSubstrate or iOS-app behavior.

[CPU load](surfaces/cpu-load.md) has research documentation only. [DNS resolver inventory](surfaces/dns-resolvers.md) remains untreated: prior guarded-FD failures have no recovered root cause, and mutating directly read resolver state can change functional DNS. No safer generic design was established for the analyzed collector.

These are source/build and host-regression results, not validation against the supplied binary on an iOS device. Required device checks include SDK call reachability, billing baselines, subsecond speed tests, dual-SIM/no-service transitions, route layouts, and memory revisions.

### Validation Snapshot: 2026-09-29

The default selection passed `make surface-check`, `make audit`, and `make package` on macOS 26.2 (25C56), using macOS/iPhoneOS SDK 26.5. The actual interface module/backend live probe checked 189 non-loopback counter reads in each of classic and ordinary chained native executables. Route fixtures passed 257 sanitizer assertions, including nested public/private wrappers. Process-memory, telephony, and import composition fixtures passed. The arm64 standalone artifact is `dist/runtime.dylib`; the rootless package is `dist/com.loupehole.runtime_0.1.0_iphoneos-arm64.deb`. Package layout verification is separate from installation and runtime testing. No iOS target-app or device evidence was collected.

## What Is Experimental

- All default mitigations are experimental and should be evaluated by their linked mitigation pages, not by broad surface names.
- Real-device validation remains required for every iOS version, jailbreak, loader, and target-app combination.
- Package policy and Settings behavior are implemented but still young; lifecycle changes need install, upgrade, disable, and uninstall review.
- The current surface inventory is intentionally larger than the implemented mitigation set.

## What Is Not Claimed

- Loupehole does not claim universal coverage for a surface just because one mitigation in that family exists.
- Loupehole does not bypass DRM, fraud systems, app security controls, or hardware attestation.
- Loupehole does not collect telemetry.
- Permissioned personal-data inventories, location, local network discovery, Photos, contacts, and similar areas remain constrained by compatibility, consent, and detectability concerns.

## Handoff Checks

Before a broad handoff, run:

```sh
make surface-check
make audit
make package
```

`surface-check` requires a Darwin compiler/SDK and the default profile's interface seeds; custom selections that omit those modules should run applicable individual checks instead. Keep these focused host tests distinct from device evidence.

When changing catalog entries, policy seed declarations, source paths, generator behavior, or package layout, run `make generate` first and treat generated files as disposable output.
