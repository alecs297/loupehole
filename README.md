# Loupehole

![Status: Early Development](https://img.shields.io/badge/status-early%20development-orange)

<p align="center">
  <img src="docs/assets/loupehole-logo.png" alt="Loupehole logo" width="180">
</p>

> **Early-stage project**
>
> Loupehole is experimental software. The first prototype works and already ships a meaningful set of mitigations, but coverage is incomplete, behavior can change quickly, and every device/app combination still needs careful validation. Use it at your own risk.

Loupehole is an iOS privacy tweak and injectable runtime that reduces abusive fingerprinting from native apps and embedded web views. It is designed for people who want fewer stable, app-readable identifiers without turning their device into a pile of obvious fake values.

The project can be used in two modes:

- **Systemwide tweak:** the best-case path, packaged as a rootless Debian package with a PreferenceLoader Settings pane and MobileSubstrate-compatible injection.
- **Standalone dylib:** the same runtime built as an injectable dynamic library for owned-app testing, sideload-style workflows, or focused research.

Loupehole is heavily inspired by [Loupe](https://github.com/mysk-research/loupe), and Loupe's public fingerprinting surfaces are a primary research source for this project. Loupehole is not affiliated with Loupe, Mysk, or its authors. The goal here is broader defensive coverage over time: first watch the surfaces Loupe demonstrates, then cover adjacent native and WebView signals where safe mitigation is possible.

## Why Loupehole Exists

Apps can often recognize a device without asking for a single explicit identifier. They combine many small observations: boot time, volume creation dates, language lists, network names, battery state, WebView quirks, installed voices, pasteboard metadata, and other details. One value may look harmless; a stable cluster can become a fingerprint.

Loupehole's approach is **smart randomization**. It does not make everything random on every read. Instead, it tries to return values that are:

- **Scoped:** different apps can see different derived identities when that protects the user.
- **Stable where needed:** the same app should not see a value flicker every time it asks.
- **Coherent:** related mitigations should agree with each other, especially temporal values such as volume creation, app install, and boot time.
- **Low drama:** when Loupehole cannot safely produce a documented value, the hook should pass through instead of inventing a broken one.

At a high level, Loupehole combines a root/build seed, the active scope, per-mitigation policy seeds, and small persisted state where needed. The seed gives each build or install its own identity; the scope controls who sees the same derived values; policy seeds separate one value stream from another. See [Seeds](docs/concepts/seeds.md), [Scopes](docs/concepts/scopes.md), [Randomization](docs/concepts/randomization.md), and [Derivation](docs/concepts/derivation.md) for the deeper model.

## Current Status

Loupehole is in very early development. The current baseline includes:

- an injected runtime with scope, seed, state, policy, module registry, and hook-backend machinery;
- a generated static mitigation graph driven by `config/mitigations.json` and `config/build.default.json`;
- a rootless package with generated loader names, package policy, root seed storage, and a Settings pane;
- a standalone dylib build for injection-focused workflows;
- static verification scripts for seed derivation, package layout, binary strings, symbols, Swift runtime absence, debug logs, and mitigation helper behavior;
- 32 experimental mitigation modules in the default selection.

The [surface inventory](docs/surfaces/) is research coverage. The [mitigation pages](docs/mitigations/) describe implemented behavior. A compiled mitigation is not a claim that the whole surface is solved; always read the linked mitigation page for exact API coverage, limitations, rollback behavior, and validation evidence.

## Available Mitigations

| Mitigation | Source folder | ID |
| --- | --- | --- |
| [identity.idfv](docs/mitigations/identity-idfv.md) | [identity/idfv](src/mitigations/identity/idfv/) | `identity.idfv.uidevice.scoped_uuid` |
| [system.boot_time](docs/mitigations/system-boot-time.md) | [system/boot_time](src/mitigations/system/boot_time/) | `system.boot_time.composite.synthetic` |
| [storage.volume_creation_time](docs/mitigations/storage-volume-time.md) | [storage/volume_creation_time](src/mitigations/storage/volume_creation_time/) | `storage.volume_creation_time.foundation.synthetic` |
| [app_bundle.install_date](docs/mitigations/app-bundle-install-date.md) | [app_bundle/install_date](src/mitigations/app_bundle/install_date/) | `app_bundle.install_date.foundation.synthetic` |
| [identity.device_name](docs/mitigations/identity-device-name.md) | [identity/device_name](src/mitigations/identity/device_name/) | `identity.device_name.uidevice.generic` |
| [identity.hostname](docs/mitigations/identity-hostname.md) | [identity/hostname](src/mitigations/identity/hostname/) | `identity.hostname.composite.generic` |
| [accessibility.common_preferences](docs/mitigations/accessibility-common-preferences.md) | [accessibility/common](src/mitigations/accessibility/common/) | `accessibility.common_preferences.uikit.normalized` |
| [account.ubiquity_token](docs/mitigations/account-ubiquity-token.md) | [identity/apple_account](src/mitigations/identity/apple_account/) | `account.ubiquity_token.filemanager.nil` |
| [advertising.idfa](docs/mitigations/advertising-idfa.md) | [advertising/idfa](src/mitigations/advertising/idfa/) | `advertising.idfa.adsupport.zero` |
| [storage.available_capacity](docs/mitigations/storage-available-capacity.md) | [storage/available_capacity](src/mitigations/storage/available_capacity/) | `storage.available_capacity.foundation.bucketed` |
| [system.lockdown_mode](docs/mitigations/system-lockdown-mode.md) | [system/lockdown_mode](src/mitigations/system/lockdown_mode/) | `system.lockdown_mode.userdefaults.common_false` |
| [system.memory_counters](docs/mitigations/system-memory-counters.md) | [system/memory_counters](src/mitigations/system/memory_counters/) | `system.memory_counters.mach.bucketed` |
| [locale.preferred_languages](docs/mitigations/locale-preferred-languages.md) | [locale/language_preferences](src/mitigations/locale/language_preferences/) | `locale.preferred_languages.foundation.primary_only` |
| [locale.keyboard_languages](docs/mitigations/locale-keyboard-languages.md) | [locale/keyboard_languages](src/mitigations/locale/keyboard_languages/) | `locale.keyboard_languages.uikit.primary_only` |
| [voices.inventory](docs/mitigations/voices-inventory.md) | [voices/inventory](src/mitigations/voices/inventory/) | `voices.inventory.avspeech.downloaded_hidden` |
| [audio.session](docs/mitigations/audio-session.md) | [media/audio_session](src/mitigations/media/audio_session/) | `audio.session.avaudiosession.shaped_values` |
| [camera.unique_id](docs/mitigations/camera-unique-id.md) | [camera/unique_id](src/mitigations/camera/unique_id/) | `camera.unique_id.avcapturedevice.scoped_id` |
| [display.brightness](docs/mitigations/display-brightness.md) | [display/brightness](src/mitigations/display/brightness/) | `display.brightness.uiscreen.curved` |
| [display.dynamic_type](docs/mitigations/display-dynamic-type.md) | [display/dynamic_type](src/mitigations/display/dynamic_type/) | `display.dynamic_type.uikit.bucketed` |
| [power.battery](docs/mitigations/power-battery.md) | [power/battery_state](src/mitigations/power/battery_state/) | `power.battery.uidevice.curved_level` |
| [power.low_power_mode](docs/mitigations/power-low-power-mode.md) | [power/low_power_mode](src/mitigations/power/low_power_mode/) | `power.low_power_mode.processinfo.normalized_false` |
| [power.thermal_state](docs/mitigations/power-thermal-state.md) | [power/thermal_state](src/mitigations/power/thermal_state/) | `power.thermal_state.processinfo.nominalized` |
| [sensors.device_motion](docs/mitigations/sensors-device-motion-seeded-jitter.md) | [sensors/device_motion](src/mitigations/sensors/device_motion/) | `sensors.device_motion.coremotion.seeded_jitter` |
| [bluetooth.corebluetooth](docs/mitigations/bluetooth-corebluetooth-scan-empty.md) | [bluetooth/corebluetooth](src/mitigations/bluetooth/corebluetooth/) | `bluetooth.corebluetooth.scan.empty` |
| [telephony.radio_access](docs/mitigations/telephony-radio-access-single-lte.md) | [telephony/radio_access](src/mitigations/telephony/radio_access/) | `telephony.radio_access.coretelephony.single_lte` |
| [personal_data.eventkit](docs/mitigations/personal-data-eventkit-empty.md) | [personal_data/eventkit_empty](src/mitigations/personal_data/eventkit_empty/) | `personal_data.eventkit.inventory.empty` |
| [apps.url_scheme_probes](docs/mitigations/apps-url-scheme-probes.md) | [apps/url_scheme_probes](src/mitigations/apps/url_scheme_probes/) | `apps.url_scheme_probes.uiapplication.default_false` |
| [network.hostname](docs/mitigations/network-hostname.md) | [network/hostname](src/mitigations/network/hostname/) | `network.hostname.composite.generic_device_name` |
| [network.wifi_identity](docs/mitigations/network-wifi-identity.md) | [network/wifi_identity](src/mitigations/network/wifi_identity/) | `network.wifi_identity.nehotspot.scoped` |
| [network.interface_inventory](docs/mitigations/network-interface-inventory.md) | [network/interface_inventory](src/mitigations/network/interface_inventory/) | `network.interface_inventory.composite.common` |
| [pasteboard.metadata](docs/mitigations/pasteboard-metadata.md) | [pasteboard/metadata](src/mitigations/pasteboard/metadata/) | `pasteboard.metadata.uikit.empty_shape` |
| [webview.script_fingerprint](docs/mitigations/webview-script-fingerprint.md) | [webview/script_fingerprint](src/mitigations/webview/script_fingerprint/) | `webview.script_fingerprint.wkwebview.exact_probe_guard` |

The default selection mixes seeded synthetic values, coarse bucketing, strict empty inventory shapes, and low-entropy constants. Some surfaces are intentionally not compiled by default because iOS already has strong permission controls or because a partial synthetic inventory would be more detectable than useful. See [Known limitations](docs/reference/known-limitations.md) for the current boundary.

## Build And Releases

Loupehole builds from a **mitigation profile**. The profile chooses which mitigation modules are compiled and provides a build seed. The generator turns that selection into runtime config, module registry code, generated policy seed bytes, Settings metadata, and package layout inputs.

From the repository root:

```sh
# Generate, build, sign, and copy the standalone dylib.
make

# Build the dylib and run static verification.
make audit

# Build and verify the rootless package.
make package

# Use a different profile.
BUILD_SELECTION=path/to/selection.json make audit
```

`make` writes `dist/runtime.dylib`. `make package` writes `dist/com.loupehole.runtime_0.1.0_iphoneos-arm64.deb`.

For the standalone dylib, compiling it yourself is recommended so you control the build profile and seed. Some release builds may be provided with predefined seeds for easier testing, but those builds trade convenience for less personal control over generated build identity. See [Build profiles](docs/concepts/build-profiles.md), [Build environment](docs/development/build-environment.md), and [Build system reference](docs/reference/build-system.md) for details.

## Runtime Requirements

The rootless package expects:

- iOS 15 or later, within the current intended iOS 15-26 validation window;
- a rootless jailbreak/package environment;
- a MobileSubstrate-compatible injection loader;
- PreferenceLoader for the Settings pane.

The package starts conservatively and uses Settings-managed policy to decide where protection is active. The runtime still refuses non-app, extension, and system-bundle contexts before resolving seeds or installing hooks.

The standalone dylib is for controlled injection into an owned app process. It is useful for development and research, but it does not include the full package policy and rootless Settings lifecycle.

## Documentation

| Area | Contents |
| --- | --- |
| [Documentation map](docs/README.md) | Entry points for users, contributors, and reviewers. |
| [Status](docs/status.md) | Current coverage, limits, and validation posture. |
| [Surfaces](docs/surfaces/) | Research inventory of fingerprinting surfaces. |
| [Mitigations](docs/mitigations/) | Implemented mitigation behavior pages. |
| [Concepts](docs/concepts/seeds.md) | Seeds, scopes, profiles, randomization, and derivation. |
| [Development](docs/development/adding-a-mitigation.md) | Contributor workflow, runtime architecture, package architecture, and project values. |
| [Reference](docs/reference/build-system.md) | Build system, validation, glossary, and limitations. |
| [Agent handoff](AGENTS.md) | Repository-aware operational rules and invariants. |

## Safety, Scope, And Non-Goals

Loupehole is focused on reducing fingerprintability. It is not built to bypass DRM, defeat fraud systems, impersonate hardware, evade app security controls, or hide abusive behavior. The project collects no telemetry.

The goal is a small set of auditable, reversible changes that make abusive correlation harder while preserving ordinary app behavior where possible. Good mitigations are honest about what they cover, what they leave untouched, and when they pass through.

## Contribution Status

The project is young, and contributions are most useful when they add well-researched surface coverage, preserve cross-API coherence, document limitations clearly, and include build plus runtime validation evidence. Start with [Project values](docs/development/project-values.md), [Adding a mitigation](docs/development/adding-a-mitigation.md), and [Mitigation principles](docs/development/mitigation-principles.md).
