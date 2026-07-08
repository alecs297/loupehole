# Storage

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/StorageProvider.swift`

Loupe category: Storage
Loupe tier: passive local volume metadata
Permission required: none
Primary relevance: free-space correlation, volume lifetime, and storage-profile
coherence.

This category covers volume metadata that a normal app can read from Foundation
URL resource APIs without a runtime permission prompt. Loupe queries the app
home directory, so the returned values describe the volume that contains the app
container rather than files owned by another app.

## Official Links

- Apple Developer: [`URL.resourceValues(forKeys:)`](https://developer.apple.com/documentation/foundation/url/resourcevalues%28forkeys%3A%29)
- Apple Developer: [`NSURL resourceValuesForKeys:error:`](https://developer.apple.com/documentation/foundation/nsurl/resourcevalues%28forkeys%3A%29?language=objc)
- Apple Developer: [`NSURL getResourceValue:forKey:error:`](https://developer.apple.com/documentation/foundation/nsurl/getresourcevalue%28_%3Aforkey%3A%29?language=objc)
- Apple Developer: [`URLResourceValues`](https://developer.apple.com/documentation/foundation/urlresourcevalues)
- Apple Developer: [`URLResourceKey`](https://developer.apple.com/documentation/foundation/urlresourcekey)
- Apple Developer: [`volumeTotalCapacityKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/volumetotalcapacitykey)
- Apple Developer: [`volumeAvailableCapacityKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/volumeavailablecapacitykey)
- Apple Developer: [`volumeAvailableCapacityForImportantUsageKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/volumeavailablecapacityforimportantusagekey)
- Apple Developer: [`volumeAvailableCapacityForOpportunisticUsageKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/volumeavailablecapacityforopportunisticusagekey)
- Apple Developer: [`volumeCreationDateKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/volumecreationdatekey)
- Apple Developer: [`volumeUUIDStringKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/volumeuuidstringkey)
- Apple Developer: [`volumeNameKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/volumenamekey)
- Apple Developer: [`volumeLocalizedNameKey`](https://developer.apple.com/documentation/foundation/urlresourcekey/volumelocalizednamekey)
- Apple Developer: [Checking Volume Storage Capacity](https://developer.apple.com/documentation/foundation/checking-volume-storage-capacity)

Apple documents these as read-only volume resource values. The important and
opportunistic capacity keys are intended for different storage-planning cases:
important data that the app needs or the user requested, and nonessential data
that the system may treat more conservatively.

## Loupe Signals

Loupe builds a `URL(fileURLWithPath: NSHomeDirectory())`, requests all storage
keys in one `resourceValues(forKeys:)` call, then emits any value that Foundation
returns.

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `total` | `URLResourceValues.volumeTotalCapacity`, requested through `volumeTotalCapacityKey` | None | Passive volume metadata read | Exclude as a standalone Storage mitigation; keep as device/storage-cohort dependency | Low to medium. Total capacity is mostly a storage SKU and hardware profile proxy. It reduces the cohort, but treating it as independently random would create contradictions with model, free space, and quota behavior. |
| `available` | `URLResourceValues.volumeAvailableCapacity`, requested through `volumeAvailableCapacityKey` | None | Passive volume metadata read | Include | High for short-to-medium correlation. Exact free bytes are user-specific, change slowly, and can link app launches, reinstalls, and web sessions. |
| `reclaimable` | `volumeAvailableCapacityForImportantUsage` and `volumeAvailableCapacityForOpportunisticUsage` | None | Passive volume metadata read | Include | Medium to high. The important/opportunistic pair exposes purgeable-cache and iCloud-eviction headroom, not just ordinary free bytes. The gap between the two can reveal local storage pressure and content-cache shape. |
| `created` | `URLResourceValues.volumeCreationDate`, requested through `volumeCreationDateKey` | None | Passive temporal volume metadata read | Include | High. Volume creation date can reveal device setup, erase, restore, or migration timing, and it is stable across app launches until the underlying volume history changes. |
| `uuid` | `URLResourceValues.volumeUUIDString`, requested through `volumeUUIDStringKey` | None | Passive volume identity metadata read | Include as low-priority coherence/pass-through surface | Low on current Loupe observations because the value appears common across iOS and iPadOS devices, but it is still a volume identifier and should not become a unique synthetic marker. |
| `name` | `volumeName` and `volumeLocalizedName`, requested through `volumeNameKey` and `volumeLocalizedNameKey` | None | Passive human-readable volume metadata read | Include as low-priority coherence/pass-through surface | Low on current Loupe observations because the values appear common, but localized names can still become a consistency check across Foundation, filesystem, OS version, and locale. |

Loupe formats byte counts with `ByteCountFormatter` using `.file` style and
includes the actual byte count in the display string. The hook surface should
therefore reason about raw byte values, not the formatted strings Loupe shows.

## Permission and Activity Classification

No included Loupe Storage signal requires Contacts, Location, Photos, Bluetooth,
Local Network, Motion, or another user-granted runtime permission. A sandboxed
app can query these Foundation resource values for a URL inside its own
container.

This category is passive in the fingerprinting sense. The app calls local
Foundation APIs and receives volume metadata. It does not scan another app,
touch the network, prompt the user, or force a system purge. The important and
opportunistic capacity APIs expose the system's estimate of available storage
for different usage classes, but Loupe's read path does not itself reclaim
space.

Mitigation code is active because it hooks Objective-C/Foundation resource-value
methods, but the original fingerprint surface is passive local metadata.

## Fingerprinting Value

Available capacity is the strongest capacity signal because exact free bytes are
user-shaped. Installed apps, downloaded media, Messages attachments, Photos
library size, cache state, offline maps, and app documents all influence it. Two
observations with the same or very close free-space value can link sessions even
when stable identifiers are hidden.

The important and opportunistic capacity pair adds more detail than a single
free-space value. It can reveal how much space the OS believes can be made
available for critical versus nonessential work. That difference can expose
purgeable caches, cloud-backed content, recent storage pressure, and whether the
device is close to a cleanup threshold.

Volume creation date is a stable timeline anchor. Apps can compare it with
`kern.boottime`, app install dates, file creation dates, container timestamps,
profile-reset dates, and server-side first-seen timestamps. A protected profile
that spoofs boot time but leaves the real volume date visible can still leak the
device history.

Volume UUID, volume name, and localized name appear low-entropy on current
iOS/iPadOS observations, and Loupe's own rationale says the name and UUID appear
identical across devices. They remain relevant because a rare future value, a
platform difference, or a synthetic value containing a project-specific string
would stand out. They are also useful consistency checks when an app compares
Foundation, filesystem, and locale-derived metadata.

Total capacity is useful to trackers as a storage-tier classifier, but it is
mostly a coarse SKU proxy. It should be handled by the broader hardware/device
cohort rather than as an independent per-user Storage value.

## Mitigation Strategy Ideas

### `storage.available_capacity`

Hook Foundation resource-value reads that can return:

- `NSURLVolumeAvailableCapacityKey`
- `NSURLVolumeAvailableCapacityForImportantUsageKey`
- `NSURLVolumeAvailableCapacityForOpportunisticUsageKey`
- Swift `URL.resourceValues(forKeys:)`
- Objective-C `-[NSURL resourceValuesForKeys:error:]`
- Objective-C `-[NSURL getResourceValue:forKey:error:]`

Default behavior should be compatibility-first. Many apps use free-space checks
before downloads, recording, media export, database compaction, and cache
growth. Passing through is safest for apps that genuinely need accurate storage
availability.

Standard privacy behavior can bucket exact byte values into broad common ranges
while preserving the user's real storage-pressure class. For example, the
mitigation can return a bucketed value such as "about 8 GB free" instead of an
exact byte count. Buckets should be wide enough that many users share the same
result, and they should avoid implausible precision.

Strict behavior can return a slowly varying synthetic storage state, but the
three capacity fields must be generated together. A practical invariant is:

```text
0 <= available <= opportunistic <= important <= total
```

If the real platform returns `nil` for any key, the mitigation should normally
preserve that shape instead of inventing unsupported values. If the app writes a
large file and immediately queries capacity again, the synthetic state should
either pass through or move in the expected direction rather than remain frozen.

Adjacent lower-level APIs are future coverage, not solved by the Foundation hook
alone. Apps may compare Foundation output with `statfs`, `fstatfs`,
`getattrlist`, file-system attributes, app container sizes, WebKit storage
quota, or server-observed upload/download behavior.

### `storage.volume_creation_time`

Existing option: `storage.volume_creation_time`

Keep this as a temporal lifetime value, not an isolated date replacement. The
current option hooks Foundation URL resource-value methods for
`NSURLVolumeCreationDateKey` and asks the policy engine for a typed synthetic
Unix timestamp.

The value must satisfy the project timeline rules:

```text
profileEpoch <= volumeCreationTime < bootTime < now
volumeCreationTime <= appInstallTime
```

If an app compares volume date with `kern.boottime`, `systemUptime`, app
container creation, Documents/Caches/Application Support timestamps, install
markers, or file metadata, those surfaces should not contradict the synthetic
timeline. Until lower-level filesystem timestamp coverage exists, this
mitigation should document that only the Foundation volume resource-value path
is covered.

### `storage.volume_identity`

Hook Foundation reads for:

- `NSURLVolumeUUIDStringKey`
- `NSURLVolumeNameKey`
- `NSURLVolumeLocalizedNameKey`

Compatibility default should pass through because current observations suggest
these are common values on iOS and iPadOS. Strict behavior can return common
cohort values, but it should not generate per-user unique names or UUIDs.

Never expose readable project names, mitigation names, profile IDs, salts, or
state labels through volume names. Localized names should remain compatible with
the selected OS and locale profile. If `volumeName` and `volumeLocalizedName`
differ, the pair should differ in a normal platform way, not because one path
was spoofed and the other was left real.

### `storage.total_capacity`

Do not create a first-class standalone mitigation that chooses a random total
capacity. Total capacity should come from the selected hardware/storage cohort
if and when Loupehole exposes a complete device profile. If that profile selects
a storage tier, total capacity, available capacity, filesystem quota behavior,
WebKit storage estimates, and app-visible storage settings should all describe
the same class of device.

For strict profiles that hide hardware tiers, total capacity can be bucketed or
cohort-normalized as part of that wider profile. As an isolated Storage value,
pass-through is less risky than returning a capacity that conflicts with the
real model, APFS behavior, or available-space values.

## Derivation Considerations

Capacity values should be low-entropy and slowly varying. Do not derive exact
byte counts directly from the seed; a seed-derived exact value can become a new
identifier. Prefer broad common buckets with realistic drift and stable results
inside short observation windows.

Available, opportunistic, important, and total capacity should be generated as a
tuple. The tuple needs internal ordering, realistic free-space ratios, and
coherence with the selected hardware/storage cohort. If total capacity is
passed through, synthetic free-space values must still be less than that real
total.

Free-space lifetime should depend on policy mode:

| Mode | Suggested lifetime | Notes |
| --- | --- | --- |
| Pass-through | Real current value | Maximum compatibility. |
| Bucketed | Slowly varying bucket | Preserve storage-pressure class while reducing exact entropy. |
| Strict synthetic | Per-scope temporal state | Stable across relaunches for the same scope, with plausible drift and optional adjustment for large writes. |

Volume creation time belongs to the temporal lifetime state domain. It should be
derived from the active scoped seed and scope, stored or reconstructed
deterministically, and generated with boot time and profile epoch so ordering is
true by construction.

Volume UUID and names should usually be cohort constants or pass-through values.
They are poor candidates for per-user random derivation. If a replacement UUID
is ever needed, choose a common platform-compatible value shape and ensure it
does not expose the active seed, scope identifier, derivation label, or package
state name.

Purpose labels for storage derivation should stay internal and seed-bound.
Returned API values must not include readable project strings or internal
storage names.

## Impact and Tradeoffs

Free-space spoofing can break real app behavior. Underreporting capacity may
make apps refuse downloads, stop recording, shrink caches, or warn the user.
Overreporting capacity may make apps start work that later fails when the real
filesystem runs out of space. The safest default is pass-through or broad
bucketed values that keep the real storage-pressure class.

Important/opportunistic spoofing has extra compatibility risk because apps use
those APIs to decide whether data is critical enough to store. A bad synthetic
gap can make an app treat purgeable content incorrectly or create behavior that
does not match actual OS cleanup decisions.

Volume creation-time spoofing has low direct user-visible impact, but high
coherence risk. A volume date after boot time, after app install, or after files
that supposedly live on the volume is a strong synthetic-profile marker.

Volume identity spoofing is usually low impact if common values are used, but
rare names or unique UUIDs can make the mitigation more identifying than the
original. Localized names also need to match locale and OS behavior.

Partial coverage is the main detection risk. Foundation URL resource hooks do
not automatically cover lower-level filesystem APIs, WebKit storage quota,
settings-reported app storage, or app-specific file timestamps. A strict Storage
profile should either cover related surfaces coherently or document the known
comparison gaps.

## Exclusion Note

Omitted from standalone Storage mitigation planning:

- `total` / `URLResourceValues.volumeTotalCapacity` /
  `NSURLVolumeTotalCapacityKey`

Reason: total capacity is primarily a coarse storage SKU proxy. It is relevant
to fingerprinting, but it belongs with hardware/model/storage-tier cohort
generation rather than an independent Storage value. It must still remain
coherent with available capacity, WebKit storage estimates, app quota behavior,
and the selected device profile.

## Relevance

Storage is relevant for v1 because it combines a stable temporal anchor with
slow-changing user-shaped capacity values. The existing
`storage.volume_creation_time` option already covers the most important temporal
piece, and the fingerprinting surface matrix treats Storage as P0.

Priority order:

1. `created`: keep the implemented volume creation-time mitigation coherent with
   boot time and app-install timelines.
2. `available` and `reclaimable`: reduce exact free-space entropy with buckets
   or a coherent slowly varying model.
3. `uuid` and `name`: keep common/pass-through by default, with strict cohort
   normalization only if future observations show meaningful variance.
4. `total`: exclude from standalone Storage planning and handle through the
   broader hardware/storage cohort.

The practical default should be conservative: pass through or bucket capacity,
keep volume creation time synthetic only when the temporal profile is active,
and avoid unique synthetic volume identifiers.
