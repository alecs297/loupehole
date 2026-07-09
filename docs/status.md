# Status and limits

## Current implementation baseline

Loupehole currently has a complete **build-to-package skeleton**, not complete anti-fingerprinting coverage.

Present components include:

- a generated, statically compiled mitigation registry;
- generated compile-time policy seeds declared by selected mitigations;
- a central policy engine;
- seed, scope, and state-provider machinery;
- a MobileSubstrate-compatible hook backend abstraction;
- a rootless Debian package with a PreferenceLoader Settings bundle;
- package policy with default and per-bundle controls;
- dylib and package verification targets;
- 29 experimental mitigation modules selected by the default build.

## Implemented mitigation group

| Group | Present behavior | Important boundary |
| --- | --- | --- |
| Identity and install context | Covers IDFV, device name, hostname, app install date, and iCloud ubiquity-token absence. | It does not normalize every account, StoreKit, OS-version, anti-abuse, bundle metadata, previous-install, or generic Keychain signal. |
| Temporal and storage values | Covers boot time, Foundation volume creation date, app install date, and available-capacity bucketing. | It does not normalize all clocks, filesystem metadata, total capacity, volume UUID/name, logs, or mach-time APIs. |
| Locale, voices, accessibility, display, audio, camera, and power | Covers narrow high-level getters with primary-language filtering, inventory filtering, shaped live values, coarse values, or common constants. | It does not provide a coherent full hardware, locale, rendering, media, accessibility, or camera-profile replacement. Font inventory is documented as a research surface but intentionally not compiled because partial filtering can be more fingerprintable than pass-through. |
| Bluetooth, telephony, EventKit, app, network, pasteboard, and WebView probes | Covers selected Bluetooth scan behavior, EventKit empty inventory shape, URL-scheme probe filtering, proxy/Bonjour/hostname paths, pasteboard metadata, and exact WebView probe guards. | It does not normalize every delegate callback, timeline, permission path, arbitrary JavaScript fingerprint, network interface, local discovery workflow, or permissioned-data behavior. |

The temporal modules are linked intentionally. They should not be evaluated as independent fake timestamps: their shared policy-seed use establishes `volume creation time < app install time < boot time < now` where the selected modules overlap.

Location, motion and sensors, contacts, Photos, and music-library inventory are not part of the compiled mitigation set. The default position is that those iOS permission domains are granular enough for users to control directly, while partial synthetic inventories can create new fingerprinting risks.

## Why the status remains experimental

A hook can compile and still be unsuitable for broad use. The current modules need ongoing testing across OS versions, jailbreak environments, app types, Swift, Objective-C, C, imported-symbol call paths, package upgrades, disabled policy paths, and cross-surface checks. Many APIs named by the surface inventory remain unimplemented or intentionally pass through.

Experimental does **not** mean safe to assume universal compatibility. It means the module has a defined intended behavior, a controlled fallback, and early validation evidence, while compatibility and anti-fingerprinting efficacy remain open to revision.

## Non-goals

Loupehole does not currently claim to:

- defeat all app tamper detection, jailbreak detection, fraud detection, licensing enforcement, or DRM;
- transform an arbitrary real device into a fully coherent different hardware model;
- normalize every native, WebKit, filesystem, network, timing, account, or permissioned surface;
- inject into every process on a device;
- collect telemetry or remotely manage profiles;
- make per-call randomness a general privacy mechanism.

## Compatibility position

The build target is arm64 with a minimum iOS deployment target of 15.0. The project intends to support iOS 15–26, but a version in that range is a validation target, not an unconditional support guarantee. Package mode additionally depends on a rootless jailbreak setup with a compatible injection loader and PreferenceLoader.

## Documentation status model

The detailed surface and mitigation libraries are research and behavior references. Their existence does not mark a surface as implemented. The authoritative implementation set is the selected entries in `config/build.default.json` and the generated registry produced from `config/mitigations.json`.
