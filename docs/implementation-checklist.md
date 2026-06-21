# Implementation Checklist

This document is the actionable handoff plan for implementing Loupehole from the current package/configuration baseline. It assumes the decisions in [architecture.md](architecture.md), [execution-plan.md](execution-plan.md), [fingerprinting-surfaces.md](fingerprinting-surfaces.md), and [spoofing-option-policy.md](spoofing-option-policy.md).

## Settled Decisions

- Build locally on macOS with Xcode 26+, Theos, `ldid`, and `dpkg-deb`.
- Build a plain injectable arm64 iOS `.dylib` and package the same runtime into a rootless `.deb`.
- Real-device deployment and validation are manual: Sideloadly-style owned-app injection or rootless jailbreak package installation.
- The injected runtime must use C, Objective-C, or Objective-C++. Do not use Swift in the dylib. Swift is allowed only for preferences UI or external tooling.
- Use `LHHookBackend` from the first source commit. The current implementation is Theos/Logos with MobileSubstrate-compatible hooks.
- Use a configuration instance seed supplied as any valid UUID. Feed it through a KDF to derive scoped seeds, opaque storage identifiers, state filenames, Keychain service/account names, generated internal names, and optional build variability.
- Compile cohort profile values into the binary for v1, preferably as generated C/Objective-C data under `core/profiles`.
- Store mutable values through state providers. Current providers: `LHEmbeddedStateProvider`, `LHLocalStateProvider`, and `LHPackageStateProvider`.
- Default KDF: HKDF-SHA256 implemented with C/Objective-C-compatible Apple crypto APIs. Opaque derivation labels are inputs to derivation only and must not be stored next to derived names.
- Default mutable state encoding: binary property list with a schema version. JSON is acceptable only for debug export/import tools, not target-process runtime state.
- Default scope is per app install. Supported policy scopes are
  per-app-install, per-app, per-vendor group, and custom seed/manual linked
  group. Manual linked behavior is represented by reusing custom seeds, not by
  adding another runtime scope.
- Never disable all hooks as the normal response to one failure. Every mitigation needs a documented generic fallback. If no coherent fallback is available, pass through only the affected value.
- First mitigation group: `UIDevice.identifierForVendor`, device boot time, and volume initialization or creation time.
- The first mitigation group must be complete enough to evaluate limits: hook Objective-C/Foundation and C/Darwin layers that expose the same values.
- Temporal ordering is mandatory: synthetic volume initialization or creation time must be earlier than synthetic last boot time, and generated dates must form a plausible timeline by construction.
- Storage guard hooks are manual hardening backlog. Opaque seed-derived names are the primary defense.
- Testing automation is backlog. Initial validation uses manual Loupe comparisons.
- Custom build website is last, after local deterministic dylib and `.deb` builds work.

## Phase 0: Source Skeleton

Status: complete.

Completed in commit `7dec2d9` with follow-up artifact output cleanup in
`c034790`. The current build produces a signed dylib at `dist/runtime.dylib`
and `make audit` validates the release artifact.

Create the source layout without active spoofing.

Files/directories to create:

- `core/include/`
- `core/src/`
- `core/profiles/`
- `packages/tweak/`
- `packages/tweak/Makefile`
- `packages/tweak/sources/`
- `packages/tweak/filters/`
- `scripts/build/`
- `scripts/verify/`
- `docs/options/`

Implementation tasks:

- Add root Makefile or documented build command that builds the dylib target.
- Add a minimal Theos tweak Makefile for arm64 iOS.
- Add a safe constructor that initializes once and does nothing visible.
- Add release/debug build flags:
  - `LH_ENABLE_VARIABILITY`
  - `LH_ENABLE_DIAGNOSTICS`
- Add static build-selection files:
  - `config/mitigations.json`
  - `config/build.default.json`
- Add generated build inputs:
  - Theos mitigation source fragment
  - generated mitigation registry header/source
- Add scripts for local binary audit:
  - string scan
  - exported symbol scan
  - Mach-O summary
  - dylib signing check

Acceptance checks:

- `make` or the documented build command produces a `.dylib`.
- `ldid -S` can sign it.
- `file`, `otool`, and `nm` can inspect it.
- Release build has no debug logs and no project-identifying runtime strings.
- The dylib contains no Swift runtime dependency.

## Phase 1: Core Types and Hook Backend

Status: complete.

Completed after Phase 0. The runtime boundary, generated mitigation registry,
seed/scope helpers, named scope-mode initializers, and Theos-compatible hook
backend are present. `make seed-check` validates UUID parsing, deterministic
scoped derivation, different scope outputs, and opaque-name reproduction. `make
policy-check` validates the generated policy value-query boundary and resolver
table. `make audit` validates the selected mitigation and policy-value
registries through the signed dylib build.

Create the runtime boundary before adding real mitigations.

Core modules:

- `LHPolicyEngine`
- `LHProfile`
- `LHAppContext`
- `LHScope`
- `LHSeed`
- `LHValueQuantizer`
- `LHCompatibility`
- `LHHookBackend`

Implementation tasks:

- Define `LHScopeMode` with:
  - per app install
  - per app
  - per vendor group
  - custom seed/manual linked group
- Implement per-app-install scope resolution first, with an opaque random marker
  in app data.
- Resolve vendor-group scope from original pre-spoof IDFV when available.
- Use fresh random alphanumeric scope identifiers when scope input is missing,
  empty, or too long to copy safely.
- Implement UUID instance seed parsing and validation without restricting the UUID version.
- Implement KDF/keyed hash helpers for scoped seeds and opaque names.
- Implement `LHHookBackend` with Theos/Logos/MobileSubstrate-compatible entry points first.
- Support imported C-symbol rebinding behind `LHHookBackend` for call sites that
  do not reliably pass through a patched shared implementation.
- Keep hook modules as adapters: hooks must call policy APIs, not invent values.
- Use generated policy value queries instead of adding one top-level policy-engine accessor or central switch branch per future surface.

Acceptance checks:

- A test or small debug command can derive stable scoped seeds from the same UUID instance seed.
- Different scopes produce different derived seeds.
- Reusing the same instance seed and scope input reproduces the same derived identifiers.
- Hook backend can register no-op hooks selected through the generated mitigation registry.

## Phase 2: Profile and State Providers

Status: complete for the current embedded, local, and package providers.

Implemented embedded profile metadata, runtime scope configuration, local,
embedded, and package state-provider paths, binary property-list state encoding,
opaque seed-derived state filenames, seed-derived timeline values, and
mitigation-owned state blobs. `make state-check` validates local persistence,
embedded fallback, binary plist round-trip behavior, generic blob loading, and
opaque state filenames. Phase 3 manual Loupe validation confirmed these
providers support the current first mitigation group, and Phase 5 package checks
validate the package-owned state path.

Implement profile data and state access without coupling mitigation code to a
specific storage backend.

Providers:

- `LHEmbeddedStateProvider`: deterministic, read-only defaults.
- `LHLocalStateProvider`: per-app sandbox/local testing state.
- `LHPackageStateProvider`: package-owned rootless state for `.deb` installs.

Implementation tasks:

- Compile first cohort profile metadata directly into the binary.
- Derive first-mitigation state values from the active instance seed and scope;
  do not store concrete boot age, volume age, or scope/seed epoch constants in the
  profile.
- Encode mutable state blobs as binary property lists with explicit schema versioning.
- Define each mutable state blob shape in the resolver or mitigation source that
  owns it. Core state providers should only know the state key, schema version,
  byte length, generated bytes callback, and opaque payload bytes.
- Declare derivation label IDs in the owning resolver or state-domain source
  with `LH_DERIVATION_LABEL(domain, name)`, and use generated seed-bound
  `LHDerivationLabel` constants in resolver or mitigation sources.
- Derive storage names from the instance seed and scope. Do not use readable prefixes.
- Implement generic fallback values per mitigation.

Acceptance checks:

- No profile values are hardcoded in hook modules.
- Concrete temporal state values are derived from the active seed and scope.
- Mutable state blobs round-trip through binary property list encoding.
- Local state survives app relaunch where the backend supports persistence.
- Embedded state can run without writable storage.
- State filenames and keys are opaque and seed-derived.

## Phase 3: First Mitigation Group

Status: complete.

Implemented the first mitigation group as policy-driven hooks for IDFV,
boot-time surfaces, and Foundation volume creation date APIs. Boot time is
selected through a catch-all composite mitigation that imports sysctl-family and
`NSProcessInfo.systemUptime` adapters. Hook modules are thin adapters around
policy accessors and pass through only the affected API when hook installation
or policy lookup fails. Manual Loupe validation passed on 2026-06-18. Real-device
deployment and Loupe comparison remain manual and out of scope for repo
automation.

Implement IDFV, boot time, and volume initialization or creation time together.

IDFV tasks:

- Hook `UIDevice.identifierForVendor`.
- Return a per-scope stable UUID from policy state.
- Support generic fallback if state cannot provide a UUID.
- Document option behavior in `docs/options/identity-idfv.md`.

Boot time tasks:

- Hook `sysctl`, `sysctlbyname`, and available underscored syscall entry names
  for `kern.boottime` through function patching and imported-symbol rebinding.
- Hook `NSProcessInfo.systemUptime` as part of the same boot-time composite.
- Identify whether additional APIs in Loupe expose boot/uptime-adjacent values.
- Return a synthetic boot time from the policy timeline.
- Preserve structure, errno behavior, and buffer-size behavior as closely as possible.
- Document option behavior in `docs/options/system-boot-time.md`.

Volume time tasks:

- Hook Foundation storage APIs used by Loupe for volume creation/init metadata.
- Hook lower-level file attribute APIs if needed for temporal alignment:
  - `getattrlist`
  - `stat`/`fstat`/`lstat` where relevant
  - URL resource values where relevant
- Return synthetic volume initialization or creation time from the same policy timeline.
- Document option behavior in `docs/options/storage-volume-time.md`.

Temporal generation tasks:

- Generate boot-time anchor `A1` from the active seed and scope.
- Generate volume time by deriving the same `A1`, deriving a second offset, and
  subtracting the offset so `volumeInitializedAt < lastBootAt < now`.
- Reserve room for later `appInstalledAt` and scope/seed rotation values.

Acceptance checks:

- Manual Loupe run showed IDFV changed according to policy.
- Manual Loupe run showed boot time normalized.
- Manual Loupe run showed volume initialization or creation time normalized.
- Loupe did not observe volume time after boot time.
- Repeated launches showed stable values for the same scope.
- Different app scopes see different per-app values unless shared scope is selected.
- If a mitigation fails, only that affected value uses fallback/pass-through behavior.

## Phase 4: Package Readiness Baseline

Status: complete.

The plain dylib build, generated mitigation/policy registries, seed-derived
names, release/debug build split, and package build inputs are stable enough to
support the rootless package path. `make audit` remains the local dylib
verification entry point; broader static-marker hardening is tracked in the
manual hardening phase near the end of this checklist.

Implementation tasks:

- Keep the plain dylib and package builds using the same generated registry and
  selected mitigation set.
- Keep development builds readable by default while release/custom builds use
  generated static names where configured.
- Ensure build variability never changes observable API values.
- Keep target-process-visible state filenames opaque and seed-derived.

Acceptance checks:

- `make audit` validates the signed release dylib.
- `LH_ENABLE_VARIABILITY=0` produces readable development artifacts.
- `LH_ENABLE_VARIABILITY=1` produces generated internal names where implemented.
- Release audit does not fail on package metadata outside target processes.

## Phase 5: Rootless Deb Package

Status: complete for the first rootless package path.

Implemented a rootless Theos package for the existing runtime. `make package`
builds `dist/com.loupehole.runtime_0.1.0_iphoneos-arm64.deb`, compiles the
dylib with `LHStateProviderKindPackage`, verifies the `/var/jb` package layout,
checks the package filter starts empty, and exercises the Settings store's
default-on UIKit app-class filter plus per-bundle overrides. The package
includes install, upgrade, disable, and uninstall maintainer-script paths. The
package layout, package-owned state parent
directory, package seed root, root seed filename, package policy file, and
loader dylib/filter basename are generated at build time and passed into the
runtime config and maintainer scripts. `LHSeedProvider`
resolves package installs to a persisted root install seed used as the package
practical seed. The default per-app-install scope uses an opaque random marker in
app data so app reinstall rotates the active seed. Custom seed scope uses a
configured UUID as the active seed directly, letting the user deliberately link
the default policy or multiple bundle overrides through the same manual-linked
scope model. The package state provider
stores blobs under package-owned rootless storage outside target app containers,
with derived opaque per-scope state directories and blob filenames. The package
includes `LoupeholePreferences.bundle` as the built-in Settings menu for default
policy settings, per-app overrides, mitigation toggles, global reset, debug
paths/seeds, root seed reset, and scope selection. Device install and behavioral validation
remain manual.

Package the same dylib for jailbreak installation.

Implementation tasks:

- Add rootless Theos package layout.
- Add conservative filter plist.
- Start with no global injection.
- Add maintainer scripts for install, upgrade, disable, and uninstall.
- Implement `LHPackageStateProvider`.
- Implement `LHSeedProvider` for practical seed resolution, package root seed,
  per-app-install markers, and stable scoped seeds.
- Add a first configuration surface for the rootless filter plist and package policy.
- Keep package-owned runtime state outside target app containers.
- Keep target-process-visible state names seed-derived and opaque.
- Derive the package policy config filename from the build seed so the runtime
  can find it before loading the root install seed.
- Remove package-owned policy config together with the generated preferences
  directory on uninstall.

Acceptance checks:

- `.deb` builds locally with `dpkg-deb --root-owner-group`; fakeroot is bypassed
  for the package step to avoid host SYSV IPC failures.
- Package layout installs under `/var/jb`.
- Package loader basename, package root seed, per-app-install marker paths, and
  scoped state paths are generated and opaque.
- Default third-party app targeting, disabled per-bundle overrides, and package
  policy edits work through the Settings store verifier.
- Uninstall removes package-owned dylibs, filter plists, preference bundles, generated manifests, caches, and package-owned config.
- Uninstall does not delete target app containers or app Keychain items unless explicitly requested by the user.
- Reinstall after uninstall does not leave stale filter plists, generated names, or dangling package-owned preferences.

## Phase 6: Configuration and Preferences

Status: complete for package-owned Settings configuration.

Implemented the first package-owned config provider and built-in Settings menu.
The runtime reads the generated build-seed-derived package policy file before
scope and seed resolution, applies the default policy plus the current bundle's
override, and installs only the enabled compiled modules. Package runtime startup
exits before scope/seed setup for system bundles, non-app processes, extensions,
and effectively disabled policies. The package default is off on install; when
enabled, the default policy targets the broad UIKit app class and per-bundle
disabled overrides win. Local/plain dylib development defaults still enable compiled mitigations.
Generated Settings metadata exposes the selected compiled module ID/name map for
the deb, and runtime policy stores numeric module IDs with room for up to 1024
enabled modules. The Settings menu also supports global reset, per-app override
reset, debug seed/path explanations, scope selection, and destructively confirmed
root seed reset. Runtime preferences select targeting, scope, seed, and compiled
mitigation state; profile selection belongs to custom compilation/build profiles.

Add configuration without moving policy into hooks.

Implementation tasks:

- Implement config priority:
  - emergency per-bundle bypass
  - package policy override/default
  - embedded build-time config
  - built-in default policy
- Add default third-party app targeting with per-app overrides. Status: complete
  for the Settings package flow.
- Add mitigation toggles. Status: complete for compiled module IDs through the
  Settings package flow.
- Add scope mode selector. Status: complete for Settings package policy:
  - per app install
  - per app
  - per vendor group
  - custom seed/manual linked group
  Manual linked behavior should reuse custom seeds instead of adding stored
  group/link entities.
- Add seed reset and state rotation controls on top of the existing
  `LHSeedProvider`. Status: complete for package root seed reset in Settings.
- Promote or replace the first bundle toggle helper with a full
  preference/config provider flow. Status: complete for the built-in Settings
  menu.
- Use Swift only for preference UI if needed.

Acceptance checks:

- Changing config changes policy output without hook-code changes.
- Preference identifiers and paths do not leak into target app-visible API returns.
- Scope mode is stored and passed through the state/policy layer for the
  supported package policy modes.

## Phase 7: More Mitigations

Status: backlog after the package/configuration baseline.

Implement remaining MVP and later surfaces after the package/configuration
baseline is stable.

MVP passive targets:

- device/sysctl/uname alignment
- ProcessInfo CPU/RAM/OS
- storage capacity/free/date
- display/safe area
- battery/thermal
- locale/timezone/languages
- pasteboard shape
- network interfaces/hostname/VPN heuristic
- fonts and voices
- Metal/GPU
- URL scheme probing
- Keychain reinstall tracking
- WKWebView navigator/screen/canvas/WebGL basics
- Advertising ID

Rules:

- Every option needs documentation before it can be marked stable.
- Every option needs a generic fallback and rollback behavior.
- Every option must list temporal and value dependencies.
- Permissioned APIs default to compatibility-preserving behavior.

## Phase 8: Storage Guard Hardening

Status: manual hardening backlog.

Add optional hardening for target-visible storage and final release artifacts
after the current package/config baseline.

Implementation tasks:

- Add `StorageGuardHooks`.
- For target-visible Keychain state:
  - filter Loupehole-owned records from broad `SecItemCopyMatching`
  - protect Loupehole-owned records from target-app update/delete when ownership is certain
  - add reentrancy bypass for Loupehole state providers
- For target-visible filesystem storage:
  - evaluate `FileManager`, `open`, `stat`, `getattrlist`, `readdir`, `unlink`, and URL resource-value filtering
  - keep this hardening-only unless a specific implemented storage path needs it
- Extend release/static-marker audits covering:
  - strings
  - exported symbols
  - linked libraries
  - Swift runtime absence
  - debug log absence
  - build timestamp/build ID absence where possible
- Harden mutable state encoding markers:
  - evaluate replacing static binary-plist field keys with generated/keyed field names or a compact binary record
  - keep schema versioning and binary round-trip checks
  - ensure target-process-visible state filenames remain opaque and seed-derived

Acceptance checks:

- Guard hooks never hide unrelated app records.
- Guard hooks leave calls unfiltered when ownership is uncertain.
- Opaque seed-derived names remain the primary defense.
- Release audit fails on project-identifying strings in injected runtime.
- Release audit does not expose useful static mutable-state field markers beyond intentionally generic platform/runtime strings.

## Phase 9: Automated Harness

Status: backlog.

Manual Loupe testing is enough initially.

Implementation tasks:

- Define snapshot schema for observed values.
- Import or recreate Loupe-style probes.
- Compare real, protected, and expected cohort values.
- Report entropy and invariant failures.

Acceptance checks:

- Harness can answer whether hooks applied, apps remained stable, values became less identifying, and contradictions were avoided.

## Phase 10: Custom Build Website

Status: backlog.

Build after local deterministic artifacts are reliable.

Implementation tasks:

- Web UI for target, build profile, modules, filters, and instance seed.
- Let users create a new UUID seed or provide an existing one.
- Compute uniqueness/anonymity-set risk.
- Use macOS workers with Xcode/Theos.
- Compile `.dylib` and rootless `.deb` artifacts.
- Apply build variability to static markers only.

Acceptance checks:

- Shared templates are the default.
- Custom values warn about uniqueness.
- Observable API behavior remains in shared cohorts.
- Artifacts expire and no telemetry is collected beyond operational build status.
