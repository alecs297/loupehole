# Spoofing Option Policy

This document defines requirements for the final tweak, its configuration system, and every spoofing option/suboption.

## Non-Identifying Constants

The injected runtime must not contain hardcoded values that allow apps to identify the tweak, the project, or a specific custom build.

Avoid hardcoding identifiable markers in:

- Exported symbols.
- Objective-C class names and category names.
- Swift module names in injected code.
- C string literals.
- Log tags.
- File names and directory paths.
- Preference keys read from inside target app processes.
- Keychain service/account names.
- Mach service names.
- XPC labels.
- Bundle IDs used by the injected runtime.
- User-Agent fragments or JavaScript patch names.
- Error messages visible to target apps.
- Static build IDs, timestamps, salts, or UUIDs.
- Debug-only strings accidentally left in release builds.

Rules:

- The injected dylib should not contain project branding such as `Loupehole` except where unavoidable in package metadata outside the target app process.
- Hook code should not embed spoofed values directly. Values should come from a profile table or generated build config.
- Custom builds may randomize internal names, but returned API values must stay inside shared, plausible cohorts.
- Build-time generated names must not be unique observable API values.
- Release builds must strip symbols and disable logs by default.
- Diagnostics strings may exist only in a separate diagnostics build or preference component, not in the normal injected runtime.
- If a constant is needed by a hook, it must be classified as either a shared cohort value, an Apple/public API name, or an internal generated value.

Acceptable hardcoded values:

- Apple framework/API names required for hooking.
- Public enum names or selector names needed to call system APIs.
- Shared cohort defaults that plausibly occur on many normal devices.
- Generic values such as `unknown`, `unavailable`, `iPhone`, or `Wi-Fi`, when they match platform behavior.

Unacceptable hardcoded values:

- Unique salts shared across all installs.
- Project-specific Keychain services.
- Project-specific target-visible storage filenames or keys.
- Project-specific JS globals.
- Project-specific class prefixes in target processes.
- Rare fake defaults that normal devices almost never expose.
- A single universal synthetic device profile if it becomes a recognizable signature.

## Instance Seed and Storage Names

Each configuration instance should have one high-entropy instance seed. The seed lets a user recreate or continue the same Loupehole instance across rebuilt dylibs or packages without manually tracking every generated path, key, and scoped value. The seed must never be returned through protected app APIs and must not be exposed to page scripts.

The build-selection instance seed should derive generated labels, generated
package names, and deterministic dylib/local practical seed material. For debs,
the package root install seed is the practical seed used for runtime value
derivation. The practical seed should derive:

- Scoped per-app-install, per-app, per-vendor, and custom/manual-linked seeds.
  Custom seed scope uses the configured UUID as the active seed directly.
- State record identifiers.
- Package-owned and target-visible storage filenames.
- Keychain service/account names.
- Package-owned internal state filenames.
- Concrete timeline values such as boot time, volume creation time, and
  scope/seed rotation epoch.
- Optional generated internal symbol or class prefixes, if those names cannot become app-visible API values.

Storage-name rules:

- Do not use readable project names, module names, mitigation names, or obvious prefixes in filenames, preference keys, Keychain service names, Keychain account names, or target-visible storage records.
- Derive storage names with a keyed hash or KDF from the practical seed, purpose label, scope mode, and stable scope identifier.
- Keep purpose labels internal to derivation code; do not store them next to the derived value.
- Reusing the same practical seed and stable scope inputs should recreate the same derived paths and keys, except per-app-install scope, which also depends on a random app-container marker. Reusing the same custom seed intentionally recreates the same active seed across selected apps or installs.
- Rotating the practical seed should rotate every derived storage name and scoped value unless the user explicitly migrates state.
- Release audits must search binaries, scripts, generated config, and package layouts for accidental project-identifying storage names.
- Mutable state field names inside target-process runtime storage should avoid readable project, module, or mitigation names. Short generic binary-plist keys are acceptable for the initial local provider, but a later hardening pass should evaluate generated/keyed field names or a compact binary record format to reduce static markers.

Storage guard hooks:

- Hooking Keychain or filesystem APIs to hide Loupehole-owned state is allowed as a hardening feature, but it must not replace opaque seed-derived storage names.
- Guard hooks may filter or protect only records that are provably derived from the active instance seed and scope.
- Guard hooks must not hide unrelated app data, unrelated Keychain records, or user files.
- Loupehole's own state provider must have an explicit reentrancy bypass.
- Storage guard hooks should leave the app's storage call unfiltered when Loupehole ownership cannot be proven.

## Coverage Requirement

The final tweak must include every spoofing method that makes sense in at least one legitimate privacy scenario.

"Makes sense" means:

- It reduces a real fingerprinting surface.
- It can be explained and tested.
- It has a clear default behavior and an explicit opt-in path for higher-breakage behavior.
- It does not make the protected device more unique than the original value.

Every method should be available as one of these policy behaviors:

- Pass-through: return the original API result.
- Empty/denied: return no data or a platform-normal denial.
- Coarse: reduce precision while preserving rough meaning.
- Bucketed: map high-cardinality values into common ranges.
- Cohort-normalized: return values from a common profile shared by many users.
- Per-app pseudonymous: derive a stable app-specific replacement identifier.
- Session-stable: keep a synthetic value only for the current app process lifetime.
- Slowly varying: change values on a realistic schedule in broad buckets.
- User-action gated: allow behavior only after a plausible foreground/user action.
- Partitioned: isolate storage or identifiers by app/scope.
- Ephemeral: reset data on app close or scope/seed reset.
- Native hook: intercept Objective-C/C/Swift-visible native APIs.
- JavaScript shim: normalize WebView/browser APIs before page scripts run.
- Rate limited: reduce sampling frequency for sensors/timing.
- Smoothing/noise: add low-risk deterministic perturbation without becoming unique.

Each surface should expose all behaviors that are technically and ethically appropriate. For example, location can support pass-through, coarse, region-only, session-stable synthetic, or denied. DeviceCheck/App Attest should generally support pass-through only, because spoofing those APIs targets security workflows more than privacy fingerprinting.

## Required Documentation Per Option

Every option and suboption must have detailed documentation before it can be considered complete.

Required fields:

- Option ID: stable internal identifier.
- User-facing name: short preference label.
- Status: planned, experimental, beta, stable, deprecated.
- Surface: device identity, WebView, storage, location, etc.
- Affected APIs: classes, functions, selectors, C APIs, JavaScript APIs, and frameworks.
- Permission requirements: whether iOS prompts are involved.
- Default behavior: pass-through, enabled mitigation, coarse, denied, or off.
- Common default: the recommended default value or bucket, with reasoning.
- Original API behavior: how the real API works and what a normal app receives.
- Fingerprinting mechanism: how trackers combine or persist the value.
- Mitigation behavior: exactly what the tweak changes.
- Value lifetime: pass-through, per-app stable, session-stable, slowly varying, or cohort static.
- Value dependencies: other APIs that must agree with this value.
- Temporal dependencies: dates, counters, and lifetimes that must be ordered plausibly.
- Drawbacks: user-visible breakage, app compatibility risks, performance cost, and security implications.
- Detection/uniqueness risk: how the mitigation itself could stand out.
- Test plan: harness checks and expected results.
- Rollback behavior: what happens if the hook fails or the user disables the option.

Suggested markdown template:

```md
### option.id

Name:
Status:
Default:
Affected APIs:
Permissions:

Original API behavior:

Fingerprinting mechanism:

Mitigation behavior:

Common defaults:

Value lifetime:

Value dependencies:

Temporal dependencies:

Drawbacks:

Detection and uniqueness risks:

Test plan:

Rollback:
```

## Common Default Policy

When a spoofing option needs a default value, prefer values that are common on real devices and common networks. The goal is to place users in a large anonymity set.

Rules:

- Prefer default values that appear on normal iPhones/iPads without special setup.
- Prefer broad buckets over exact values.
- Prefer regional profile packs over rare global combinations.
- Prefer boring, popular values over exotic privacy-looking values.
- Avoid values that are technically possible but rare.
- Avoid contradictory values across APIs.
- Avoid overfitting to one device model or one country.

Examples:

- Local network: use common private IPv4 ranges such as `192.168.1.0/24`, `192.168.0.0/24`, or `10.0.0.0/24`. If an API expects a gateway/router, `192.168.1.1/24` is common. If it expects the device interface address, prefer a non-gateway host such as `192.168.1.23/24` while keeping gateway-like values coherent elsewhere.
- Hostname: use generic names such as `iPhone` or `iPad`, not rare personalized names.
- Battery: bucket to common values such as 50, 60, 70, 80, or 90 percent, with realistic charging state.
- Storage: bucket free space to broad ranges rather than exact bytes.
- Locale: use common regional profiles such as `en_US`, `en_GB`, `fr_FR`, `de_DE`, `es_ES`, while keeping timezone, calendar, hour cycle, keyboard languages, and WebView Intl values aligned.
- Timezone: choose a timezone consistent with the locale profile unless the user explicitly chooses a travel profile.
- Screen: choose a complete real device display profile, not hand-mixed dimensions.
- GPU/Metal: choose values matching the selected device profile.
- Fonts/voices: return the normal system baseline for the cohort OS, not a tiny fake list.
- WebView user agent: choose a common Safari/WKWebView string matching the cohort iOS/WebKit version.
- Canvas/WebGL: prefer deterministic cohort-level output rather than per-user random noise.
- Accessibility: default to common settings, but avoid breaking real accessibility needs unless the user explicitly chooses higher-breakage spoofing.

## Temporal Ordering Policy

Generated values must describe a believable device history. Do not generate timestamps, counters, lifetimes, or slowly varying values independently when an app can compare them.

Rules:

- Volume initialization or creation time must be earlier than the last boot time.
- App install time must not predate the volume initialization time.
- Synthetic scope or seed rotation time must not predate identifiers or app-scoped values that it is supposed to reset.
- Slowly varying values such as battery, free storage, thermal state, and uptime-adjacent values must move in plausible directions and buckets.
- If a hook cannot preserve required temporal ordering, use that mitigation's documented generic fallback or pass through only the affected value rather than return a contradictory value.

## Defaults Versus Hardcoding

Common defaults are allowed. Identifying hardcoded constants are not.

The distinction:

- Good: a profile file contains a shared `192.168.1.0/24` network template used by many builds.
- Bad: hook code embeds a unique project string or a unique fake IP range that all protected users expose.
- Good: a cohort profile returns a common iPhone screen/GPU/CPU combination.
- Bad: every custom build creates a unique hardware combination.
- Good: a generated build renames internal symbols.
- Bad: the generated symbol names leak into JavaScript or app-visible errors.

## Acceptance Criteria

A spoofing option is complete only when:

- It has full documentation using the required fields.
- It has a test harness case.
- It has at least one common default or an explicit pass-through default.
- Its temporal or value dependencies are listed.
- Its drawbacks are documented.
- It does not contain identifying project/build constants in the injected runtime.
- It can be disabled per app.
