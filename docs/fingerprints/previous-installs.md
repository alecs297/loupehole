# Previous Installs Log

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/PreviousInstallsProvider.swift`

Helper reviewed: `.research/upstream/loupe/code/Loupe/Support/KeychainInstallLog.swift`

Loupe category: Previous Installs Log
Loupe tier: active durable reinstall tracking
Permission required: none
Primary relevance: uninstall/reinstall correlation, app lifetime history, and
coherence with app install date and Keychain state.

This category demonstrates that an app can keep install history in durable local
state that survives app deletion. Loupe stores an array of install timestamps in
the Keychain and uses a UserDefaults flag to decide whether the current app
installation has already been recorded.

## Official and Equivalent Links

- [Keychain Services](https://developer.apple.com/documentation/security/keychain-services)
- [`SecItemAdd(_:_:)`](https://developer.apple.com/documentation/security/secitemadd%28_%3A_%3A%29)
- [`SecItemCopyMatching(_:_:)`](https://developer.apple.com/documentation/security/secitemcopymatching%28_%3A_%3A%29)
- [`SecItemUpdate(_:_:)`](https://developer.apple.com/documentation/security/secitemupdate%28_%3A_%3A%29)
- [`SecItemDelete(_:)`](https://developer.apple.com/documentation/security/secitemdelete%28_%3A%29)
- [`kSecAttrAccount`](https://developer.apple.com/documentation/security/ksecattraccount)
- [`kSecAttrService`](https://developer.apple.com/documentation/security/ksecattrservice)
- [`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`](https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlockthisdeviceonly)
- [`UserDefaults`](https://developer.apple.com/documentation/foundation/userdefaults)

Apple documents the public Keychain Services and UserDefaults APIs used here.
Loupe's reinstall persistence is an app-level pattern built from those APIs:
UserDefaults are installation-local for this app, while the Keychain item is
durable enough to be found again after a normal delete and reinstall.

## Loupe Signals

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `installCount` | `KeychainInstallLog.installDates().count` after `recordInstallIfNeeded()` | None | Active durable local tracking on first collection; passive read after recording | Include | High. Count reveals whether this app has been installed before and how many install epochs the Keychain log remembers. |
| `firstInstall` | First timestamp in the Keychain-backed install-date array | None | Active durable local tracking | Include | High. Earliest recorded install time links current activity to a prior app lifetime. |
| `currentInstall` | Last timestamp in the install-date array when `dates.count > 1` | None | Active durable local tracking | Include | High. Current reinstall time links the new sandbox to the durable Keychain history. |
| `installLog` | All timestamps joined as ISO 8601 strings when `dates.count > 1` | None | Active durable local tracking | Include | Very high. The full sequence of install epochs is a compact behavioral and lifecycle history. |

The helper uses:

- Keychain class: `kSecClassGenericPassword`
- Service: `co.mysk.loupe.installLog`
- Account: `installDates`
- Data format: JSON-encoded `[Date]` with ISO 8601 date coding
- Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- UserDefaults marker: `KeychainInstallLog.hasRecorded`

On first launch of an installation, UserDefaults does not contain the marker, so
Loupe appends `Date()` to the Keychain array and then writes the marker. On a
later launch of the same installation, it reads the existing array without
appending. After delete and reinstall, UserDefaults is gone but the Keychain
item can remain, so Loupe appends another timestamp.

## Permission and Activity Classification

No Previous Installs signal requires Contacts, Location, Bluetooth, Local
Network, Motion, Photos, Calendar, Reminders, Music, or another user-granted
runtime permission. The Keychain calls shown here do not use biometric access
control or a user-presence prompt.

This category is active durable tracking, not merely passive metadata. The
provider calls `recordInstallIfNeeded()` as part of collection, and that helper
can write a new Keychain timestamp before Loupe displays the signals.

After the current installation has been recorded, subsequent collection is a
local Keychain read. The fingerprinting risk remains durable because the stored
state can outlive the app container.

## Fingerprinting Value

Previous-install history is high value because it survives the boundary many
users expect to reset app state: deleting and reinstalling the app. The current
container can look fresh while the Keychain log still says the app existed
before.

`installCount` is enough to distinguish a first-time install from a reinstall.
That matters for anti-abuse systems, trial eligibility, account recovery,
onboarding, and analytics attribution.

`firstInstall` and `currentInstall` are timeline anchors. They can be compared
with app-container creation date, volume creation date, boot time, file
timestamps, server first-seen timestamps, and account creation dates. If those
values disagree, the synthetic profile is detectable.

`installLog` is stronger than either date alone because the sequence of
reinstall events can be distinctive. A user who installed the app three times
on particular days has a small lifecycle signature even without IDFV, account
tokens, or network identifiers.

The Keychain item is app-scoped unless the app uses access groups, but that is
still valuable. A single app can reconnect its own local state after reinstall,
and apps from the same developer can intentionally share Keychain state through
configured access groups.

## Mitigation Strategy Ideas

### `install-history.keychain-log`

Treat durable reinstall state as a Keychain/UserDefaults coherence problem, not
as a single displayed string. Coverage should consider:

- `SecItemCopyMatching`
- `SecItemAdd`
- `SecItemUpdate`
- `SecItemDelete`
- generic-password queries keyed by service/account/access group
- UserDefaults first-run markers that decide whether to append a new record

Compatibility default should pass through. Apps store authentication tokens,
licensing state, encryption keys, user preferences, and legitimate migration
markers in the Keychain. Broadly hiding or deleting Keychain items can log users
out, break paid features, or destroy app data.

Strict mode should be narrow and non-destructive. Prefer intercepting reads and
writes for known reinstall-tracking keys over deleting real Keychain items. For
Loupe's pattern, a strict profile can present an empty or one-entry install log
to the process while leaving unrelated Keychain entries untouched.

When the mitigation hides old install history, it must also handle the
UserDefaults marker. If UserDefaults says the current install has already been
recorded but the synthetic Keychain log is empty, the app can observe a
contradiction. If UserDefaults is absent and the synthetic Keychain log already
contains a current-install timestamp, repeated launches should not append
duplicates.

### `install-history.scope-isolation`

Provide an app-scope or profile-scope isolation mode for durable local state.
The practical goal is that a protected app sees a fresh Keychain namespace when
the selected Loupehole scope says it should, without corrupting the real
Keychain database.

Potential policy shapes:

- Pass-through: real Keychain state.
- Fresh install: no prior log; record only the synthetic current install.
- Current app lifetime: one stable current-install timestamp.
- Full synthetic history: a coherent but low-entropy install history, used only
  when a target app expects previous installs and breaks on a fresh state.

Do not synthesize many exact timestamps from hash output. A detailed fake
history can be more identifying than a one-entry fresh-install shape.

## Derivation and Coherence Considerations

Previous-install data belongs to the temporal and durable-state domains. A
synthetic record should be generated as a tuple:

```text
installCount == number of installLog timestamps
firstInstall == earliest installLog timestamp
currentInstall == latest installLog timestamp when count > 1
firstInstall <= currentInstall <= now
volumeCreationTime <= firstInstall when modeling one device lifetime
app installDate is close to currentInstall for the current sandbox
```

For a first install, Loupe emits `installCount` and `firstInstall`, but it does
not emit `currentInstall` or `installLog` because the count is one. A mitigation
that wants to look like a first install should preserve that signal shape.

For a reinstall, the current-install timestamp should be close to the app
Documents directory creation date and any first-launch marker. It should not be
before the volume creation date, after the current wall clock, or inconsistent
with boot/session timing.

Scope selection matters. A durable install marker can be per app, per vendor
access group, per app group, per profile, or pass-through. The selected scope
must be stable and documented, because rotating it unexpectedly can log users
out or make paid/trial state look tampered with.

`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` means the stored item is
device-local and availability depends on first unlock after restart. If a
profile models backup/restore or migration, do not treat this Keychain item as a
cloud-synced account value.

Purpose labels and synthetic Keychain service/account names should remain
internal and seed-bound. Returned data must not expose readable mitigation
names, salts, or Loupehole identifiers.

## Impact and Tradeoffs

Keychain mitigation has high blast radius if it is broad. The same API family
stores login tokens, refresh tokens, cryptographic keys, app passwords, purchase
state, and account recovery data. A generic denylist can break the app more
than it protects the user.

Fresh-install isolation improves privacy against reinstall tracking, but it can
reset legitimate app state. Users may be logged out, lose device trust, repeat
onboarding, lose trial/purchase continuity, or trigger fraud checks if the app
expects durable state.

Synthetic histories have lower compatibility risk for apps that expect a prior
install, but higher fingerprinting and detection risk. Exact fake timestamps,
impossible ordering, or mismatch with container dates can stand out.

The safest implementation is narrow, policy-driven, and non-destructive: hide or
reshape tracking keys for selected apps while leaving unrelated Keychain data
alone.

## Exclusion Note

No coarse hardware/model constants appear in Loupe's Previous Installs provider.

The helper's raw service name, account name, accessibility class, and
UserDefaults key are implementation details, not separate Loupe fingerprint
signals. They are documented here because mitigation needs to understand the
storage pattern, but the included fingerprinting surfaces are the emitted count
and timestamp values.

## Relevance

Previous Installs Log is relevant because it shows a durable app-local identity
class that survives delete/reinstall and requires no user permission prompt.
This is P0 research for any profile that promises reset semantics, install
freshness, or per-app isolation.

The mitigation priority is not "spoof four strings." It is coherent state
isolation: app install date, Keychain history, UserDefaults first-run markers,
volume lifetime, and profile reset behavior must describe the same lifecycle.
