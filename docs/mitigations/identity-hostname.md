# `identity.hostname`

The hostname option normalizes app-visible host-name reads to the same generic device-class vocabulary used by the device-name mitigation.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `identity.hostname` |
| Implemented mitigation | `identity.hostname.composite.generic` |
| Policy seeds | None; this mitigation returns a low-entropy cohort constant |
| User-facing name | Hostname |
| Status | Experimental |
| Surface | Device identity |
| Classification | Passive host identity surface; active C and Foundation hook mitigation |
| Affected APIs | `sysctl`, `sysctlbyname`, `__sysctl`, `__sysctlbyname`, `kern.hostname`, `gethostname`, `uname.nodename`, `NSProcessInfo.hostName` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | None |

## References

- Apple Developer: `NSProcessInfo.hostName`.
- Darwin/BSD interfaces: `sysctl`, `sysctlbyname`, `gethostname`, `uname`.
- Darwin sysctl key: `kern.hostname`.

## Surface And Relevance

`kern.hostname`, `gethostname`, `uname.nodename`, and `NSProcessInfo.hostName` can expose host naming choices that duplicate user-assigned device names or local-network identity. Alone the value is medium entropy, but it is a useful cross-check against `UIDevice.name`.

## Mitigation Strategy

The mitigation hooks direct functions and imported symbols for sysctl-family hostname reads, `gethostname`, and `uname`, and it hooks `-[NSProcessInfo hostName]`. Read-only `kern.hostname` queries return `iPad` or `iPhone` using the same UIKit idiom check as the device-name mitigation.

Non-hostname sysctl requests and sysctl write attempts pass through unchanged.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifiers | None |
| Helper/state owner | Local module idiom check and C buffer copy-out logic |
| Value shape | C string or `NSString` value `iPad` or `iPhone`, depending on API |
| Derivation input | Current UIKit device idiom |
| Storage behavior | No mitigation-owned state blob |
| Lifetime | Common cohort value changes only when the device class observed by UIKit changes |

The returned hostname intentionally has no seed-derived suffix. This avoids turning hostname into a new stable identifier.

## Impact And Tradeoffs

Network diagnostics, discovery tools, and apps that need the true host name may lose useful context. Network-interface names, Bonjour advertisements, local-network discovery behavior, and lower-level system identity values are not covered by this module.

## Validation

Expected observations after catalog selection and generation:

- `sysctlbyname("kern.hostname")`, `gethostname`, `uname.nodename`, and `NSProcessInfo.hostName` agree on the generic name.
- Non-hostname sysctl requests preserve original behavior and sizing semantics.
- The value agrees with `UIDevice.name` when the device-name mitigation is also selected.

## Rollback And Pass-Through

If no hostname hook installs, the module registers as a no-op. Non-hostname sysctl requests and sysctl write attempts pass through unchanged. If a replacement cannot safely satisfy a C buffer request, it follows normal error-style behavior or falls through to the original function where available. Disabling the mitigation restores original hostname behavior on covered APIs.
