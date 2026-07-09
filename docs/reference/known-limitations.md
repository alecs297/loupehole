# Known limitations and threat-model boundaries

## Present limitation: coverage is selective

Loupehole currently compiles 39 experimental mitigations in the default build. The surface inventory remains broader and deeper than those modules: each compiled mitigation covers only the exact APIs and behavior documented on its mitigation page. Inventory coverage is research coverage, not runtime coverage.

## Cross-check limitation

A covered high-level API can be compared with an uncovered low-level API. Current examples:

- Foundation volume and app install dates can be compared with filesystem metadata APIs that are not yet normalized.
- Synthetic boot time and Foundation uptime do not normalize every monotonic clock, process age, log time, or mach-time path.
- Scoped and generic identity values do not normalize all account, StoreKit, OS-version, anti-abuse, bundle metadata, or generic Keychain signals.
- Coarse sensor, location, network, media, and WebView modules can still be cross-checked against unimplemented delegate callbacks, lower-level APIs, arbitrary JavaScript, or server-side behavior.

These are documented gaps, not claims of invisibility.

## Loader and platform limitation

Hook behavior depends on iOS version, ABI/compiler behavior, Theos/MobileSubstrate-compatible backend behavior, call-site form, and app implementation language. An intercepted Objective-C selector does not prove every Swift, C, inlined, direct, or imported-symbol path is covered.

## Compatibility limitation

Apps may rely on genuine system values for analytics, licensing, account recovery, timeline logic, diagnostics, device management, local network, accessibility behavior, media behavior, and anti-abuse. A mitigation can be privacy-improving and still be incompatible with an app. Per-bundle policy and pass-through behavior exist to keep this risk controllable.

## Hardware-profile limitation

The project does not presently present a full alternative hardware identity. Hardware model, display properties, CPU/GPU capabilities, camera lineup, and WebKit claims must be changed only as a coherent profile family. One-off hardware spoofing is outside the safe default model.

## No anti-detection guarantee

Avoiding fixed project markers and minimizing injected side effects can reduce self-identification, but it does not guarantee resistance to jailbreak detection, integrity checks, loader detection, behavioral analysis, or server-side correlation. Loupehole’s stated purpose is fingerprinting-surface normalization, not anti-tamper evasion.

## Persistence limitation

State and seed persistence establish useful stability but also create lifecycle complexity. Package upgrades, resets, uninstall behavior, rootless paths, failed writes, and schema changes require tests. Persistence should be minimal, private, and documented; it is not a reason to retain unrelated target-app data.
