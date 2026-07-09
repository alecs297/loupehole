# Fingerprinting Surface Inventory

This directory maps Loupe's fingerprinting providers to Loupehole surface
inventory pages. Each page is research coverage first: it records what Loupe
reads, why that read matters, and what a future mitigation would need to keep
coherent. A page in this directory does not mean the surface is implemented.

Treat these pages as the reference template for adding or maintaining surface
inventory. Preserve reviewed facts, call out uncertainty, and avoid upgrading a
research note into a mitigation claim unless the code and mitigation docs also
support that claim.

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

## Page Template

Use this section order for new pages and normalize existing pages toward it when
the content maps cleanly:

1. `# <Loupe category>`
2. Source reviewed line, pointing at the reviewed Loupe provider under
   `.research/upstream/loupe/code/Loupe/Providers/`.
3. Short metadata block:
   - `Loupe category:`
   - `Loupe tier:`
   - `Permission required:`
   - `Primary relevance:`
4. Introductory scope paragraph that says what the page includes, what it does
   not include, and whether any values are being treated as coherence
   constraints rather than standalone mitigation targets.
5. `## Official Links`
6. `## Loupe Signals`
7. `## Permission and Collection Class`
8. `## Fingerprinting Value`
9. `## Mitigation Strategy Ideas`
10. `## Derivation Considerations`
11. `## Impact and Tradeoffs`
12. Optional `## Exclusion Note` when Loupe reports values that this page
    deliberately excludes from first-class mitigation ownership.
13. `## Relevance`

Use tables for Loupe signals when there is more than one signal. Include these
columns when they are useful: `Loupe signal`, `Provider source`, `Permission`,
`Classification`, `Decision`, and `Fingerprinting value`. Pages may add
platform or source columns when that makes the inventory clearer.

## Maintenance Rules

- Use official Apple Developer links where available. Use Apple archived manual
  pages, Apple open-source headers, standards documents, or platform-owner
  references when modern Developer Documentation is sparse.
- Say `None` when the API has no TCC prompt. Do not invent permission prompts.
- Distinguish collection from mitigation: a passive fingerprinting surface can
  still require an active hook mitigation.
- Use `Include`, `Exclude`, or an explicit scoped decision in the signal table.
  Exclusions should explain where the value belongs instead, such as a coherent
  hardware, graphics, display, account, or timeline profile.
- Prefer coherent reduction over randomization. Values that can be compared
  should derive from the same state domain or profile choice.
- Explain impact honestly. Some mitigations can break analytics, licensing,
  local-network utilities, media apps, accessibility-aware UI, or device
  management flows.
- Keep omitted hardware constants visible in exclusion notes so they do not
  quietly re-enter the roadmap as one-off spoofing tasks.
- Keep repo references current with the source-tree layout. Mitigation source
  belongs under `src/mitigations/`, reusable mitigation helpers under
  `src/mitigationkit/`, internal headers under `src/core/include/`, and
  generator/build/verification helpers under `src/scripts/`.
