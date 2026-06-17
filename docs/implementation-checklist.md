# Implementation Checklist

This document is the actionable handoff plan for implementing Loupehole from the current planning state. It assumes the decisions in [architecture.md](architecture.md), [execution-plan.md](execution-plan.md), [fingerprinting-surfaces.md](fingerprinting-surfaces.md), and [spoofing-option-policy.md](spoofing-option-policy.md).

## Settled Decisions

- Build locally on macOS with Xcode 26+, Theos, `ldid`, `dpkg-deb`, and `fakeroot`.
- Start with a plain injectable arm64 iOS `.dylib`; package the same runtime into a rootless `.deb` later.
- Real-device deployment and validation are manual: Sideloadly-style owned-app injection or rootless jailbreak package installation.
- The injected runtime must use C, Objective-C, or Objective-C++. Do not use Swift in the dylib. Swift is allowed only for preferences UI or external tooling.
- Use `LHHookBackend` from the first source commit. First implementation is Theos/Logos with MobileSubstrate-compatible hooks. ElleKit/libhooker-specific backends are postponed behind build flags.
- Use a UUIDv4 configuration instance seed. Feed it through a KDF to derive scoped seeds, opaque storage identifiers, state filenames, Keychain service/account names, generated internal names, and optional build variability.
- Compile cohort profile values into the binary for v1, preferably as generated C/Objective-C data under `core/profiles`.
- Store mutable values through state providers. First providers: `LHEmbeddedStateProvider` and `LHLocalStateProvider`. Later providers: `LHPackageStateProvider`, `LHAppGroupStateProvider`, and `LHKeychainGroupStateProvider`.
- Default KDF: HKDF-SHA256 implemented with C/Objective-C-compatible Apple crypto APIs. Purpose labels are inputs to derivation only and must not be stored next to derived names.
- Default mutable state encoding: binary property list with a schema version. JSON is acceptable only for debug export/import tools, not target-process runtime state.
- Default scope is per app. Design scope APIs for per-vendor group, per-shared-app-group, and manual linked group even if only per-app works initially.
- Never disable all hooks as the normal response to one failure. Every mitigation needs a documented generic fallback. If no coherent fallback is available, pass through only the affected value in compatibility mode.
- First mitigation group: `UIDevice.identifierForVendor`, device boot time, and volume initialization or creation time.
- The first mitigation group must be complete enough to evaluate limits: hook Objective-C/Foundation and C/Darwin layers that expose the same values.
- Temporal coherence is mandatory: synthetic volume initialization or creation time must be earlier than synthetic last boot time, and generated dates must form a plausible timeline.
- Storage guard hooks are postponed hardening. Opaque seed-derived names are the primary defense.
- Testing automation is postponed. Initial validation uses manual Loupe comparisons.
- Custom build website is last, after local deterministic dylib and `.deb` builds work.

## Phase 0: Source Skeleton

Status: pending.

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
  - `LH_ENABLE_MODULE_IDENTITY`
  - `LH_ENABLE_MODULE_SYSCTL`
  - `LH_ENABLE_MODULE_STORAGE`
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

Status: pending.

Create the runtime boundary before adding real mitigations.

Core modules:

- `LHPolicyEngine`
- `LHProfile`
- `LHAppContext`
- `LHScope`
- `LHSeed`
- `LHCoherenceGraph`
- `LHValueQuantizer`
- `LHCompatibility`
- `LHHookBackend`

Implementation tasks:

- Define `LHScopeMode` with:
  - per app
  - per vendor group
  - per shared app group
  - manual linked group
- Implement per-app scope resolution first.
- Stub other scope modes so callers can pass them without changing API later.
- Implement UUIDv4 instance seed parsing and validation.
- Implement KDF/keyed hash helpers for scoped seeds and opaque names.
- Implement `LHHookBackend` with Theos/Logos/MobileSubstrate-compatible entry points first.
- Keep hook modules as adapters: hooks must call policy APIs, not invent values.

Acceptance checks:

- A test or small debug command can derive stable scoped seeds from the same UUIDv4 instance seed.
- Different scopes produce different derived seeds.
- Reusing the same instance seed and scope input reproduces the same derived identifiers.
- Hook backend can register no-op hooks behind module flags.

## Phase 2: Profile and State Providers

Status: pending.

Implement profile data and state access with future storage backends in mind.

Providers:

- `LHEmbeddedStateProvider`: deterministic, read-only defaults.
- `LHLocalStateProvider`: per-app sandbox/local testing state.
- `LHPackageStateProvider`: postponed until `.deb` phase.
- `LHAppGroupStateProvider`: postponed until sideloading entitlements are known.
- `LHKeychainGroupStateProvider`: postponed until sideloading entitlements are known.

Implementation tasks:

- Compile a first cohort profile directly into the binary.
- Include first-mitigation defaults in the compiled profile.
- Encode mutable state as binary property lists with explicit schema versioning.
- Store Keychain-backed state, when implemented later, as opaque data values rather than descriptive attributes.
- Define mutable state record shape:
  - instance seed identifier or version
  - scope identifier
  - scoped seed
  - IDFV replacement UUID
  - synthetic boot time
  - synthetic volume initialization or creation time
  - profile epoch
  - state schema version
- Derive storage names from the instance seed and scope. Do not use readable prefixes.
- Implement generic fallback values per mitigation.

Acceptance checks:

- No profile values are hardcoded in hook modules.
- Mutable state records round-trip through binary property list encoding.
- Local state survives app relaunch where the backend supports persistence.
- Embedded state can run without writable storage.
- State filenames and keys are opaque and seed-derived.

## Phase 3: First Mitigation Group

Status: pending.

Implement IDFV, boot time, and volume initialization or creation time together.

IDFV tasks:

- Hook `UIDevice.identifierForVendor`.
- Return a per-scope stable UUID from policy state.
- Support generic fallback if state cannot provide a UUID.
- Document option behavior in `docs/options/identity-idfv.md`.

Boot time tasks:

- Hook `sysctl` and `sysctlbyname` for `kern.boottime`.
- Identify whether additional APIs in Loupe expose boot/uptime-adjacent values.
- Return a synthetic boot time from the policy timeline.
- Preserve structure, errno behavior, and buffer-size behavior as closely as possible.
- Document option behavior in `docs/options/system-boot-time.md`.

Volume time tasks:

- Hook Foundation storage APIs used by Loupe for volume creation/init metadata.
- Hook lower-level file attribute APIs if needed for coherence:
  - `getattrlist`
  - `stat`/`fstat`/`lstat` where relevant
  - URL resource values where relevant
- Return synthetic volume initialization or creation time from the same policy timeline.
- Document option behavior in `docs/options/storage-volume-time.md`.

Temporal coherence tasks:

- Generate a timeline where `volumeInitializedAt < lastBootAt < now`.
- Reserve room for later `appInstalledAt`, `profileEpoch`, and profile rotation values.
- Add policy checks that reject contradictory generated timelines.

Acceptance checks:

- Manual Loupe run shows IDFV changed according to policy.
- Manual Loupe run shows boot time normalized.
- Manual Loupe run shows volume initialization or creation time normalized.
- Loupe does not observe volume time after boot time.
- Repeated launches see stable values for the same scope.
- Different app scopes see different per-app values unless shared scope is selected.
- If a mitigation fails, only that affected value uses fallback/pass-through behavior.

## Phase 4: Dylib Audit and Build Variability

Status: pending.

Harden the plain dylib before packaging.

Implementation tasks:

- Add release audit script covering:
  - strings
  - exported symbols
  - linked libraries
  - Swift runtime absence
  - debug log absence
  - build timestamp/build ID absence where possible
- Add build-flag-controlled generated internal names.
- Keep development builds readable by default.
- Ensure build variability never changes observable API values.

Acceptance checks:

- `LH_ENABLE_VARIABILITY=0` produces readable development artifacts.
- `LH_ENABLE_VARIABILITY=1` produces generated internal names where implemented.
- Release audit fails on project-identifying strings in injected runtime.
- Release audit does not fail on package metadata outside target process.

## Phase 5: Rootless Deb Package

Status: pending.

Package the same dylib for jailbreak installation.

Implementation tasks:

- Add rootless Theos package layout.
- Add conservative filter plist.
- Start with no global injection.
- Add maintainer scripts for install, upgrade, disable, and uninstall.
- Implement `LHPackageStateProvider`.
- Keep package-owned runtime state outside target app containers.
- Keep target-process-visible state names seed-derived and opaque.

Acceptance checks:

- `.deb` builds locally with `dpkg-deb` and `fakeroot`.
- Package layout installs under `/var/jb`.
- Uninstall removes package-owned dylibs, filter plists, preference bundles, generated manifests, caches, and package-owned config.
- Uninstall does not delete target app containers or app Keychain items unless explicitly requested by the user.
- Reinstall after uninstall does not leave stale filter plists, generated names, or dangling package-owned preferences.

## Phase 6: Configuration and Preferences

Status: pending.

Add configuration without moving policy into hooks.

Implementation tasks:

- Implement config priority:
  - emergency per-bundle bypass
  - jailbreak preference UI profile
  - embedded build-time config
  - built-in default profile
- Add per-app allowlist.
- Add module toggles.
- Add profile selection.
- Add scope mode selector:
  - per app
  - per vendor group
  - per shared app group
  - manual linked group
- Add seed reset and state rotation.
- Use Swift only for preference UI if needed.

Acceptance checks:

- Changing config changes policy output without hook-code changes.
- Preference identifiers and paths do not leak into target app-visible API returns.
- Scope mode is stored and passed through the state/policy layer even if only per-app is complete initially.

## Phase 7: More Mitigations

Status: postponed.

Implement remaining MVP and later surfaces after the first mitigation group is stable.

MVP passive targets:

- device/sysctl/uname coherence
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
- Every option must list coherence and temporal dependencies.
- Permissioned APIs default to compatibility-preserving behavior.

## Phase 8: Storage Guard Hardening

Status: postponed.

Add optional anti-detection guard hooks for target-visible storage.

Implementation tasks:

- Add `StorageGuardHooks`.
- For shared Keychain state:
  - filter Loupehole-owned records from broad `SecItemCopyMatching`
  - protect Loupehole-owned records from target-app update/delete when ownership is certain
  - add reentrancy bypass for Loupehole state providers
- For shared App Group/file storage:
  - evaluate `FileManager`, `open`, `stat`, `getattrlist`, `readdir`, `unlink`, and URL resource-value filtering
  - keep this strict-mode or hardening-only unless needed earlier

Acceptance checks:

- Guard hooks never hide unrelated app records.
- Guard hooks leave calls unfiltered when ownership is uncertain.
- Opaque seed-derived names remain the primary defense.

## Phase 9: Sideloaded Shared Storage Providers

Status: postponed.

Only implement after the signing setup is known.

Implementation tasks:

- Implement `LHAppGroupStateProvider` for apps signed with a common App Group entitlement.
- Implement `LHKeychainGroupStateProvider` for apps signed with a common Keychain Access Group entitlement.
- Keep state names opaque and seed-derived.
- If neither entitlement exists, use local per-app state or embedded config only.

Acceptance checks:

- Separately sideloaded apps do not claim shared writable state unless entitlements actually allow it.
- Reusing the same instance seed across entitled apps reproduces matching shared state names and values.

## Phase 10: Automated Harness

Status: postponed.

Manual Loupe testing is enough initially.

Implementation tasks:

- Define snapshot schema for observed values.
- Import or recreate Loupe-style probes.
- Compare real, protected, and expected cohort values.
- Report entropy and coherence failures.

Acceptance checks:

- Harness can answer whether hooks applied, apps remained stable, values became less identifying, and contradictions were avoided.

## Phase 11: Custom Build Website

Status: postponed.

Build after local deterministic artifacts are reliable.

Implementation tasks:

- Web UI for target, profile, modules, filters, and instance seed.
- Let users create a new UUIDv4 seed or provide an existing one.
- Compute uniqueness/anonymity-set risk.
- Use macOS workers with Xcode/Theos.
- Compile `.dylib` and rootless `.deb` artifacts.
- Apply build variability to static markers only.

Acceptance checks:

- Shared templates are the default.
- Custom values warn about uniqueness.
- Observable API behavior remains in shared cohorts.
- Artifacts expire and no telemetry is collected beyond operational build status.

## First Coding Task

Status: pending.

Start with Phase 0 and Phase 1 only:

1. Create source directories and minimal Theos dylib target.
2. Add no-op constructor and module registry.
3. Add C/Objective-C/Objective-C++ core scaffolding.
4. Add `LHHookBackend` abstraction with first Theos/Logos-compatible implementation.
5. Add local audit scripts.
6. Build, sign, and audit the empty dylib.

Do not implement spoofed values until this skeleton builds and audits cleanly.
