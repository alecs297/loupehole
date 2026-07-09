# `network.vpn_proxy`

The VPN proxy option filters scoped CFNetwork proxy keys used by the reviewed Network surface's VPN heuristic. It reduces local disclosure of `tap`, `tun`, `ppp`, and `ipsec` proxy-scope keys without rewriting unrelated proxy settings.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `network.vpn_proxy` |
| Implemented mitigation | `network.vpn_proxy.cfnetwork.scoped_filter` |
| Policy seeds | None |
| User-facing name | VPN proxy-key filter |
| Status | Experimental |
| Surface | Network |
| Classification | Passive proxy-settings read; active hook mitigation |
| Affected APIs | `CFNetworkCopySystemProxySettings` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None |

## References

- Apple CFNetwork: `CFNetworkCopySystemProxySettings`.
- Apple CFNetwork global proxy settings constants.

## Surface And Relevance

The reviewed Network provider derives `vpnActive` and `vpnInterfaces` by scanning the proxy settings dictionary's `__SCOPED__` keys for names containing `tap`, `tun`, `ppp`, or `ipsec`. A true VPN heuristic can reveal sensitive security posture, workplace requirements, travel, or region workarounds.

## Mitigation Strategy

The mitigation hooks `CFNetworkCopySystemProxySettings`, calls the original function, and returns a mutable copy where only matching entries inside `__SCOPED__` are removed. Other top-level proxy keys and unrelated scoped keys are preserved.

The module deliberately does not remove `utun`, matching the surface document's caution that iOS may expose `utun` for non-VPN Apple features.

## Derivation And Lifetime

No policy seed is declared because this is a live dictionary filter rather than a synthetic value stream. The returned dictionary follows current real proxy state minus the filtered heuristic keys.

## Impact And Tradeoffs

Apps that require or diagnose a corporate VPN may mis-detect VPN status. Server-observed egress IP, DNS, latency, TLS routing, NetworkExtension state, and interface-address APIs can still reveal VPN use. This module does not filter `getifaddrs` or `NWPath` observations.

## Validation

Expected observations:

- `CFNetworkCopySystemProxySettings()["__SCOPED__"]` omits keys containing `tap`, `tun`, `ppp`, or `ipsec`.
- Unrelated proxy keys and value types remain intact.
- `utun` keys are preserved.

Repo-level validation is pending until the catalog entry is merged and the generated registry includes this module.

## Rollback And Pass-Through

Disabling the module restores the original proxy settings dictionary. If the symbol cannot be resolved or hooked, the module registers as a no-op. If the original dictionary has no scoped proxy dictionary, the replacement returns a retained copy of the original value.
