# Fingerprinting Surface Inventory

This directory maps Loupe's fingerprinting providers to Loupehole mitigation
planning pages. Each page is written around one global Loupe category and should
answer the same practical questions:

- what Loupe reads
- whether the read is passive, active, permissioned, or a hardware/cohort probe
- which permission, entitlement, or user prompt is required
- which APIs or platform contracts document the surface
- why the value is useful for fingerprinting
- how a Loupehole mitigation should derive, scope, and rotate replacement values
- what compatibility or detection risks the mitigation creates

The goal is not to claim every page is implemented. The goal is to preserve a
complete, useful inventory of granular fingerprinting methods that can become
mitigations without re-reading Loupe every time.

## Inclusion Rule

Include surfaces that expose user, install, account, environment, time-varying,
permissioned, or configuration-specific data. Examples include battery level,
brightness, audio route, language combinations, accessibility settings, install
history, local-network services, media-library metadata, and location state.

Exclude surfaces that are mostly constant for an iPhone/iPad model or that do
not allow granular tracking on their own. Examples include hardware model,
screen size, CPU architecture, fixed display scale, GPU family support, and
camera lineup. Pages that encounter those values must include an explicit
exclusion note listing the omitted Loupe signals.

Excluded values can still matter as coherence constraints. If Loupehole later
implements a full hardware profile, those values should be handled together so
model, display, CPU, GPU, camera, and WebKit hardware claims agree.

## Inventory

| Loupe category | Page | Collection class | Permission requirement |
| --- | --- | --- | --- |
| Device Identity | [`device-identity.md`](device-identity.md) | Passive native identity | None for included IDFV/hostname/version; user-assigned device name requires Apple's entitlement on modern iOS |
| System Info | [`system-info.md`](system-info.md) | Passive system/runtime state | None |
| Battery & Power | [`battery-power.md`](battery-power.md) | Passive live state | None |
| Storage | [`storage.md`](storage.md) | Passive storage/volume state | None |
| Display | [`display.md`](display.md) | Passive live display and user-preference state | None |
| Audio | [`audio.md`](audio.md) | Passive live audio-session state | None for included session/route properties |
| Locale & Region | [`locale-region.md`](locale-region.md) | Passive user/environment configuration | None |
| Accessibility | [`accessibility.md`](accessibility.md) | Passive user-preference configuration | None |
| Pasteboard | [`pasteboard.md`](pasteboard.md) | Passive/active clipboard metadata read | None, but pasteboard access can have user-visible privacy behavior depending on API and OS |
| Device Motion | [`device-motion.md`](device-motion.md) | Active sensor sampling | Motion/privacy constraints vary by API and platform version |
| Network | [`network.md`](network.md) | Passive network-path and interface state | None for path/proxy/interface reads |
| Fonts | [`fonts.md`](fonts.md) | Passive installed-resource inventory | None |
| Installed Voices | [`installed-voices.md`](installed-voices.md) | Passive installed-resource inventory | None |
| App & Bundle | [`app-bundle.md`](app-bundle.md) | Passive app/container metadata | None |
| Apple Account | [`apple-account.md`](apple-account.md) | Passive account/storefront state | None for local token/storefront availability checks; account state depends on system configuration |
| Graphics & Metal | [`graphics-metal.md`](graphics-metal.md) | Hardware/cohort profile with exclusions | None |
| Telephony | [`telephony.md`](telephony.md) | Passive cellular service state | None for exposed CoreTelephony service metadata; platform availability varies |
| Installed Apps Probe | [`installed-apps.md`](installed-apps.md) | Active URL-scheme probing | None, but limited by `LSApplicationQueriesSchemes` and platform policy |
| WebView Fingerprint | [`webview-fingerprint.md`](webview-fingerprint.md) | Active browser-style fingerprinting | None for local WebView probes |
| Previous Installs Log | [`previous-installs.md`](previous-installs.md) | Active durable reinstall tracking | None; usually backed by Keychain or other durable state |
| Motion & Sensors | [`motion-sensors.md`](motion-sensors.md) | Active permissioned sensor/activity collection | Motion & Fitness / Core Motion authorization where applicable |
| Location | [`location.md`](location.md) | Active permissioned location collection | Location authorization |
| Cameras | [`cameras.md`](cameras.md) | Permissioned hardware/camera identity with exclusions | Camera authorization for capture; enumeration behavior depends on API |
| Bluetooth | [`bluetooth.md`](bluetooth.md) | Active permissioned nearby-device collection | Bluetooth authorization |
| Local Network | [`local-network.md`](local-network.md) | Active permissioned Bonjour/local service probing | Local Network authorization |
| Contacts | [`contacts.md`](contacts.md) | Active permissioned personal-data inventory | Contacts authorization |
| Photos | [`photos.md`](photos.md) | Active permissioned library/geotag inventory | Photos authorization |
| Calendar | [`calendar.md`](calendar.md) | Active permissioned calendar inventory | Calendar authorization |
| Reminders | [`reminders.md`](reminders.md) | Active permissioned reminders inventory | Reminders authorization |
| Music | [`music-library.md`](music-library.md) | Active permissioned media-library inventory | Media Library / Apple Music authorization depending on API |

## Page Rules

- Use official Apple Developer links where available. Use Apple archived manual
  pages, Apple open-source headers, standards documents, or platform-owner
  references when modern Developer Documentation is sparse.
- Say `None` when the API has no TCC prompt. Do not invent permission prompts.
- Distinguish collection from mitigation: a passive fingerprinting surface can
  still require an active hook mitigation.
- Prefer coherent reduction over randomization. Values that can be compared
  should derive from the same state domain or profile choice.
- Explain impact honestly. Some mitigations can break analytics, licensing,
  local-network utilities, media apps, accessibility-aware UI, or device
  management flows.
- Keep omitted hardware constants visible in exclusion notes so they do not
  quietly re-enter the roadmap as one-off spoofing tasks.
