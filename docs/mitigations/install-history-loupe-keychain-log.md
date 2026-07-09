# `install_history.loupe_keychain_log`

The Loupe previous-install log option isolates the exact Keychain/UserDefaults pattern used by Loupe's reinstall probe and presents a one-entry fresh-install history.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `install_history.loupe_keychain_log` |
| Implemented mitigation | `install_history.loupe_keychain_log.fresh_install` |
| Policy seeds | `app_install_date`, `volume_creation_date` |
| User-facing name | Loupe previous-install log |
| Status | Experimental |
| Surface | Previous Installs Log |
| Classification | Active durable reinstall tracking pattern; active Keychain/UserDefaults hook mitigation |
| Affected APIs | `SecItemCopyMatching`, `SecItemAdd`, `SecItemUpdate`, `SecItemDelete`, `NSUserDefaults boolForKey:`, `objectForKey:`, `setBool:forKey:`, `setObject:forKey:` for Loupe's exact keys |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None |

## Surface And Relevance

Loupe stores install timestamps in a generic-password Keychain item with service `co.mysk.loupe.installLog` and account `installDates`, then uses `KeychainInstallLog.hasRecorded` in UserDefaults to avoid appending a duplicate for the current install. The Keychain item can survive delete/reinstall and reveal prior app lifetimes.

## Mitigation Strategy

The mitigation recognizes only Loupe's documented service/account pair and UserDefaults key. Matching Keychain reads that request data receive a JSON array with one ISO-8601 timestamp. Matching writes, updates, and deletes are acknowledged without mutating unrelated Keychain state. The UserDefaults marker reads as recorded so Loupe does not append another timestamp for the synthetic current install.

All other Keychain and UserDefaults keys pass through.

## Derivation And Lifetime

The mitigation reuses the app install-date value owner:

```c
LH_POLICY_SEED(app_install_date)
LH_POLICY_SEED(volume_creation_date)
```

| Item | Value |
| --- | --- |
| Shared helper | `LHAppInstallDateCopySyntheticTimestamp` |
| Log shape | One-entry JSON date array |
| Install count effect | Looks like a first install: `installCount == 1`, no prior `installLog` sequence |
| Derivation input | active/practical seed + generated policy seed + active `LHScope` |
| State behavior | Same persisted `app_install_date` state as the app install-date mitigation |
| Coherence dependency | Current install timestamp agrees with app container install date |

## Impact And Tradeoffs

This is intentionally not generic Keychain isolation. Apps can store authentication tokens, purchases, keys, and legitimate migration state in the same API family. A broad Keychain namespace rewrite belongs to a separate design with per-app compatibility controls.

The module covers Loupe's known reinstall-tracking pattern only. Access groups, app-specific service names, synchronizable items, server-side reinstall history, and lower-level filesystem markers remain uncovered.

## Validation

Expected observations after catalog selection and generation:

- Loupe's install log reads as a one-entry fresh-install history.
- The timestamp matches the synthetic app install-date state.
- Repeated collection does not append duplicate synthetic entries through Loupe's UserDefaults marker.
- Unrelated Keychain items pass through.

## Rollback And Pass-Through

If no hooks install, the module registers as a no-op. If synthetic app-install state cannot be loaded, matching Keychain reads fall through to the original Keychain call. Disabling the module restores real Keychain and UserDefaults behavior for Loupe's keys.
