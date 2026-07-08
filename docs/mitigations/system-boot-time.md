# `system.boot_time`

The boot-time option normalizes app-visible device lifetime values. It covers passive temporal fingerprinting surfaces, while the mitigation actively hooks both C sysctl callers and the Foundation uptime property.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `system.boot_time` |
| Implemented mitigation | `system.boot_time.composite.synthetic` |
| Policy seeds | `boot_time`, `volume_creation_date` |
| User-facing name | Device boot time |
| Status | Experimental |
| Surface | System lifetime |
| Classification | Passive temporal surface; active hook mitigation |
| Affected APIs | `sysctl`, `sysctlbyname`, `__sysctl`, `__sysctlbyname`, `kern.boottime`, `NSProcessInfo.systemUptime` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None; these APIs do not trigger an iOS permission prompt |

## References

- Apple Developer: [`ProcessInfo.systemUptime`](https://developer.apple.com/documentation/foundation/processinfo/systemuptime).
- Apple Developer archive: [`sysctl(3)` iOS manual page](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/sysctl.3.html).
- Apple Developer: [`sysctlbyname`](https://developer.apple.com/documentation/kernel/1387446-sysctlbyname).
- Apple open source: [`CTL_KERN` and `KERN_BOOTTIME` in Darwin `sysctl.h`](https://github.com/apple/darwin-xnu/blob/main/bsd/sys/sysctl.h).

## Surface And Relevance

`kern.boottime` exposes the system's last boot timestamp as a `struct timeval` through the sysctl MIB path `CTL_KERN, KERN_BOOTTIME` or the string name `"kern.boottime"`. `NSProcessInfo.systemUptime` exposes elapsed awake time since the last restart.

Boot time is stable until the device restarts. Apps can use it to link launches, compare sessions, infer reboot behavior, or cross-check other timeline signals such as volume creation time, app install time, logs, caches, and storage metadata.

## Mitigation Strategy

The selected mitigation is a composite installer. It imports:

- `BootTimeSysctlMitigation.c` for `sysctl`, `sysctlbyname`, `__sysctl`, and `__sysctlbyname`.
- `BootTimeProcessInfoMitigation.m` for `-[NSProcessInfo systemUptime]`.

The sysctl adapter handles read-only boot-time queries only. It recognizes `CTL_KERN, KERN_BOOTTIME` and `"kern.boottime"` when `newp == NULL`, copies out the synthetic `struct timeval`, and preserves the normal `oldp`/`oldlenp` size-query pattern. Non-boot-time sysctl calls and write attempts pass through to the original functions.

The ProcessInfo adapter reads the same boot-time value owner and returns `now - bootTime` when the result is coherent and nonnegative. This keeps uptime and boot timestamp tied to the same synthetic timeline.

The hook backend attempts direct function patching and imported-symbol rebinding for the sysctl names because app, Swift, and libSystem call sites may not all pass through a single public wrapper.

## Derivation And Lifetime

The boot-time mitigation declares:

```c
LH_POLICY_SEED(boot_time)
LH_POLICY_SEED(volume_creation_date)
```

| Item | Value |
| --- | --- |
| Value owner | `src/mitigations/system/boot_time/BootTimeValues.c` |
| State key | Managed by `LHMitigationCopyStableTimeIntervalBetween` with `LHGeneratedPolicySeed_boot_time`. |
| Boot helper | `LHMitigationCopyStableTimeIntervalBetween` with `LHGeneratedPolicySeed_boot_time` |
| Volume baseline | `LHMitigationCopyStablePastTime` with `LHGeneratedPolicySeed_volume_creation_date` |
| Value shape | `struct timeval` with microseconds set to `0`. |
| Derivation input | active/practical seed + generated policy seed + active `LHScope`. |
| Boot range | Created after the documented volume-creation baseline, at least 6 hours before first generation, and normally inside a 14-day lookback window at first generation. |
| Storage behavior | The mitigationkit stable-time helper keeps the generated boot time stable across relaunches for the same scope. |
| Temporal dependency | `volumeCreationTime < bootTime < now`. |

The boot-time mitigation intentionally declares and uses `volume_creation_date` so it can reproduce the storage mitigation's volume baseline before choosing a later boot time. This is per-mitigation coherence, not a shared state module.

## Impact And Tradeoffs

Apps that compare unimplemented uptime-adjacent APIs can still observe real values until those surfaces receive separate mitigation modules. The composite currently covers the sysctl-family boot timestamp and Foundation `systemUptime`; it does not claim to normalize every possible monotonic clock, mach time, log timestamp, or process lifetime value.

The highest detection risk is temporal contradiction. Returning a boot time that is earlier than impossible storage events, later than `now`, or inconsistent with `systemUptime` would stand out. This mitigation reduces that risk by deriving boot time after the documented volume baseline and serving boot timestamp plus uptime from its own persisted state.

## Validation

Manual Loupe validation passed on 2026-06-18. Expected observations:

- `kern.boottime` is normalized through Loupe's sysctl path.
- `NSProcessInfo.systemUptime` corresponds to the same synthetic boot timestamp.
- The synthetic boot time remains stable across relaunches for the same seed and scope.
- The synthetic boot time is later than the synthetic volume creation time and earlier than the current wall clock.
- Non-boot-time sysctl queries keep their original behavior.

## Rollback And Pass-Through

If no boot-time adapter installs, the composite mitigation registers as a no-op. If boot-time state loading fails inside an installed sysctl replacement, the replacement falls through to the original function. If no original function is available as a final safety path, the C replacement returns `-1` with `errno` set rather than manufacturing an unrelated timestamp.

For `NSProcessInfo.systemUptime`, state loading failure or an incoherent negative uptime falls through to the original implementation. If no original method is available, the last-resort return is `0.0`.

Disabling this mitigation should affect only boot-time and uptime queries. The volume creation date mitigation has its own rollback behavior.
