# Validation and release criteria

## Validation layers

A mitigation requires evidence at four layers. Passing one layer does not substitute for another.

| Layer | Evidence | Purpose |
| --- | --- | --- |
| Declarative | Catalog/selection generation succeeds. | Ensures source, policy-seed, dependency, and metadata graph is coherent. |
| Build and binary | `make audit` passes. | Guards signing, generated linkage, symbols, strings, debug behavior, and core providers. |
| Package | `make package` and package layout checks pass. | Verifies rootless packaging, generated layout, filter/prefs placement, and dependency assumptions. |
| Runtime | Owned-device / owned-app observation plus regressions. | Verifies actual hook reachability, fallback, coherence, and compatibility. |

## Static gate baseline

`make audit` runs checks covering:

- derivation behavior;
- seed-provider behavior;
- state-provider behavior;
- mitigation-value derivation;
- Mach-O summary;
- string scanning;
- exported-symbol scanning;
- absence of Swift runtime linkage in the dylib;
- absence of debug logging in release artifact paths.

A failed scan is a signal to inspect the artifact and source. It is not appropriate to silence a scan merely to restore green output without understanding the observable change.

## Focused Host Regressions

Run `make surface-check` with the default selection on a Darwin compiler/SDK host. It is separate from `make audit`, allowing custom profiles to omit the interface module without requiring its generated seeds in unrelated checks.

- `interface-traffic-check`: actual list/raw adapters and counter model; Wi-Fi/multiple-cellular aggregation, shared 32/64-bit values, subsecond growth, rollover, compressed masks, ownership, nesting, malformed dumps, and failed clock/derivation paths. Live classic/chained executables also install the actual module through the backend and check native list/raw reads against the model.
- `routing-table-check`: supported IPv4/link-local IPv6 routes, common interface seeds, message lengths/flags/indexes, partial/unsupported layouts, and error/short-buffer behavior.
- `imported-symbol-check`: sanitized metadata/protection tests; live classic/chained clients, initial/later images, first lazy calls, stored import pointers, actual `getifaddrs`/`sysctl`, and stacked direct/import adapters.
- `process-memory-check`: Darwin basic/VM layouts, every count boundary, revision tails, one shared quantum, available-memory and legacy/64-bit VM coherence, unsupported tasks/flavors, and failure paths.
- `telephony-check`: dual-service/active-service projection, carrier redaction, legacy/modern getters, nil/unavailable states, notifier reassignment/clearing, reentrancy, partial hook installation, and SDK syntax.

Sanitizer fixtures and native-host imports establish bounded regression evidence only. Real iOS symbols, private wrappers, pointer authentication, actual MobileSubstrate trampolines, and target-app compatibility still need runtime evidence.

## Runtime test matrix

Each mitigation should be tested against the relevant dimensions:

- iOS versions within the intended 15–26 range;
- jailbreak and injection-loader environments where package mode is supported;
- Objective-C, C, imported-symbol, and Swift call paths where applicable;
- enabled, disabled, per-bundle override, and module-filter states;
- first launch, relaunch, app reinstall, package reinstall/upgrade, seed reset, and state reset;
- original API failure and policy/state failure paths;
- target apps that use the API directly and apps that use it through SDK/framework wrappers;
- cross-surface consistency checks.

For the device-information collector follow-up, explicitly compare equal-time traffic views, the low 32 bits of wide counters, multiple `pdp_ip*` aggregates, billing-baseline resets, rapid speed-test samples, and ownership after repeated frees. Probe covered and uncovered imports separately. Compare gateway/local address/name/MAC observations while recording unchanged route topology and untreated DNS. Test no-service, dual-SIM/data-line changes and provider callbacks alongside RAT/delegate gaps. Read basic flavor `0x14` and VM flavor `0x16` with their actual counts; do not equate resident memory with footprint or alter CPU times. Record CPU/DNS as untreated, not test successes.

## Evidence format

A mitigation page should record enough to reproduce the claim:

- device class and OS version;
- execution mode: standalone injected dylib or rootless package;
- loader/jailbreak context when package mode is used;
- selected build profile and relevant policy/scope configuration;
- probe method or owned test app;
- original observed result and mitigated observed result;
- stability/rotation observations;
- adjacent API results and known gaps;
- compatibility regressions or warnings.

## Release criteria for a new default mitigation

A mitigation should not enter the default build selection until it has:

1. a reviewed surface page and mitigation page;
2. explicit policy-seed/state/scope ownership;
3. documented fallback and disabled behavior;
4. catalog metadata and generator coverage;
5. static audit and package validation;
6. runtime evidence across a justified test matrix;
7. cross-surface coherence evidence;
8. an honest statement of remaining unimplemented adjacent paths.
