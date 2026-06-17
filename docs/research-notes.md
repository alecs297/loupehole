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
- Swift only for optional UI/preferences components and external tooling, not the injected core.

Verified local environment on 2026-06-17:

- Xcode 26.5 with iPhoneOS SDK 26.5.
- Apple clang 21.0.0 and Swift 6.3.2 are available through Xcode.
- Theos is installed at `/Users/alex/theos` and updated to commit `9bc7340`.
- `ldid` 2.1.5_1 is installed.
- `dpkg-deb` 1.23.7 and `fakeroot` 1.38.1 are installed for `.deb` package assembly.
- Binary audit tools are available: `file`, `otool`, `nm`, `strings`, and `strip`.
- A minimal arm64 iOS dynamic library can be compiled locally with `xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=15.0 -dynamiclib` and signed with `ldid -S`.
- The upstream Loupe Xcode project can be inspected with `xcodebuild -list`; simulator access may be noisy or unavailable in sandboxed automation, but simulator testing is not required for the initial Loupehole workflow.

Current local gaps and constraints:

- No valid Apple code-signing identities are installed. This is acceptable for the Theos/rootless `.deb` path and for ad hoc `ldid` signing, but not for App Store-style device builds.
- `fastlane` is not installed. It is only needed for upstream Loupe App Store metadata/screenshots, not for the tweak runtime.
- `ios-deploy`, `idevice_id`, and `ideviceinstaller` are not installed. Real-device install, injection, and verification will be handled manually or through external tools, not by this repository's first automation.
- Homebrew's `dpkg` is suitable for building `.deb` archives with `dpkg-deb`; it is not configured for local package installation with commands such as `dpkg -i`.

## Open Research Questions

- How much backend-specific support should be added after the first MobileSubstrate-compatible Theos/Logos backend, such as ElleKit or libhooker-specific paths?
- Which injection tracks are in scope beyond jailbreak packages: TrollStore-style app injection, sideloaded IPA patching for owned apps, or developer-only test host apps?
- What minimum iOS version should be supported? A practical first target is iOS 15+ for rootless jailbreaks, with iOS 14 or earlier considered only if there is a concrete user need.
- How much WebKit behavior can be normalized from native code without destabilizing app web views?
- How should the website prove that a custom profile remains in a large anonymity set?
