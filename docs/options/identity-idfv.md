# identity.idfv

Name: Vendor identifier
Status: experimental
Default: standard
Affected APIs: `UIDevice.identifierForVendor`
Permissions: none

Original API behavior:

`UIDevice.identifierForVendor` returns an app-vendor-scoped UUID managed by iOS.
It can remain stable across related apps and can participate in reinstall or
cross-app correlation patterns.

Fingerprinting mechanism:

Apps and SDKs can use the vendor identifier as a stable native identifier and
combine it with boot, storage, and device-profile signals.

Mitigation behavior:

The tweak hooks `UIDevice.identifierForVendor` and asks the policy engine for a
per-scope UUID from the IDFV resolver's state blob. The hook does not generate values.
If policy state is unavailable, the hook passes through to the original API.

Common defaults:

The default scope is per app. The generated UUID is deterministic for the active
configuration instance seed and scope, and is stored in the IDFV state blob
when the local provider is available.

Value lifetime:

Per-scope stable until state is reset or the configuration instance seed changes.

Value dependencies:

Shares scope and state lifetime with the first temporal mitigation group.

Temporal dependencies:

None directly.

Drawbacks:

Apps that expect sibling apps from the same vendor to share the same IDFV may
need a future vendor-group scope configuration.

Detection and uniqueness risks:

Per-user random IDs can become identifying if scoped inconsistently. The current
implementation keeps generation in the policy resolver and out of hook code.

Test plan:

Manual Loupe comparison after injection should show a scoped UUID distinct from
the real IDFV and stable across relaunches for the same scope.

Rollback:

If hook installation or policy lookup fails, pass through only this affected API.
