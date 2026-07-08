# Status and limits

## Current implementation baseline

Loupehole currently has a complete **build-to-package skeleton**, not complete anti-fingerprinting coverage.

Present components include:

- a generated, statically compiled mitigation registry;
- a typed policy-value registry;
- a central policy engine;
- seed, scope, and state-provider machinery;
- a MobileSubstrate-compatible hook backend abstraction;
- a rootless Debian package with a PreferenceLoader Settings bundle;
- package policy with default and per-bundle controls;
- dylib and package verification targets;
- three experimental mitigation modules selected by the default build.

## Implemented mitigation group

| Group | Present behavior | Important boundary |
| --- | --- | --- |
| IDFV | Hooks `UIDevice.identifierForVendor` and returns a policy-resolved scoped UUID. | It does not normalize every identity API or prove vendor-group behavior for every app topology. |
| Device lifetime | Hooks supported boot-time sysctl forms and `NSProcessInfo.systemUptime` from one temporal state. | It does not normalize all clocks, process lifetime values, logs, or mach-time APIs. |
| Storage lifetime | Hooks Foundation URL volume-creation-date resource values. | It does not normalize lower-level filesystem metadata such as `stat`, `fstat`, `lstat`, `getattrlist`, or direct filesystem queries. |

The temporal modules are linked intentionally. They should not be evaluated as independent fake timestamps: their state establishes `profile epoch ≤ volume creation time < boot time < now`.

## Why the status remains experimental

A hook can compile and still be unsuitable for broad use. The current modules need ongoing testing across OS versions, jailbreak environments, app types, Swift and Objective-C call paths, package upgrades, disabled policy paths, and cross-surface checks. Coverage also remains much smaller than the surface inventory in `docs/surfaces/`.

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
