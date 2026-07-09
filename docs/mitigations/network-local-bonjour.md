# `network.local_bonjour`

The local Bonjour option suppresses Network.framework browser result delivery so short local-service inventory probes observe an empty result stream rather than discovered service names. It is a strict mitigation for the Local Network surface.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `network.local_bonjour` |
| Implemented mitigation | `network.local_bonjour.nwbrowser.empty_results` |
| Policy seeds | None |
| User-facing name | Local service browsing |
| Status | Experimental |
| Surface | Local Network |
| Classification | Active permissioned local-service browse; active hook mitigation |
| Affected APIs | Network.framework `nw_browse_descriptor_create_bonjour_service`, `nw_browser_create`, `nw_browser_set_browse_results_changed_handler`, including Swift `NWBrowser` call paths that reach those symbols |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | Does not bypass or grant Local Network permission |

## References

- Apple Network: `NWBrowser`.
- Apple Network: Bonjour browser descriptors.
- Apple technote TN3179, local network privacy.

## Surface And Relevance

Bonjour browsing can reveal nearby media devices, printers, file servers, smart-home bridges, remote-management services, development tools, and personalized service names. The reviewed Local Network surface starts short `NWBrowser` sessions across common service types and emits discovered instance names.

## Mitigation Strategy

The mitigation hooks Bonjour descriptor and browser creation to identify Loupe's self-published `_loupe-probe._tcp` permission probe and passes that probe through. Other Bonjour browsers keep their lifecycle but have their browse-result handler replaced with a copied no-op block, so discovered services are not delivered to the app.

This avoids presenting inventory browses as start failures and avoids fabricating invalid Network.framework result objects. It installs direct function hooks when symbols are already present and imported-symbol hooks for call sites that import those symbols.

This is a strict suppression strategy. It avoids inventing a fake household or workplace inventory, and it preserves the system permission boundary by not returning synthetic services.

## Derivation And Lifetime

No policy seed is declared because the module does not synthesize service names, counts, or timing values. The visible inventory profile is empty/no results while enabled. The known `_loupe-probe._tcp` permission check remains pass-through so authorization probes do not time out as unknown.

## Impact And Tradeoffs

This can break legitimate discovery for printers, scanners, TVs, speakers, HomeKit, Matter, file sharing, local web setup pages, and diagnostics. It does not cover legacy `NetService`, DNS-SD C APIs, direct multicast, local hostname resolution, Bluetooth-adjacent discovery, or app-specific pairing protocols.

Because the hook suppresses `NWBrowser` result delivery broadly, protected apps that rely on Network.framework browsing for core functionality should use runtime policy pass-through.

## Validation

Expected observations:

- Swift `NWBrowser` Bonjour inventory browses that reach Network.framework C browser symbols do not deliver service-result callbacks.
- The `_loupe-probe._tcp` permission browser remains pass-through.
- The module registers as a no-op when the symbol cannot be hooked.
- The mitigation does not grant Local Network permission or expose services before permission.

Repo-level validation is pending until the catalog entry is merged and the generated registry includes this module.

## Rollback And Pass-Through

Disabling the module restores normal browser result delivery. If neither direct nor imported-symbol hook installation succeeds, the module registers as a no-op.
