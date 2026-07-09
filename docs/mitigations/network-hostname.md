# `network.hostname`

The hostname option normalizes common local host-name reads to a generic device-class value. It covers passive local network identity surfaces that can otherwise mirror personalized device names.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `network.hostname` |
| Implemented mitigation | `network.hostname.composite.generic_device_name` |
| Policy seeds | None |
| User-facing name | Local hostname |
| Status | Experimental |
| Surface | Network |
| Classification | Passive local hostname read; active hook mitigation |
| Affected APIs | `gethostname`, `uname`, `sysctl`/`sysctlbyname` for `kern.hostname`, `NSProcessInfo.hostName` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None |

## References

- Apple archived iOS manual pages for `gethostname(3)` and `sysctl(3)`.
- Apple Foundation: `ProcessInfo.hostName`.

## Surface and Relevance

Local host names can encode a user name, owner label, device nickname, enterprise asset naming pattern, or other local-network identity. The value should agree across BSD, sysctl, Foundation, and future device-name surfaces.

## Mitigation Strategy

The mitigation hooks the main observed native paths and returns `iPhone` or `iPad` as a low-entropy cohort value using the same runtime device-family check as the identity hostname/device-name mitigations. `uname` calls first ask the original implementation for the rest of the structure, then replace only `nodename`.

The module intentionally avoids seed-derived names. A stable unique fake hostname can become a stronger identifier than a common generic value.

## Derivation and Lifetime

No policy seed is declared because the module returns a cohort constant rather than a scoped unique value. The value is stable while enabled and rotates only if the source policy changes.

## Impact and Tradeoffs

Host-name normalization can confuse diagnostics, enterprise tools, device-management flows, local sharing, support screens, and apps that need to show or match the real host name. Interface addresses, Bonjour names, `UIDevice.name`, and other device-name surfaces are not covered by this page and may still contradict this generic value until those modules exist.

## Validation

Expected observations:

- `gethostname` reports `iPhone` or `iPad` according to the runtime device family.
- `uname.nodename`, `kern.hostname`, and `NSProcessInfo.hostName` report the same value through covered paths.
- Non-hostname sysctl calls pass through.

Repo-level validation is pending until the catalog entry is merged and the generated registry includes this module.

## Rollback and Pass-Through

Disabling the module restores original host-name behavior. If no hook installs, the module registers as a no-op. Sysctl write attempts and unrelated sysctl names pass through to the original implementation.
