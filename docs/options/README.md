# Mitigation Options

This directory documents user-visible mitigation options. Each page describes
one option surface, the concrete mitigation currently compiled for that surface,
and the behavior an app should observe when the option is enabled, disabled, or
unable to resolve policy state.

Keep this directory scoped to option behavior. Broader roadmap status and
fingerprint inventories are owned outside this directory.

## Implemented Pages

| Option page | Implemented mitigation | Surface | Classification | Permission requirement |
| --- | --- | --- | --- | --- |
| [`identity-idfv.md`](identity-idfv.md) | `identity.idfv.uidevice.scoped_uuid` | Device identity | Passive fingerprinting surface; active hook mitigation | None |
| [`system-boot-time.md`](system-boot-time.md) | `system.boot_time.composite.synthetic` | System lifetime | Passive temporal surface; active hook mitigation | None |
| [`storage-volume-time.md`](storage-volume-time.md) | `storage.volume_creation_time.foundation.synthetic` | Storage lifetime | Passive temporal/storage surface; active hook mitigation | None |

All three pages are part of the first coherent mitigation group. The IDFV value
is scoped from the active seed, while boot time and volume creation time are
derived from the same temporal state so `volumeCreationTime < bootTime < now`.

## Page Structure

Each implemented option page should use the same high-level shape:

1. **Metadata**: option ID, mitigation ID, user-facing name, status, surface,
   active/passive classification, affected APIs, default behavior, and
   permission requirement.
2. **References**: official Apple Developer links where available. Apple open
   source, Darwin headers, BSD manual pages, or upstream platform references are
   acceptable for low-level APIs that Apple documents outside the modern
   Developer Documentation site.
3. **Surface and Relevance**: what the real API exposes and why the value is
   relevant for fingerprinting or cross-session correlation.
4. **Mitigation Strategy**: exactly which APIs are hooked, what policy value is
   requested, which calls pass through unchanged, and how the mitigation avoids
   embedding concrete fake values in hook code.
5. **Derivation and Lifetime**: seed/scope inputs, state blob ownership,
   derivation labels, value lifetime, temporal ordering, and dependencies on
   other mitigation values.
6. **Impact and Tradeoffs**: compatibility risks, detection risks, incomplete
   adjacent surfaces, and user-visible behavior.
7. **Validation**: manual Loupe evidence, repo-level checks, and the observable
   results expected from the option.
8. **Rollback and Pass-Through**: behavior when disabled, when hook installation
   fails, when policy lookup fails, or when the original API cannot be called.

## Shared Rules

- Prefer per-mitigation fallback or pass-through. Do not describe a global hook
  shutdown as normal rollback behavior.
- Keep generated values in policy resolvers or state domains, not in hook
  adapters.
- Document temporal dependencies explicitly when a value participates in a
  timeline.
- Treat permission requirements literally: if the API does not trigger an iOS
  permission prompt, say `None`.
- Distinguish the observed surface from the mitigation action. These first
  pages are passive fingerprinting surfaces, but the runtime mitigation is an
  active hook.
