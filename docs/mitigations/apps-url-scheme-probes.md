# `apps.url_scheme_probes`

The URL-scheme probe option suppresses the known installed-app probe list used by the reviewed Installed Apps surface. It covers active local URL-scheme capability checks through `UIApplication.canOpenURL:`.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `apps.url_scheme_probes` |
| Implemented mitigation | `apps.url_scheme_probes.uiapplication.known_list` |
| Policy seeds | None |
| User-facing name | Installed app probes |
| Status | Experimental |
| Surface | Installed Apps Probe |
| Classification | Active local URL-scheme probing; active hook mitigation |
| Affected APIs | `-[UIApplication canOpenURL:]` for the documented third-party probe schemes |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None; iOS still enforces the caller's `LSApplicationQueriesSchemes` declarations |

## References

- Apple Developer: `UIApplication.canOpenURL(_:)`.
- Apple Information Property List reference: `LSApplicationQueriesSchemes`.

## Surface And Relevance

The installed-app probe asks iOS whether a fixed set of third-party URL schemes can be opened. Positive answers reveal installed apps and interests such as messaging, social networking, dating, finance, crypto, browsers, password managers, VPN, mobility, and media apps.

## Mitigation Strategy

The mitigation hooks `-[UIApplication canOpenURL:]`. For the reviewed 50 third-party probe schemes, the replacement returns `NO`. Other schemes pass through to the original implementation.

The mitigation does not synthesize positive answers. Returning `YES` for apps that are not installed would create contradictions when the caller later attempts to open the URL. It also does not hide the protected app's own `LSApplicationQueriesSchemes` list, because that list is the querying app's declared metadata rather than an installed-app result.

Blanket `NO` for every scheme is intentionally avoided. Apps use `canOpenURL:` for their own OAuth/SSO callbacks, payment handoffs, maps, mail, phone, app-to-app workflows, and companion-app detection. Returning `NO` for all schemes can break legitimate flows and can itself look abnormal because common first-party or app-owned schemes would appear unavailable.

## Derivation And Lifetime

No policy seed is declared because this module does not create a value stream. It returns one low-entropy strict result for the documented probe list: absent.

The result is stable for every read while the module is enabled. Rotation is controlled only by runtime policy or by changing the protected scheme set in source.

## Impact And Tradeoffs

Apps that use one of the protected schemes for real handoff features may hide buttons or disable integrations. Direct `openURL` behavior is not changed by this mitigation, so user-initiated deep links can still work when an app calls them without first requiring `canOpenURL`.

Adjacent private installed-app enumeration, bundle-container probing, and non-UIKit macOS Launch Services APIs are not covered.

## Validation

Expected observations:

- `canOpenURL:` returns `NO` for the documented probe schemes.
- Non-listed schemes keep original behavior.
- The module registers as a no-op if `UIApplication` or the selector is unavailable.

Repo-level validation is pending until the catalog entry is merged and the generated registry includes this module.

## Rollback And Pass-Through

Disabling the module restores original `canOpenURL:` behavior. If the hook cannot install, the module registers as a no-op. If a queried scheme is outside the protected list, the replacement calls the original implementation.
