# Device Identity

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/DeviceIdentityProvider.swift`

Loupe category: Device Identity
Loupe tier: passive native identity
Permission required: none for included IDFV, hostname, and version reads;
user-assigned device name requires Apple's entitlement on modern iOS
Primary relevance: vendor-scoped identity, host naming, OS-version coherence,
and separation from model-constant hardware claims.

This page scopes Loupehole's Device Identity fingerprint category to values
that identify the user, app/vendor relationship, host naming, or OS identity.
Static hardware cohort fields are intentionally excluded here even though Loupe
shows them in the same category.

## Official Links

- [`UIDevice.identifierForVendor`](https://developer.apple.com/documentation/uikit/uidevice/identifierforvendor)
- [`UIDevice.name`](https://developer.apple.com/documentation/uikit/uidevice/name)
- [User-assigned device name entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.device-information.user-assigned-device-name)
- [`UIDevice.systemVersion`](https://developer.apple.com/documentation/uikit/uidevice/systemversion)
- [`sysctl` / `sysctlbyname` manual page](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/sysctl.3.html)
- [`gethostname` manual page](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/gethostname.3.html)
- [`uname` manual page](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/uname.3.html)

## Loupe Signals

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `idfv` | `PlatformDevice.identifierForVendor` -> `UIDevice.current.identifierForVendor` on iOS | None | Passive native identity read | Include | High. Stable vendor-scoped native identifier with high correlation value. |
| `name` | `PlatformDevice.name` -> `UIDevice.current.name` on iOS | None for generic device name; user-assigned name requires Apple's entitlement on modern iOS | Passive native identity read | Include | Medium to high when personalized. Usually generic on modern iOS, but entitlemented apps, older OS behavior, and macOS-style host names can expose user-assigned naming. |
| `kern.hostname` | `SysctlHelper.string("kern.hostname")` | None for reads available to the process sandbox | Passive kernel hostname read | Include | Medium. It can mirror the user-visible device name or local network identity. |
| `systemVersion` | `PlatformDevice.systemVersion` -> `UIDevice.current.systemVersion` on iOS | None | Passive OS-version read | Include | Medium. OS patch/version narrows the anonymity set and must stay coherent with other OS/WebKit/kernel surfaces. |
| `hw.machine` | `SysctlHelper.modelIdentifier()`, plus `hw.model` board detail on iOS and `uname.machine` architecture on macOS | None | Passive hardware/model read | Exclude | High as a model classifier, but coarse/model-constant hardware belongs in a hardware/system profile, not this identity page. |
| `hw.cputype` | `SysctlHelper.int64("hw.cputype")` and `hw.cpusubtype` | None | Passive CPU architecture read | Exclude | Medium to high as a model classifier. Track with CPU/hardware cohort surfaces, not this identity page. |

## Permission and Collection Class

| Surface | Runtime permission | Passive or active | Notes |
| --- | --- | --- | --- |
| `UIDevice.identifierForVendor` | None | Passive | Synchronous app-readable property. No prompt. |
| `UIDevice.name` | None for generic device name. User-assigned name requires Apple's entitlement on modern iOS. | Passive | The entitlement is a signing/capability gate, not a user TCC prompt. |
| `kern.hostname` | None for reads available to the process sandbox | Passive | Kernel/sysctl hostname read. Equivalent host-name APIs should be treated as the same surface. |
| `UIDevice.systemVersion` | None | Passive | Synchronous OS version string. |

No included signal requires Contacts, Location, Local Network, Bluetooth, Motion,
or other user-granted runtime permissions. This category is native passive
identity: an app can read it without visible user action.

## Fingerprinting Value

`identifierForVendor` is the highest-value signal in this category. It is
stable across apps from the same vendor and can link activity until all apps for
that vendor state reset according to platform semantics. It is especially
strong when joined with app reinstall markers, storage dates, boot time, or
server-side account state.

`UIDevice.name` is lower entropy on iOS and iPadOS 16+ when the app only sees a
generic product name, but it becomes high-value when an app has entitlemented
access to the user-assigned name or runs in an environment where the custom name
is still visible. Personalized names can directly reveal the owner or household.

`kern.hostname` is a medium-value native signal. Alone it is often generic, but
it can duplicate the user-assigned device name, expose a local-network naming
choice, or create a consistency check against `gethostname`, `uname.nodename`,
Bonjour, and network-interface surfaces.

`systemVersion` is not a unique identifier by itself, but exact patch-level OS
versions are useful cohort reducers. It becomes more valuable when combined
with WebKit version, kernel strings, feature availability checks, app SDK paths,
and hardware model data.

## Mitigation Strategy Ideas

### `identity.idfv`

- Hook `UIDevice.identifierForVendor`.
- Return a valid pseudonymous UUID from the policy/value resolver, not from the
  hook body.
- Default to per-app-install or per-app stable scope, depending on the selected
  profile.
- Support explicit per-vendor scope for apps that legitimately expect sibling
  apps from the same vendor to share an IDFV.
- Rotate on profile reset, scope reset, or practical seed change.
- If resolver state is unavailable, pass through this API only.

### `identity.device-name`

- Hook `UIDevice.name`.
- Default to a generic cohort value such as `iPhone` or `iPad` that matches the
  selected device class.
- Avoid personalized names, account names, owner initials, rare punctuation, or
  seed-derived high-cardinality strings.
- For entitlemented apps with a real compatibility need, expose an opt-in
  compatibility mode that can pass through the original value.
- Strict mode should stay generic and coherent with hostname-like values.

### `identity.hostname`

- Normalize `sysctl` / `sysctlbyname` reads of `kern.hostname`.
- Keep equivalent host-name APIs coherent: `gethostname`, `uname.nodename`,
  `ProcessInfo.hostName` where applicable, and any network-provider surface that
  exposes the same name.
- Default to the same generic name family as `UIDevice.name`, without a unique
  numeric suffix.
- Avoid changing real network behavior unless the app is only reading the value
  as a fingerprinting probe.
- If a networking app needs true host identity, prefer pass-through for this
  surface rather than returning a contradictory name.

### `identity.os-version`

- Hook `UIDevice.systemVersion` and align related OS-version APIs in the system
  profile rather than changing only this string.
- Compatibility default: pass through major/minor and optionally bucket or
  cohort-normalize patch level.
- Strict default: return a full cohort OS version supported by the selected
  hardware profile.
- Keep `ProcessInfo.operatingSystemVersion`, kernel release/build strings,
  WebKit user agent, WebKit feature set, and API availability behavior coherent
  with the reported version.

## Derivation Considerations

- IDFV replacements should derive from the practical seed, scope kind, stable
  scope identifier, and any app-install marker used by that scope.
- The derived IDFV must be stable for its documented lifetime and reset only
  when the selected scope says it resets.
- Device name and hostname should usually be cohort constants, not unique
  per-user derivations. A deterministic choice from a tiny common set is safer
  than a generated name that becomes a new identifier.
- Hostname and device name must use the same device class vocabulary. Do not
  return `iPad` through `UIDevice.name` and `Alex-iPhone` through
  `kern.hostname`.
- OS version should be selected as part of the device/system profile, not as a
  standalone random value. It must agree with WebKit, kernel, SDK feature
  availability, and any hardware support assumptions.
- Purpose labels for derivation should stay internal and seed-bound. Do not
  expose readable project names, mitigation names, salts, or profile IDs through
  returned API values.

## Impact and Tradeoffs

IDFV spoofing can affect analytics, licensing, anti-abuse checks, and apps that
coordinate identity across multiple apps from the same developer. Per-vendor
scope is more compatible; per-app or per-install scope is more private.

Device-name normalization can remove visible personalization, but some document,
sync, enterprise, or device-management flows use the device name to help users
pick the right device. Those cases need an explicit compatibility path.

Hostname normalization can confuse local-network diagnostics or discovery tools
if they expect the real host name. It is less risky for ordinary apps that only
read the hostname as another passive fingerprint component.

OS-version spoofing is easy to detect if only the string changes. Apps can test
selectors, framework behavior, WebKit capabilities, or kernel values. Keep the
default conservative and make strict version cohorts complete.

The safest behavior is coherent reduction, not maximal falsification. Returning
common values that agree across APIs is less unique than returning rare,
over-randomized, or internally contradictory values.

## Exclusion Note

Omit `hw.machine`, `hw.model`, `uname.machine`, `hw.cputype`, and
`hw.cpusubtype` from Device Identity mitigation planning in this document. They
remain relevant to fingerprinting, but belong in a coherent
hardware/system-profile document where model, SoC, CPU, RAM, GPU, display, and
WebKit hardware values can be generated together.

## Relevance

Device Identity is a core passive-native fingerprint category because it gives
trackers stable IDs and low-friction cohort reducers before any permission
prompt appears. `identity.idfv` is P0. Device name and hostname are P1 because
modern iOS has already reduced the default exposure, but entitlemented and
cross-surface cases still matter. OS version remains P0 as a coherence anchor
for the broader device/system profile.

This page should feed future mitigation docs for IDFV, device name, hostname,
and OS version. Hardware model and CPU constants should remain out of this page
and be handled by a separate coherent hardware profile plan.
