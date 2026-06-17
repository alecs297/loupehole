# Research Notes

Last updated: 2026-06-17.

## Upstream Loupe Snapshot

The project was inventoried from [mysk-research/loupe](https://github.com/mysk-research/loupe) at commit:

```text
2262efd4456ecba802e1c69f6012859b92eec969
```

Loupe describes itself as an iOS and iPadOS app that reads public iOS APIs and groups signals into passive, permissioned, and advanced tiers. Its README says the project needs Xcode 26 or newer, and its source currently contains 30 provider categories.

## Loupe Categories

Passive:

- Device Identity
- Apple Account
- System Info
- Display
- Locale and Region
- Accessibility
- Device Motion
- Battery and Power
- Storage
- Network
- Fonts
- Installed Voices
- App and Bundle
- Pasteboard
- Audio
- Graphics and Metal
- Telephony

Advanced:

- Installed Apps Probe
- WebView Fingerprint
- Previous Installs Log

Permissioned:

- Motion and Sensors
- Location
- Cameras
- Bluetooth
- Local Network
- Contacts
- Photos
- Calendar
- Reminders
- Music

## Source Links

- Loupe upstream repository: <https://github.com/mysk-research/loupe>
- Loupe README: <https://github.com/mysk-research/loupe#readme>
- Apple Xcode overview: <https://developer.apple.com/xcode/>
- Theos installation docs: <https://theos.dev/docs/installation>
- Theos Logos docs: <https://theos.dev/docs/logos>
- Theos rootless docs: <https://theos.dev/docs/rootless>
- Theos packaging docs: <https://theos.dev/docs/packaging>

## Development Environment Findings

macOS is strongly recommended and should be treated as required for the official build environment.

Reasons:

- Apple positions Xcode as the toolchain for developing, testing, and distributing apps for Apple platforms, with Simulator and device tooling "all from your Mac."
- Loupe itself currently documents Xcode 26 or newer.
- Theos is cross-platform and supports macOS, iOS, Linux, and Windows, but Theos rootless notes call out arm64e ABI work that currently needs Xcode's linker on macOS for relevant system binaries.
- A website that compiles custom dylibs should use macOS workers for the canonical pipeline, even if some Linux/Windows Theos builds are possible for narrow cases.

Recommended baseline:

- macOS build host.
- Xcode 26+ initially, keep a moving compatibility target for Xcode 27+.
- Theos for jailbreak packaging, rootless packages, and Logos where appropriate.
- C/Objective-C/Objective-C++ for hooks and ABI-sensitive code.
- Swift only for optional UI/preferences components, not the injected core, unless the runtime and ABI costs are explicitly accepted.

## Open Research Questions

- Which hook backend should be primary for modern rootless jailbreaks: ElleKit, Substitute/libhooker, or MobileSubstrate compatibility through Theos?
- Which injection tracks are in scope beyond jailbreak packages: TrollStore-style app injection, sideloaded IPA patching for owned apps, or developer-only test host apps?
- What minimum iOS version should be supported? A practical first target is iOS 15+ for rootless jailbreaks, with iOS 14 or earlier considered only if there is a concrete user need.
- How much WebKit behavior can be normalized from native code without destabilizing app web views?
- How should the website prove that a custom profile remains in a large anonymity set?

