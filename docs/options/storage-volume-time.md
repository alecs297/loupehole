# storage.volume_creation_time

Name: Volume creation time
Status: experimental
Default behavior: enabled when the module is selected
Affected APIs: `NSURL getResourceValue:forKey:error:`,
`NSURL resourceValuesForKeys:error:`, `NSURLVolumeCreationDateKey`
Permissions: none

Original API behavior:

Foundation URL resource APIs can expose volume-level creation or initialization
metadata.

Fingerprinting mechanism:

Volume creation time can reveal device setup or restore history and can be
compared with boot time for temporal correlation.

Mitigation behavior:

The selected Foundation mitigation hooks URL resource-value APIs for
`NSURLVolumeCreationDateKey` and asks the policy engine for the synthetic volume
creation time from the temporal resolver's state blob. Other resource keys pass through.

Common defaults:

The temporal resolver derives the same boot anchor used by the boot-time value,
derives a second offset, and subtracts that offset to produce a volume creation
time before boot. The value is kept in policy state, not in hook code.

Value lifetime:

Per-scope stable when local state is writable. Embedded fallback can operate
without writable state.

Value dependencies:

Must stay earlier than `system.boot_time`.

Temporal dependencies:

`volumeCreationTime < bootTime < now`.

Drawbacks:

Only the Foundation URL resource APIs are implemented in this phase. Lower-level
`stat`, `fstat`, `lstat`, and `getattrlist` alignment can be added as separate
mitigation modules.

Detection and uniqueness risks:

Temporal contradiction with boot time is high risk. The temporal generator
constructs `volumeCreationTime < bootTime` directly from shared derivation
anchors.

Test plan:

Manual Loupe comparison after injection should show volume creation time
normalized and earlier than synthetic boot time.

Validation:

Phase 3 manual Loupe validation passed on 2026-06-18.

Rollback:

If hook installation or policy lookup fails, pass through only volume creation
date resource queries.
