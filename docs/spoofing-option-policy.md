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
- Project-specific JS globals.
- Project-specific class prefixes in target processes.
- Rare fake defaults that normal devices almost never expose.
- A single universal synthetic device profile if it becomes a recognizable signature.

## Coverage Requirement

The final tweak must include every spoofing method that makes sense in at least one legitimate privacy scenario.

"Makes sense" means:

- It reduces a real fingerprinting surface.
- It can be explained and tested.
- It has a clear compatibility mode or opt-in strict mode.
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
- Partitioned: isolate storage or identifiers by app/profile.
- Ephemeral: reset data on app close or profile reset.
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
- Default mode: compatibility, standard, strict, or off.
- Common default: the recommended default value or bucket, with reasoning.
- Original API behavior: how the real API works and what a normal app receives.
- Fingerprinting mechanism: how trackers combine or persist the value.
- Mitigation behavior: exactly what the tweak changes.
- Value lifetime: pass-through, per-app stable, session-stable, slowly varying, or cohort static.
- Coherence dependencies: other APIs that must agree with this value.
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

Coherence dependencies:

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
- Accessibility: default to common settings, but avoid breaking real accessibility needs unless the user chooses strict spoofing.

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
- Its coherence dependencies are listed.
- Its drawbacks are documented.
- It does not contain identifying project/build constants in the injected runtime.
- It can be disabled per app.

