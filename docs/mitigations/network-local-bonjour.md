# `network.local_bonjour`

The local Bonjour option suppresses Network.framework browser starts so short local-service inventory probes do not receive service names. It is a strict mitigation for the Local Network surface.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `network.local_bonjour` |
| Implemented mitigation | `network.local_bonjour.nwbrowser.suppress_start` |
| Policy seeds | None |
| User-facing name | Local service browsing |
| Status | Experimental |
| Surface | Local Network |
| Classification | Active permissioned local-service browse; active hook mitigation |
| Affected APIs | Network.framework `nw_browser_start`, including Swift `NWBrowser.start(queue:)` call paths that reach that symbol |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | Does not bypass or grant Local Network permission |

## References

- Apple Network: `NWBrowser`.
- Apple Network: Bonjour browser descriptors.
- Apple technote TN3179, local network privacy.

## Surface And Relevance

Bonjour browsing can reveal nearby media devices, printers, file servers, smart-home bridges, remote-management services, development tools, and personalized service names. The reviewed Local Network surface starts short `NWBrowser` sessions across common service types and emits discovered instance names.

## Mitigation Strategy

The mitigation hooks `nw_browser_start` and leaves the browser unstated and result-free. It installs both a direct function hook when the symbol is already present and an imported-symbol hook for call sites that import the symbol.

This is a strict suppression strategy. It avoids inventing a fake household or workplace inventory, and it preserves the system permission boundary by not returning synthetic services.

## Derivation And Lifetime

No policy seed is declared because the module does not synthesize service names, counts, or timing values. The visible profile is empty/no results while enabled.

## Impact And Tradeoffs

This can break legitimate discovery for printers, scanners, TVs, speakers, HomeKit, Matter, file sharing, local web setup pages, and diagnostics. It does not cover legacy `NetService`, DNS-SD C APIs, direct multicast, local hostname resolution, Bluetooth-adjacent discovery, or app-specific pairing protocols.

Because the hook suppresses `NWBrowser` starts broadly, protected apps that rely on Network.framework browsing for core functionality should use runtime policy pass-through.

## Validation

Expected observations:

- Swift `NWBrowser` Bonjour browses that reach `nw_browser_start` produce no service-result callbacks.
- The module registers as a no-op when the symbol cannot be hooked.
- The mitigation does not grant Local Network permission or expose services before permission.

Repo-level validation is pending until the catalog entry is merged and the generated registry includes this module.

## Rollback And Pass-Through

Disabling the module restores normal browser starts. If neither direct nor imported-symbol hook installation succeeds, the module registers as a no-op.
