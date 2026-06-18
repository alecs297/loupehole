# system.boot_time

Name: Device boot time
Status: experimental
Default: standard
Affected APIs: `sysctl`, `sysctlbyname`, `__sysctl`, `__sysctlbyname`, `kern.boottime`, `NSProcessInfo.systemUptime`
Permissions: none

Original API behavior:

`kern.boottime` exposes the device's last boot timestamp as a `timeval`.

Fingerprinting mechanism:

Boot time is stable until reboot and can link app sessions, especially when
combined with storage initialization dates and other passive signals.

Mitigation behavior:

The default selected mitigation is `system.boot_time.composite.synthetic`. It
imports the sysctl-family hook adapter and the `NSProcessInfo.systemUptime`
adapter. The sysctl adapter hooks `sysctl` and `sysctlbyname` for
`kern.boottime`; it also hooks the underscored syscall entry names when present
because Swift and libSystem callers can bind closer to those symbols than the
public wrappers. The backend applies both implementation patching and
imported-symbol rebinding for those names. The ProcessInfo adapter returns an
uptime derived from the same synthetic boot timestamp. Non-boot-time calls pass
through to the original functions.

Common defaults:

The temporal resolver derives a boot time before `now` from the active instance
seed and scope, then stores it in the temporal state blob when a writable
provider is available. Hook code does not embed the timeline.

Value lifetime:

Per-scope stable when local state is writable. Embedded fallback can operate
without writable state.

Value dependencies:

Must stay later than `storage.volume_creation_time`.

Temporal dependencies:

`volumeCreationTime < bootTime < now`.

Drawbacks:

Apps that compare additional uptime-adjacent APIs may still observe
unimplemented surfaces until later mitigations are added.

Detection and uniqueness risks:

Returning contradictory temporal values is high risk. The temporal generator
builds boot and volume values from shared seed-derived anchors so the ordering is
true by construction.

Test plan:

Manual Loupe comparison after injection should show `kern.boottime` normalized
through Loupe's `SysctlHelper.timeval("kern.boottime")` path and still later
than the synthetic volume creation time.

Validation:

Phase 3 manual Loupe validation passed on 2026-06-18.

Rollback:

If hook installation or policy lookup fails, pass through only the affected
boot-time query path.
