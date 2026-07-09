# System Info

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/SystemInfoProvider.swift`

Loupe category: System Info
Loupe tier: passive local system/runtime state
Permission required: none
Primary relevance: OS/kernel coherence, boot-time correlation, and rare
security-state leakage.

This category covers system state that normal apps can read without a prompt. It
is small, but it is high leverage because the values are easy to combine with
device identity, storage, WebView, and locale surfaces.

## Official Links

- Apple Foundation `ProcessInfo.processorCount`: <https://developer.apple.com/documentation/foundation/processinfo/processorcount>
- Apple Foundation `ProcessInfo.physicalMemory`: <https://developer.apple.com/documentation/foundation/processinfo/physicalmemory>
- Apple Foundation `ProcessInfo.operatingSystemVersion`: <https://developer.apple.com/documentation/foundation/processinfo/operatingsystemversion>
- Apple Foundation `ProcessInfo.operatingSystemVersionString`: <https://developer.apple.com/documentation/foundation/processinfo/operatingsystemversionstring>
- Apple Foundation `ProcessInfo.systemUptime`: <https://developer.apple.com/documentation/foundation/processinfo/systemuptime>
- Apple archived iOS `sysctlbyname(3)` manual page: <https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/sysctlbyname.3.html>
- Xcode equivalent `sysctl(8)` manual page mirror: <https://keith.github.io/xcode-man-pages/sysctl.8.html>
- Apple Foundation `UserDefaults`: <https://developer.apple.com/documentation/foundation/userdefaults>
- Apple Support Lockdown Mode overview: <https://support.apple.com/en-us/105120>

Apple documents the public APIs and the `sysctl` family, but it does not document
`LDMGlobalEnabled` as a public Lockdown Mode API. Loupe reads that defaults key
directly, so mitigation work should treat it as an observed app-readable
implementation detail that may change across OS releases.

## Loupe Signals and Decisions

| Loupe signal | Source API | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `processorCount` | `ProcessInfo.processInfo.processorCount` | None | Passive static read | Exclude as first-class System Info coverage | Mostly a hardware model or SoC proxy. It belongs with CPU/hardware profile coherence rather than this category. |
| `physicalMemory` | `ProcessInfo.processInfo.physicalMemory` | None | Passive static read | Exclude as first-class System Info coverage | Mostly a RAM tier and model-generation proxy. It should be handled through the hardware/device profile cohort, not as a standalone system-state value. |
| `operatingSystem` | `ProcessInfo.processInfo.operatingSystemVersionString` | None | Passive static read | Include | Narrows the OS cohort and can reveal patch/update state. It must agree with `UIDevice.systemVersion`, WebView user agent data, `kern.version`, and other kernel release fields. |
| `kern.version` | `sysctlbyname("kern.version")` through Loupe's `SysctlHelper.string` | None | Passive kernel-state read | Include | Strong OS build signal. Kernel build strings can carry exact release/build metadata and must not contradict the reported OS version. |
| `kern.boottime` | `sysctlbyname("kern.boottime")` through Loupe's `SysctlHelper.timeval` | None | Passive kernel-state read | Include | Stable until restart, so it can link app launches and sessions. It is especially useful to trackers when compared with storage volume creation time, install time, uptime, and profile rotation dates. |
| `lockdownMode` | `UserDefaults.standard.bool(forKey: "LDMGlobalEnabled")` | None | Passive defaults read | Include | Rare boolean security posture. `true` is high entropy and may identify users who have enabled Lockdown Mode; `false` is common but still helps explain other observed restrictions. |

## Permission and Activity Classification

All Loupe System Info reads are passive. They do not request iOS permissions, do
not show prompts, do not require network access, and do not need user action.
They are active only in the narrow implementation sense that the app calls local
APIs and `sysctlbyname`; they are not active probes of another app, network, or
external device.

## Mitigation Strategy Ideas

### `system.os_version_string`

Default behavior should be cohort-normalized only when the broader OS profile is
selected. Otherwise, pass through. A synthetic value must come from a common OS
cohort and must match:

- `UIDevice.systemName` and `UIDevice.systemVersion`.
- `ProcessInfo.operatingSystemVersion`.
- `ProcessInfo.operatingSystemVersionString`.
- WebView user-agent and JavaScript platform/version fields.
- Kernel release/build fields such as `kern.version`, `kern.osrelease`, and
  `uname` version fields.

Avoid making the app believe it is running on an OS version whose APIs or
feature flags do not match runtime reality. If OS-version normalization is not
complete for the process, pass through rather than return a contradictory value.

### `system.kernel_version`

`kern.version` should be generated from the same cohort OS profile as the public
Foundation/UIKit OS fields. The mitigation should cover both string-name and MIB
paths for the relevant sysctl keys where practical. It should also stay aligned
with `uname` data exposed by the device identity category.

The safest default is pass-through until the OS/kernel profile can be returned
coherently across Foundation, Darwin, UIKit, and WebKit. Strict mode can return
a cohort kernel build string, but only as part of a complete OS profile.

### `system.boot_time`

The current boot-time mitigation already treats `kern.boottime` as part of the
first mitigation group. Keep it as a synthetic per-scope timeline value derived
from the active instance seed and scope, not as a hardcoded constant.

The returned boot time must satisfy:

```text
storageVolumeCreationTime < bootTime < now
```

It must also be coherent with `NSProcessInfo.systemUptime`,
`ProcessInfo.processInfo.systemUptime`, wall-clock calculations, volume
creation time, app install time, and any future reset/profile-epoch timestamps.
Hook behavior should preserve the sysctl buffer-size and error behavior as
closely as possible, and non-boot-time sysctl keys should pass through.

### `system.lockdown_mode`

Compatibility default should pass through. Lockdown Mode is a real security
choice, and hiding it can conflict with observable platform behavior such as
restricted WebKit features, blocked features, or managed-profile limitations.

Strict mode can normalize `LDMGlobalEnabled` to the common `false` value, but
only with a warning that OS-enforced Lockdown Mode effects may still be visible
through other channels. The hook should be narrow: intercept the relevant
`NSUserDefaults`/CFPreferences read path for this key only, leave unrelated
defaults untouched, and pass through if the key cannot be identified with high
confidence.

Do not derive a random Lockdown Mode boolean per user or per app. A seeded rare
`true` value would make the protected profile more unique than the original
common state.

## Derivation Considerations

OS and kernel version values should be cohort static. Many protected users can
share the same complete OS profile, and the profile must be internally
consistent. These values should not be per-user random strings.

Boot time should be per-scope stable, derived from the active seed and scope,
and stored through the temporal state provider when writable state is available.
The generator should produce a plausible age distribution and should construct
related timestamps together so ordering is true by construction.

Lockdown Mode should be either pass-through or an explicit policy constant. It
is not a good candidate for random seed derivation because the rare enabled
state has high entropy.

Excluded CPU/RAM constants remain dependencies of the device cohort. If another
profile selects an iPhone class, the processor count, memory, CPU identifiers,
GPU/Metal data, screen, and model identifiers must all describe the same
coherent device family.

## Impact and Tradeoffs

OS and kernel spoofing can break feature gating, compatibility checks, crash
diagnostics, analytics bucketing, and server-side support flows if the app sees
an OS version that does not match actual runtime behavior. Partial spoofing is
worse than pass-through because inconsistencies are easy to detect.

Boot-time mitigation has low direct user-visible impact, but high coherence
risk. A future boot time, a boot time older than the volume, or an uptime that
does not match `kern.boottime` is a strong synthetic-profile marker.

Lockdown Mode normalization may hide a rare security setting, but it can also
make the app's observed environment contradictory if the OS is visibly enforcing
Lockdown Mode limits. Default pass-through is the safer compatibility choice;
strict normalization is useful only for users who accept the contradiction risk.

Excluding processor count and RAM avoids treating coarse hardware-model
constants as independent System Info values. They are still relevant to
fingerprinting, but they should be generated and tested as part of a complete
hardware/device profile.

The implemented `system.memory_counters` option covers live Mach VM counter
precision only. It does not report a different RAM tier, physical memory amount,
processor count, or hardware cohort.

## Exclusion Note

Omitted Loupe System Info constants:

- `processorCount`
- `physicalMemory`

Reason: both are coarse, mostly model-derived hardware proxies. They should be
covered by the hardware model, CPU, GPU/Metal, display, and device-profile
coherence work instead of being assigned standalone System Info mitigations.

## Relevance

This category remains relevant for v1 because `kern.boottime` is already part of
the validated first mitigation group, and OS/kernel state is a high-priority
coherence dependency for many other surfaces. Lockdown Mode is lower priority
than boot time and OS/kernel state, but it should stay documented because a rare
enabled state can contribute meaningful entropy without any permission prompt.
