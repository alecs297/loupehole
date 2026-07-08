# App & Bundle

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/AppInfoProvider.swift`

Loupe category: App & Bundle
Loupe tier: passive app/container metadata
Permission required: none
Primary relevance: app-version context, SDK/runtime coherence, app install
timeline, and comparison with durable reinstall markers.

This category covers metadata about the currently running app and its sandbox
container. Loupe reads its own main bundle's Info.plist dictionary and the
creation date of its Documents directory. For a protected target process, the
same pattern exposes that target app's build metadata and per-install container
timeline.

## Official and Equivalent Links

- [`Bundle`](https://developer.apple.com/documentation/foundation/bundle)
- [`Bundle.main`](https://developer.apple.com/documentation/foundation/bundle/main)
- [`Bundle.infoDictionary`](https://developer.apple.com/documentation/foundation/bundle/infodictionary)
- [`Bundle.object(forInfoDictionaryKey:)`](https://developer.apple.com/documentation/foundation/bundle/object%28forinfodictionarykey%3A%29)
- [Information Property List](https://developer.apple.com/documentation/bundleresources/information-property-list)
- [`CFBundleShortVersionString`](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleshortversionstring)
- [`CFBundleVersion`](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleversion)
- [`FileManager.url(for:in:appropriateFor:create:)`](https://developer.apple.com/documentation/foundation/filemanager/url%28for%3Ain%3Aappropriatefor%3Acreate%3A%29)
- [`FileManager.SearchPathDirectory`](https://developer.apple.com/documentation/foundation/filemanager/searchpathdirectory)
- [`FileManager.SearchPathDomainMask.userDomainMask`](https://developer.apple.com/documentation/foundation/filemanager/searchpathdomainmask/userdomainmask)
- [`URL.resourceValues(forKeys:)`](https://developer.apple.com/documentation/foundation/url/resourcevalues%28forkeys%3A%29)
- [`URLResourceKey.creationDateKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/creationdatekey)
- [`URLResourceValues.creationDate`](https://developer.apple.com/documentation/foundation/urlresourcevalues/creationdate)

Apple documents the public bundle, Info.plist, FileManager, and URL resource
value surfaces. `DTSDKName` is a build-produced Info.plist value observed in
Loupe's bundle dictionary rather than a user-authored privacy setting; treat it
as build metadata that may be present or absent depending on toolchain and
platform.

## Loupe Signals

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `buildStamp` | `Bundle.main.infoDictionary["CFBundleShortVersionString"]`, `["CFBundleVersion"]`, and `["DTSDKName"]` | None | Passive app bundle metadata read | Include for context and coherence, not as a standalone high-priority user identifier | Low for user uniqueness, but high for app/runtime context. Version, build, and SDK explain feature availability, app behavior, and which hook paths may be exercised. |
| `installDate` | `FileManager.default.url(for: .documentDirectory, in: .userDomainMask, create: false)`, then `URLResourceValues.creationDate` | None | Passive app-container file metadata read | Include | High as a per-install temporal marker. The Documents directory creation date can reveal when the current app install or container was created. |

Loupe emits `buildStamp` as a compound string:

```text
<CFBundleShortVersionString> (<CFBundleVersion>) / <DTSDKName>
```

If a bundle key is absent, Loupe uses `?` for that field. Loupe emits
`installDate` only when it can locate the Documents directory and read a
creation date.

## Permission and Activity Classification

No App & Bundle signal requires Contacts, Location, Bluetooth, Local Network,
Motion, Photos, Calendar, Reminders, Music, or another user-granted runtime
permission. These values are available inside the running app's process and
sandbox.

The category is passive collection. Loupe reads the main bundle's Info.plist
dictionary and reads metadata for its own Documents directory with
`create: false`. It does not scan another app's container, write files, make a
network request, or prompt the user.

Mitigation code may be active because it hooks Foundation and CoreFoundation
bundle/resource-value APIs, but the original fingerprinting surface is passive
local metadata.

## Fingerprinting Value

`installDate` is the strongest value in this category. It is not a global
device identifier, but it is stable within the current app installation and can
link app launches, server sessions, local files, and analytics events. It is
especially valuable when joined with Keychain-based previous-install logs,
volume creation time, boot time, first-launch defaults, cache creation dates,
and server-side first-seen timestamps.

The exact timestamp can be more identifying than a coarse install day. Many
users may install the same app version, but fewer share the same app-container
creation second, storage timeline, and prior-install history.

`buildStamp` has low direct user entropy because every user on the same build
usually shares it. It still matters because it describes the target app's code
and toolchain cohort. Apps can condition behavior on version/build, analytics
can bucket by SDK, and hook coverage may need to know which bundle metadata path
the app reads. A synthetic profile that claims an impossible SDK or app version
can also become detectable.

## Mitigation Strategy Ideas

### `app.install-date`

Hook Foundation file resource reads that expose app-container creation dates:

- `URL.resourceValues(forKeys:)`
- `NSURL resourceValuesForKeys:error:`
- `NSURL getResourceValue:forKey:error:`
- FileManager paths that locate `.documentDirectory`, `.libraryDirectory`,
  `.cachesDirectory`, and `.applicationSupportDirectory` when apps compare
  several container roots

Compatibility default should pass through. Some apps use container timestamps
for migrations, data-retention logic, backup behavior, cleanup heuristics,
support diagnostics, or abuse detection.

Strict mode can return a synthetic current-install timestamp generated by the
temporal state provider. The value should be stable for the selected app scope
and should not move on every launch. Preserve nil/error behavior when the
platform cannot provide a creation date.

The hook should target app-container metadata narrowly. It should not rewrite
unrelated user document creation dates or another app's files. If lower-level
filesystem APIs such as `stat`, `getattrlist`, or directory enumeration expose
the real timestamp, document that as future coverage rather than pretending the
Foundation hook is complete.

### `app.bundle-metadata`

Hook bundle metadata reads only when a policy explicitly asks for it:

- `Bundle.infoDictionary`
- `Bundle.object(forInfoDictionaryKey:)`
- `CFBundleGetInfoDictionary`
- app-specific wrappers around Info.plist values

Default behavior should pass through. Apps use version, build, bundle ID, and
SDK metadata for migrations, remote configuration, crash reporting, feature
flags, receipts, update prompts, and support flows. Spoofing the target app's
own version can break normal behavior and can conflict with the binary that is
actually running.

If strict privacy needs to reduce build metadata, prefer coarse normalization
or removal of nonessential build keys over inventing a fake app version. Do not
change bundle ID, executable name, receipt paths, entitlements, or code-signing
dependent values as part of this fingerprint category. Those belong to a much
larger app-identity model.

`DTSDKName` is best treated as an SDK/runtime coherence value. If it is changed,
it must still match actual framework behavior, linked SDK assumptions, and API
availability checks that the app can perform.

## Derivation and Coherence Considerations

Install date belongs to the temporal state domain. A useful state record should
include:

```text
volumeCreationTime <= firstInstallTime <= currentInstallTime <= now
currentInstallTime <= app container creation dates
bootTime may be before or after app install, but must never be in the future
previous install log dates agree with current install date and install count
```

For a fresh app profile, `installDate` and the current-install entry in the
Previous Installs Log should be close enough to be plausible. They do not need
to be byte-for-byte identical because different apps record first launch and
directory creation at different moments, but they must have the same ordering.

Install timestamps should be stable per app scope and profile epoch. Do not
derive exact seconds directly from the seed for every app; a rare timestamp
that appears unchanged across unrelated apps can become a new identifier.
Prefer plausible rounded or population-shaped times with small deterministic
offsets inside a coherent timeline.

Bundle metadata should usually come from the real app bundle. If a strict
profile changes it, the values must remain internally consistent: marketing
version, build number, SDK name, binary behavior, linked frameworks, receipt
metadata, and server-observed app version should not contradict one another.

Purpose labels and derivation salts should remain internal and seed-bound.
Returned Info.plist or timestamp values must not expose readable mitigation
names, profile IDs, or project paths.

## Impact and Tradeoffs

Install-date spoofing has moderate compatibility risk. Apps may use container
age for onboarding, trial eligibility, migration windows, cache eviction,
anti-abuse logic, or support diagnostics. A synthetic install date older than
the app's real files, newer than user-created data, or inconsistent with
Keychain state is easy to detect.

Bundle metadata spoofing has higher functional risk and lower privacy payoff.
Changing version/build can confuse migrations, remote feature flags, analytics,
crash symbolication, App Store receipt validation, update checks, and support
tools. It should remain opt-in and narrowly scoped.

Leaving `buildStamp` real while protecting install dates is normally acceptable
because build metadata is shared by many users. The main risk is coherence:
mitigations must not claim a build or SDK that the running binary cannot
support.

The safest path is to prioritize `installDate` as a timeline surface and treat
`buildStamp` as context for policy and testing.

## Exclusion Note

No hardware/model constants appear in Loupe's App & Bundle provider.

`buildStamp` is app-owned, coarse shared metadata rather than a granular user
identifier. It is included because Loupe emits it and because it matters for
runtime coherence, but it should not become a standalone high-priority spoofing
target unless a concrete target app uses bundle metadata as part of a broader
fingerprint.

## Relevance

App & Bundle is relevant for v1 planning because app install time is a strong
per-install timeline anchor and a coherence dependency for previous-install
history, storage timestamps, boot time, and profile reset state. `installDate`
is P1 for mitigation planning.

`buildStamp` is lower priority as a privacy value, but it should stay documented
because it tells future workers which app version and SDK context Loupe is
showing and because bundle metadata can influence target-specific compatibility
decisions.
