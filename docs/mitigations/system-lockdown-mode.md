# `system.lockdown_mode`

The Lockdown Mode option hides Loupe's app-readable defaults key by normalizing it to the common disabled value. It is intentionally narrow and does not claim to hide OS-enforced Lockdown Mode behavior.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `system.lockdown_mode` |
| Implemented mitigation | `system.lockdown_mode.userdefaults.common_false` |
| Policy seeds | None; this module returns a common constant for one observed defaults key |
| User-facing name | Lockdown Mode defaults exposure |
| Status | Experimental |
| Surface | System info |
| Classification | Passive local defaults read; active `NSUserDefaults` hook mitigation |
| Affected APIs | `-[NSUserDefaults boolForKey:]`, `-[NSUserDefaults integerForKey:]`, `-[NSUserDefaults objectForKey:]` for `LDMGlobalEnabled` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None |

## References

- Apple Developer: `NSUserDefaults`.
- Apple Support: Lockdown Mode overview.

## Surface And Relevance

Loupe reads `UserDefaults.standard.bool(forKey: "LDMGlobalEnabled")`. A true value is rare and can reveal a user's security posture without a permission prompt. False is the common value, but it can still explain other restrictions when combined with WebKit and system behavior.

## Mitigation Strategy

The mitigation hooks three `NSUserDefaults` getter shapes for the exact key `LDMGlobalEnabled`:

- `boolForKey:` returns `NO`.
- `integerForKey:` returns `0`.
- `objectForKey:` returns `@NO`.

All other defaults keys pass through. The module does not hook CFPreferences, Settings UI, WebKit side effects, managed-profile state, or OS-level Lockdown Mode restrictions.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifiers | None |
| Value shape | Common false boolean / zero integer / false object |
| Derivation input | None |
| Storage behavior | No mitigation-owned state |
| Lifetime | Stable while the module is enabled |
| Dependencies | OS-enforced Lockdown Mode effects may still be visible elsewhere |

Lockdown Mode is not seed-derived because a random enabled value would be a high-entropy synthetic fingerprint. The chosen normalization is the common disabled value.

## Impact And Tradeoffs

Apps that use this defaults key to adapt behavior for Lockdown Mode may no longer see the rare enabled state through this path. That can create contradictions if the OS still visibly blocks features or if WebKit restrictions are observable.

## Validation

Expected observations:

- `bool(forKey: "LDMGlobalEnabled")` reports false while the module is active.
- Unrelated defaults keys keep their original behavior.
- Direct CFPreferences reads and OS behavior remain outside coverage.

## Rollback And Pass-Through

If `NSUserDefaults` or the target selectors are unavailable, the module registers as a no-op. Disabling the mitigation restores original defaults behavior for the key.
