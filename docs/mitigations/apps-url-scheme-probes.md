# `apps.url_scheme_probes`

The URL-scheme probe option suppresses installed-app probing by denying unknown URL schemes by default. It covers active local URL-scheme capability checks through `UIApplication.canOpenURL:`.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `apps.url_scheme_probes` |
| Implemented mitigation | `apps.url_scheme_probes.uiapplication.default_false` |
| Policy seeds | None |
| User-facing name | Installed app probes |
| Status | Experimental |
| Surface | Installed Apps Probe |
| Classification | Active local URL-scheme probing; active hook mitigation |
| Affected APIs | `-[UIApplication canOpenURL:]` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None; iOS still enforces the caller's `LSApplicationQueriesSchemes` declarations |

## References

- Apple Developer: `UIApplication.canOpenURL(_:)`.
- Apple Information Property List reference: `LSApplicationQueriesSchemes`.

## Surface And Relevance

Installed-app probes ask iOS whether third-party URL schemes can be opened. Positive answers reveal installed apps and interests such as messaging, social networking, dating, finance, crypto, browsers, password managers, VPN, mobility, and media apps.

## Mitigation Strategy

The mitigation hooks `-[UIApplication canOpenURL:]`. It passes a small allowlist of common system schemes through to the original implementation: `http`, `https`, `mailto`, `tel`, `sms`, `facetime`, and `facetime-audio`. Every other scheme returns `NO`.

The mitigation does not synthesize positive answers. Returning `YES` for apps that are not installed would create contradictions when the caller later attempts to open the URL. Common schemes are passed through rather than forced to `YES` so UIKit can still apply normal URL and platform validation. The mitigation also does not hide the protected app's own `LSApplicationQueriesSchemes` list, because that list is the querying app's declared metadata rather than an installed-app result.

This is intentionally more private and less compatible than a probe-list blacklist. Apps that use custom schemes for OAuth/SSO callbacks, payment handoffs, maps, app-to-app workflows, or companion-app detection may hide those features while the mitigation is enabled.

## Derivation And Lifetime

No policy seed is declared because this module does not create a value stream. It returns one low-entropy strict result for unknown schemes: unavailable.

The result is stable for every read while the module is enabled. Rotation is controlled only by runtime policy or by changing the allowlist in source.

## Impact And Tradeoffs

Apps that use custom schemes for real handoff features may hide buttons or disable integrations. Direct `openURL` behavior is not changed by this mitigation, so user-initiated deep links can still work when an app calls them without first requiring `canOpenURL`.

Adjacent private installed-app enumeration, bundle-container probing, and non-UIKit macOS Launch Services APIs are not covered.

## Validation

Expected observations:

- `canOpenURL:` returns `NO` for unknown/custom schemes.
- Allowed common schemes pass through to the original implementation.
- The module registers as a no-op if `UIApplication` or the selector is unavailable.

Repo-level validation should include `make generate`, the seed/state/value checks, and `make build`.

## Rollback And Pass-Through

Disabling the module restores original `canOpenURL:` behavior. If the hook cannot install, the module registers as a no-op. If a queried scheme is outside the allowlist, the replacement returns `NO`.
