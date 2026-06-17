# Execution Plan

## Project Mission

Build a privacy-preserving iOS tweak/library that can be injected into user-selected apps to reduce abusive fingerprinting. It should cover the API families demonstrated by Loupe and grow into a broader anti-fingerprinting framework for native iOS and embedded WebKit.

The project must balance privacy, app compatibility, and non-uniqueness. The best protection is not maximum spoofing. The best protection is a coherent, plausible, common profile that many users can share.

## Guiding Principles

1. Prefer normalization over randomization.
2. Keep spoofed values internally consistent across APIs.
3. Use per-app stable values where an identifier must exist.
4. Avoid unique combinations created by user over-customization.
5. Preserve app functionality unless the user explicitly chooses strict blocking.
6. Never add telemetry.
7. Do not ship hardcoded values that identify the tweak, project, or custom build from inside target app processes.
8. Prefer common defaults found on normal devices and networks when a spoofed value needs a default.
9. Document every option and suboption in detail before treating it as implemented, both in the codebase and the end user documentation, everywhere
10. If possible, have new installations of the application clear the previously stored data when first launched (this should be configurable, and extended to shared app bundles. tweak should win the race and perform the cleanup before the app is really launched)
11. Target iOS 15 -> iOS 26 (even if later not jailbrakable)

## Threat Model

In scope:

- Native app SDKs reading public iOS APIs to correlate users across sessions.
- Embedded WKWebView fingerprinting through JavaScript, canvas, WebGL, locale, screen, and timing APIs.
- Permissioned APIs being used for more tracking than the user expected.
- Reinstall tracking through Keychain and app container artifacts.
- App-installed persistent IDs stored in common local stores.
- Server correlation through device-side signals the app transmits.

Partially in scope:

- Network-layer IP and TLS fingerprinting. The tweak can reduce app-visible proxy/VPN indicators but cannot hide the public IP by itself.
- App Attest, DeviceCheck, APNs tokens, and other Apple security services. These should usually pass through or be disabled per app only when the user accepts breakage.

Out of scope:

- Jailbreak/tweak detection. The project should avoid unnecessary markers, but not become an anti-tamper bypass toolkit.

## Product Tracks

### Track A: Precompiled Privacy Tweak

Purpose:

- A default, stable, high-compatibility package intended for jailbreak injection into selected apps.

Outputs:

- Rootless `.deb`.
- Optional rootful `.deb` if legacy support is justified.
- A plain `.dylib` artifact for research/test hosts.
- Default profile: "Cohort Standard."

Behavior:

- Normalize high-entropy passive APIs.
- Reduce WebView fingerprinting.
- Guard Keychain reinstall tracking.
- Leave permissioned data mostly pass-through in compatibility mode, with optional coarse/empty responses per category.
- Per-app stable seeds for IDFV-like values and synthetic values.

### Track B: Custom Build Website

Purpose:

- Allow users/researchers to compile variants with selected modules and profiles.
- Avoid every build having the same static signature.
- Allow an interactive way of exploring each anti-fingerprinting method 

Important constraint:

- The website must not encourage one-off unique fingerprints. It should show an "anonymity set risk" score and steer users toward shared cohort profiles.

Outputs:

- Custom `.deb` for jailbreak installation.
- Custom `.dylib` for developer-owned test injection.

Controls:

- Module toggles.
- Profile choice.
- Bundle filter allowlist.
- Optional preference pane inclusion.
- Build metadata stripping.
- Randomized internal symbol prefix and section layout, while keeping observable API behavior in a common cohort.

### Track C: Jailbreak Preference UI

Purpose:

- Provide device-wide and per-app control when installed on a jailbroken system.

Components:

- Settings bundle or preference pane.
- Per-app profile assignment.
- Quick toggles for passive, WebView, storage/Keychain, permissioned, and network modules.
- Diagnostics screen for the user's own test app only.

Stealth-aware defaults:

- No always-on in-app overlay.
- No network calls.
- No verbose logs unless explicitly enabled.
- Preferences stored outside target app containers.
- Tweak loads only into selected app bundles by default.

Brainstormed menu structure:

- Global mode: off, compatibility, standard, strict.
- Protected apps: per-bundle allowlist with search, presets, and emergency bypass.
- Profile: device cohort, locale cohort, WebView cohort, identifier lifetime.
- Passive surfaces: identity, system, storage, display, battery, locale, accessibility, pasteboard, network, fonts/voices, GPU, telephony.
- WebView: navigator, screen, canvas, WebGL, audio, storage quota, timing, media devices.
- Permissioned surfaces: location, camera, Bluetooth, local network, contacts, photos, calendar, reminders, music, motion/fitness.
- Persistence: reset app seed, reset synthetic install date, clear protected Keychain namespaces, clear WebKit data for selected app.
- Uniqueness meter: explains whether the selected config is common, uncommon, or highly unique.
- Diagnostics: disabled by default, temporary per-app logging, export own-device probe report.
- Safety: exclude critical/system apps, restore defaults, uninstall helper, panic toggle.

Good defaults:

- New installs start with no app selected.
- App-specific strict mode warns that functionality may break.
- Changing profile values requires confirmation because it may rotate identifiers.

## Development Environment

The canonical local environment is macOS with Xcode and Theos. The first build target is a plain arm64 iOS dylib; Theos packaging follows once that dylib has the final runtime shape.

Required local tools:

- Xcode 26+ with the iPhoneOS SDK.
- Theos, updated regularly.
- `ldid` for ad hoc signing jailbreak/test artifacts.
- `dpkg-deb` and `fakeroot` for rootless `.deb` assembly.
- `make`, `clang`, `xcrun`, `plutil`, `otool`, `nm`, `strings`, `strip`, `file`, `jq`, `rg`, and `git`.
- Node.js/npm for the later custom build website.
- Ruby/Bundler/Fastlane only when working on upstream Loupe App Store automation or if the builder adopts Fastlane for screenshots/metadata; it is not required for the tweak MVP.

Runtime language choice:

- The injected runtime uses C, Objective-C, and Objective-C++ only.
- Swift is reserved for the optional preference UI and external tooling.

Verified local baseline as of 2026-06-17:

- Xcode 26.5 and iPhoneOS SDK 26.5 are installed.
- Theos is installed at `/Users/alex/theos` and updated to commit `9bc7340`.
- `ldid`, `dpkg-deb`, and `fakeroot` are installed.
- A minimal arm64 iOS dylib can be compiled with Xcode clang and signed with `ldid`.
- The upstream Loupe project is cloned in `.research/upstream/loupe` and remains ignored by Git.

Current workflow constraints:

- Real-device deployment and validation are manual. Supported artifact paths are a plain `.dylib` for Sideloadly-style owned-app injection experiments, and a rootless `.deb` for jailbreak package installation.
- The repository should not require `ios-deploy`, `ideviceinstaller`, or simulator automation for the first milestones.
- No Apple code-signing identity is required for the Theos/rootless package path. Xcode app builds for upstream Loupe or a signed harness app will need a developer team and signing identity.
- The build website should eventually run on macOS workers with this same Xcode/Theos toolchain.

Suggested ways of working:

- Fast dylib loop: build a plain `.dylib`, run local binary audits, then hand the artifact to the manual Sideloadly/injection workflow.
- Package loop: build the rootless `.deb`, inspect its layout and maintainer scripts locally, then hand the package to manual device installation.
- Harness loop: compare Loupe-style probe output before and after injection, but keep capture/import manual until the package and preference flows stabilize.
- Website loop: defer until the local Makefile/Theos build can produce deterministic artifacts from shared profile templates.

## Detection Resistance and Self-Fingerprinting

The project should reduce its own fingerprint without becoming an app-security bypass toolkit.

Acceptable goals:

- Avoid stable public symbols, class names, file names, log strings, and build IDs.
- Keep runtime behavior boring: low overhead, no crashes, no visible UI inside protected apps, no network calls.
- Support build variability for static artifacts.
- Load only where configured.
- Avoid config files inside target app containers.
- Make all observable API behavior match a shared cohort profile.

Partially in scope goals:

- Hiding from app integrity systems by forging security API results. This tweak should not be an anti anti-jailbreak tool, but should try to emulate the built-in APIs that can be abused for tracking

Out-of-scope goals:

- Masking malicious instrumentation.
- Piracy

Practical techniques:

- Strip symbols and avoid descriptive exported names.
- Generate internal prefixes at build time.
- Compile only selected modules into custom builds.
- Keep optional preference UI in a separate package, at best also randomized
- Avoid debug logs, environment variables, and injected resources in target containers.
- Prefer app allowlists over global injection.
- Use a small stable ABI between hooks and policy engine.
- Fail open on unsupported OS/API versions.
- Keep spoofed values in profile data, not directly in hook implementation code.
- Audit release binaries for project-specific strings, debug markers, static build IDs, unique salts, and project-specific JavaScript globals.
- Ensure generated names never leak through public API returns, errors, WebView globals, or target app-visible paths.

Important warning:

- Randomizing observable values per user is counterproductive. A custom build should vary the binary enough to avoid one static signature, but the values returned to apps should remain in common anonymity sets.

## Spoofing Option Documentation Standard

Every option and suboption must include a detailed explanation before it can ship:

- How the original API works.
- How a normal app calls it.
- What a normal device returns.
- How trackers turn it into a fingerprint.
- How the mitigation changes the result.
- Which value lifetime is used: pass-through, cohort-static, per-app stable, session-stable, slowly varying, bucketed, denied, or ephemeral.
- Which other APIs must stay coherent with it.
- Which defaults are used and why those defaults are common on normal devices.
- What can break when the option is enabled.
- How the option can make the user more unique if configured badly.
- How the harness verifies the option.

This is a release gate. A hook without this documentation is experimental, even if the code works.

The detailed policy and template live in [spoofing-option-policy.md](spoofing-option-policy.md).

## Common Defaults

When defaults are needed, prefer common real-world values. Examples:

- Use common private network templates such as `192.168.1.0/24`; use `192.168.1.1/24` when representing a common gateway/router and a non-gateway host address such as `192.168.1.23/24` when representing the device interface.
- Use complete real Apple device profiles instead of mixing arbitrary screen, CPU, GPU, camera, and WebKit values.
- Use common locale/timezone/language groups rather than rare combinations.
- Use normal system font and voice baselines rather than tiny synthetic lists.
- Use broad buckets for battery, storage, thermal, timing, and sensor values.

## Recommended Architecture

Use a layered design:

1. Policy engine: decides what each API should return for a given app, profile, and context.
2. Coherence graph: keeps device model, OS, screen, CPU, GPU, camera, RAM, and WebKit values plausible together.
3. Hook modules: small isolated modules per framework/API family.
4. Persistence guard: mediates app-generated stable identifiers where feasible.
5. WebView injector: applies JavaScript-level and native WebKit mitigations.
6. Config provider: embedded default config, optional jailbreak preferences, no remote config.
7. Test harness: compares real vs protected values using Loupe-like probes.

## Repository Structure

```text
loupehole/
  README.md
  docs/
    execution-plan.md
    architecture.md
    fingerprinting-surfaces.md
    research-notes.md
  packages/
    tweak/
      Makefile
      control
      filters/
      sources/
    prefs/
      Makefile
      sources/
  core/
    include/
    src/
    profiles/
  web-builder/
    api/
    worker/
    ui/
  harness/
    ios-probe-app/
    wkwebview-probes/
    fixtures/
  scripts/
    build/
    verify/
```

## Implementation Sequence

The project should proceed in artifact-sized steps, while keeping the final modular architecture from the first commit that adds source code.

The trackable handoff checklist for implementation lives in [implementation-checklist.md](implementation-checklist.md). A new agent should use that file as the source of truth for what to build next and how to verify it.

### Step 1: Minimal Injectable Dylib

Goal:

- Produce a loadable arm64 iOS dylib with a safe constructor, generated/internalized names, a module registry, hook backend abstraction, and no active spoofing yet.

Exit criteria:

- The dylib builds locally, signs with `ldid`, strips release symbols, and passes a string/symbol audit.
- No project-identifying strings are present in the injected runtime except unavoidable development-only artifacts.
- Hook modules can be compiled in or out without changing observable API behavior.
- `LHHookBackend` exists with a Theos/Logos MobileSubstrate-compatible implementation first; alternate ElleKit/libhooker-specific backends are deferred behind build flags.

### Step 2: Policy Engine and First Mitigation

Goal:

- Implement the core policy/profile/state path and the first low-risk passive mitigation group end to end: IDFV replacement, device boot time normalization, and volume initialization or creation time normalization.

Exit criteria:

- Hook code calls the policy engine instead of embedding spoofed values.
- The selected mitigations have option documentation, default profile data, coherence notes, and harness probes.
- The policy engine enforces temporal coherence: synthetic volume initialization or creation time must be earlier than synthetic last boot time, and related dates must form a plausible timeline.
- `LHEmbeddedStateProvider` and `LHLocalStateProvider` exist so early dylib tests can run before package state is available.
- A UUIDv4 configuration instance seed exists and is used through a KDF to derive scoped seeds and opaque state identifiers.
- Each first mitigation has a documented generic fallback; compatibility mode may pass through only for the affected mitigation when no coherent fallback is available.

### Step 3: Dylib Mitigation Expansion

Goal:

- Add MVP passive modules behind independent switches before packaging complexity grows.

Exit criteria:

- The dylib covers an initial Loupe-style passive subset.
- Runtime overhead, crash behavior, exported symbols, strings, and debug logs are audited.
- The default embedded profile is coherent across implemented surfaces.
- Build variability is controlled by build flags, with readable development builds and stricter generated names/audits for release or custom builds.

### Step 4: Rootless Deb Package

Goal:

- Package the same dylib as a clean rootless `.deb`.

Exit criteria:

- The package installs under `/var/jb`, uses a conservative filter plist, and starts with no global injection.
- Package scripts support clean install, upgrade, disable, and uninstall.
- Uninstall removes package-owned dylibs, filter plists, preference bundles, generated manifests, caches, and package-owned config, without deleting protected app data unless the user explicitly requested cleanup.

### Step 5: Configuration and Preferences

Goal:

- Add embedded config, package-owned config/state, scope selection, and optional jailbreak preference UI without changing hook behavior directly.

Exit criteria:

- Config priority is emergency bypass, preference profile, embedded build config, then built-in default.
- Per-app allowlist, profile selection, module toggles, scope mode, and seed reset work through the config provider.
- Scope mode supports per-app default, per-vendor group, per-shared-app-group, and manual linked groups.
- `LHPackageStateProvider` stores jailbreak package state outside target app containers.
- `LHAppGroupStateProvider` and `LHKeychainGroupStateProvider` are deferred until sideloaded signing entitlements are known.
- Preference identifiers, storage paths, filenames, and Keychain service/account names are derived from the instance seed and do not expose project names or module names to target app processes.

### Step 6: Full Mitigation Coverage

Goal:

- Implement the remaining passive, advanced, WebView, persistence, and permissioned mitigations.

Exit criteria:

- Every stable option has required documentation, harness coverage, defaults, drawbacks, rollback behavior, and coherence dependencies.
- Loupe-style reports show fewer high-entropy values without obvious contradictions.
- Strict mode behavior is documented as breakage-tolerant and opt-in.

### Step 6.5: Storage Guard Hardening

Goal:

- Add optional anti-detection hardening for Loupehole-owned state records in target-visible storage backends.

Exit criteria:

- Shared Keychain state is hidden from broad target-app `SecItemCopyMatching` queries and protected from target-app update/delete calls when ownership is certain.
- Loupehole state providers have an explicit reentrancy bypass so they can access their own records.
- File/App Group storage guards are optional and strict-mode oriented because filesystem enumeration has a broad API surface.
- Guard hooks never hide unrelated app data and leave the app's storage call unfiltered when ownership is uncertain.

### Step 7: Custom Build Website

Goal:

- Build a website and macOS worker pipeline that compiles shared-template dylib and `.deb` artifacts.

Exit criteria:

- Users can choose profiles, modules, and filters from predefined options.
- Users can create a new configuration instance seed or provide an existing one to reproduce matching generated paths, keys, and scoped values.
- The website warns about uniqueness risk and steers users toward shared cohorts.
- Build variability affects static markers, not observable API behavior.

## Roadmap

### Phase 0: Governance and Scope

Deliverables:

- Project charter and non-goals.
- Supported iOS/jailbreak matrix.
- Legal/ethical usage policy.
- Initial profile definitions.
- Decision on hook backend.
- Initial spoofing option documentation template.
- Release-binary marker audit checklist.

Exit criteria:

- The project can explain what it will and will not do.
- A first device/iOS target is selected.
- No module can be marked stable without option/suboption docs.

### Phase 1: Research Harness

Deliverables:

- A Loupe-inspired local probe app that records every covered API before and after injection.
- WKWebView fingerprint test page.
- Snapshot format for comparing signals.
- Basic entropy/coherence report.

Exit criteria:

- Running the harness produces a matrix of real values, protected values, and inconsistencies.

### Phase 2: Passive Native Core

Deliverables:

- Hooks for IDFV/device identity, sysctl/uname, ProcessInfo, storage resource values, display traits, battery, locale, accessibility flags, pasteboard shape, network interface summaries, fonts, voices, app bundle install date, Apple account/storefront, Metal, and telephony.
- Cohort profile catalog with at least three common device profiles.
- Per-app stable seed derivation.
- Option docs for every passive hook and suboption.
- Binary string/symbol audit to confirm no identifying constants are embedded in the injected runtime.

Exit criteria:

- Loupe passive categories show normalized, coherent, low-entropy outputs.
- Common apps run without obvious breakage.

### Phase 3: Advanced Native Surfaces

Deliverables:

- URL scheme probe policy for `canOpenURL`.
- Keychain reinstall tracking mitigation strategy.
- App container install-date normalization.
- Guardrails for persistent app-generated IDs in Keychain/UserDefaults/files where feasible.
- Detailed docs for each persistence and URL-scheme policy.

Exit criteria:

- Loupe advanced categories are reduced without breaking legitimate URL opening in compatibility profile.

### Phase 4: WebView Protection

Deliverables:

- WKWebView user script injection.
- JS API normalization for navigator, screen, Intl/timezone, canvas, WebGL, audio, fonts, hardware concurrency, storage quota, and timing.
- Native WebKit configuration hooks where needed.
- No project-specific JS globals, function names, comments, or error strings visible to page scripts.
- Detailed docs for every JS and native WebKit suboption.

Exit criteria:

- A browser-style fingerprint test page sees the selected cohort profile.
- Canvas/WebGL results are stable within an app but shared by cohort.

### Phase 5: Permissioned APIs

Deliverables:

- Policy modes for location, camera enumeration, Bluetooth, local network, contacts, photos, calendars, reminders, music, motion/fitness.
- Default compatibility policy.
- Strict policy for high-risk apps.
- Per-app user override UI.
- Detailed docs covering original permission/API behavior, fingerprinting risk, mitigation, and drawbacks for every permissioned suboption.

Exit criteria:

- Permissioned APIs can be passed through, coarsened, summarized, or denied by policy.
- Apps that need permissions can be assigned compatibility profiles.

### Phase 6: Jailbreak Package and Preferences

Deliverables:

- Rootless `.deb`.
- Bundle filter allowlist.
- Preference UI.
- Per-app profile storage.
- Logging/diagnostics disabled by default.

Exit criteria:

- Install, respring, configure, inject, and uninstall flow works on a test device.

### Phase 7: Custom Build Website

Deliverables:

- Web UI for module selection and profile choice.
- macOS build worker.
- Build reproducibility and artifact signing for project-owned packages.
- Build variability that changes static markers without creating unique observable behavior.
- Anonymous build option with no retention.

Exit criteria:

- Users can build from shared templates.
- The UI warns when a custom combination becomes too unique.

### Phase 8: Hardening and Compatibility

Deliverables:

- Crash-safe hooks.
- App allowlist/denylist recommendations.
- Performance budget per module.
- Test matrix across iOS versions and device classes.
- Regression suite using harness snapshots.

Exit criteria:

- Release candidate passes compatibility tests and Loupe-style verification.

## Milestone Plan

M0 - Planning complete:

- This documentation set.
- Initial scope and architecture.

M1 - Harness complete:

- Probe app and WebView test page.
- Baseline reports from at least two physical devices.

M2 - Passive MVP:

- Native passive modules working in a development host app.
- First coherent cohort profile.

M3 - Jailbreak MVP:

- Rootless `.deb`.
- Inject into selected bundles.
- Per-app compatibility profile.

M4 - WebView MVP:

- JS fingerprint tests normalized.
- Canvas/WebGL/audio strategy validated.

M5 - Permissioned controls:

- Strict and compatibility policies.
- Preference UI.

M6 - Custom builder:

- Build website and macOS worker.
- Shared template builds.

M7 - Public beta:

- Documentation, known issues, safe-use policy, uninstall path.

## Development Approach

Use macOS as the canonical build environment. Theos is cross-platform, but modern rootless jailbreak work and arm64e edge cases are smoother and sometimes only practical with Xcode's macOS toolchain. A Linux CI runner can lint docs, run web tests, and maybe build non-arm64e artifacts, but release artifacts should come from macOS workers.

Keep the injected core small and boring:

- C/Objective-C/Objective-C++ for runtime hooks.
- Do not use Swift in the injected dylib; reserve Swift for optional preferences UI or tooling.
- Split modules by framework to reduce blast radius.
- Use lazy initialization.
- Prefer per-mitigation generic fallbacks; pass through only the affected mitigation in compatibility mode when a coherent fallback is not available.

## Best Privacy Strategy

The "perfect" practical approach is herd privacy:

- Each app sees a stable profile for that app.
- Many users share the same profile values.
- Values are plausible for a real Apple device.
- Cross-API contradictions are avoided.
- Values that must vary over time vary in broad buckets.
- Sensitive permissions are coarsened or summarized rather than replaced with strange fake detail.
- Users can choose stricter blocking per app, but the default avoids making them stand out.

Examples:

- Do not report an iPhone 15 Pro model with an iPad screen, an A12 GPU, 8 CPU cores, and a camera list from a different generation.
- Do not randomize battery to a unique decimal every request. Bucket it and make it change slowly.
- Do not let a custom profile expose rare language, timezone, accessibility, font, and voice combinations unless the user explicitly accepts the uniqueness risk.
- Do not make every custom build produce unique observable API values. Build variability should mostly affect static binary markers, not privacy behavior.

## Main Challenges

- Swift and Objective-C APIs often sit above C/Darwin APIs; both layers may need hooks for consistency.
- Apps can measure contradictions and timing side effects.
- Some APIs are read-only views into real hardware, and overly fake values can break rendering, media, camera, or network behavior.
- Permissioned data is often functional data. Blocking it globally will break apps.
- WebKit fingerprinting has a very broad JS surface.
- Random builds can become unique artifacts.
- Jailbreak environments vary widely.
- App updates can change probing behavior.
- Apple platform APIs evolve every year.

## Available Solutions

- Cohort profiles for low uniqueness.
- Per-app stable seeds for identifiers.
- Coherence graph for plausible device bundles.
- Compatibility/standard/strict modes.
- Module-level hooks with per-mitigation generic fallback behavior.
- WebView user scripts plus selected native WebKit hooks.
- Rootless Theos package for jailbreaks.
- macOS build worker for custom artifacts.
- Loupe-style regression harness.
