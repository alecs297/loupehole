# Derivation Schemes and Project Map

Loupehole is an injected iOS runtime for reducing abusive app fingerprinting. It
does not try to make hook code clever in isolation. The hook layer is deliberately
thin: it recognizes a native API call, asks the policy engine for a typed value,
and either returns that value or falls back to the original API behavior.

The important design idea is that every stable value, storage name, package path,
and generated runtime constant comes from a small set of seed and scope inputs.
Those inputs give the project two properties that are usually at odds:

- reproducibility, when a user keeps the same configured seed and scope
- rotation, when a user changes the seed, changes scope, resets package state, or
  reinstalls an app whose scope is per app install

This document is a human map of those derivation schemes and how they connect to
the rest of the project.

## The Runtime in One Pass

At process start, `packages/tweak/sources/Runtime.mm` calls `LHRuntimeStart`.
`LHRuntimeStart` creates one `LHPolicyEngine`, creates the Theos hook backend, and
asks the generated module registry to install the selected mitigations.

The policy engine initializes in this order:

1. Build a default runtime config from generated build config.
2. Read the current app context and bundle identity.
3. In package builds, reject system bundles, extensions, and non-app processes
   before doing seed or hook work.
4. In package builds, read the generated package policy file and apply the
   default row plus any current-bundle override.
5. If policy is enabled, resolve the configured scope.
6. Resolve the active scoped seed.
7. Serve typed policy values to mitigation hook adapters.

The hook adapters never choose seeds, paths, or profile values directly. Their
job is to install hooks and request values by generated policy value IDs.

## Source of Truth

Several files define the current build and runtime shape:

- `config/build.default.json` selects the target, optional build instance seed,
  and mitigation IDs to compile.
- `config/mitigations.json` catalogs available mitigation modules.
- `config/policy-values.json` catalogs typed values and resolver symbols.
- `scripts/build/generate-mitigation-build.py` validates those catalogs and
  writes generated build products.
- `core/src/LHSeed.c` implements runtime derivation.
- `core/src/LHScope.c` defines scope identity.
- `core/src/LHSeedProvider.m` turns build, package, custom, and app-install
  seed material into the active runtime seed.
- `core/src/LHStateProvider.m` stores and loads opaque state blobs.
- `core/src/LHPolicyEngine.c` coordinates config, scope, seed, state, and value
  lookup.

Generated files under `core/generated/` and `packages/tweak/generated/` are build
products. They are useful to inspect when debugging a concrete build, but the
catalogs and generator are the source of truth.

## Seeds

Loupehole uses four seed concepts. Keeping their roles separate prevents most
confusion in this project.

### Instance Seed

The instance seed is the build-selection seed from `config/build.default.json`.
It is optional and is written as a canonical UUID string:

```json
"instanceSeed": "123e4567-e89b-12d3-a456-426614174000"
```

The parser accepts any valid hyphenated UUID shape. It does not require UUIDv4.
At generation time, the seed is converted to 16 raw bytes and emitted into
`LHGeneratedConfig`.

The instance seed is used for build-time deterministic outputs:

- generated derivation label bytes
- generated package state directory names
- generated package seed and policy file names
- generated package loader basename
- the local or embedded runtime's default practical seed

If a build selection omits `instanceSeed`, generated labels and package names use
an empty build-seed input, and `LHRuntimeConfigDefault` creates a random runtime
seed when the runtime config is initialized. That mode is useful for experiments,
but it is not the reproducible path.

### Root Seed

The root seed is package-install seed material. It exists only for package-mode
runtime behavior.

For a `.deb`, the generated package layout creates a package-owned rootless state
area. During install, `postinst` creates a raw 16-byte root seed file if it does
not already exist. At runtime, `LHSeedProvider` reads that root seed and uses it
as the package practical seed.

This distinction is intentional:

- the instance seed lets the runtime and Settings bundle agree on generated
  package paths before any package state has been read
- the root seed lets an installed package rotate runtime values without
  rebuilding the package

Resetting the root seed changes future package-derived active seeds. Existing
state is not migrated by the current reset path.

### Practical Seed

The practical seed is the intermediate seed that the runtime starts from before
scope is applied.

In local dylib builds, the practical seed is the generated instance seed. In
package builds, the practical seed is normally the root seed read from the
package-owned root seed file. In manual linked/custom seed mode, the configured
custom UUID becomes the practical seed and also becomes the active seed directly.

Hook and resolver code should not care which practical seed path was used. They
receive only the initialized `LHPolicyEngine`.

### Active Scoped Seed

The active scoped seed is the final seed stored in `config->instanceSeed` after
`LHSeedProviderResolveActiveSeed` runs. Despite the field name, at that point it
means "the active seed for this process, policy, and scope", not necessarily the
original build instance seed.

Policy values and state providers use the active scoped seed for runtime
derivation. If two APIs must agree, they should share the same active seed,
scope, and state domain.

## Scopes

A scope tells Loupehole which apps should share a value set. Scope is encoded as
a mode plus an identifier. Runtime derivation includes both.

The current scope modes are:

| Mode | Runtime enum | Meaning |
| --- | --- | --- |
| `0` | `LHScopeModePerAppInstall` | Stable for one app container install, rotates when the app's container marker is removed. |
| `1` | `LHScopeModePerApp` | Stable for the bundle identifier. |
| `2` | `LHScopeModePerVendorGroup` | Stable for the original pre-spoof IDFV when available, otherwise the bundle identifier. |
| `3` | `LHScopeModeManualLinkedGroup` | Uses the configured custom seed as the shared value set. |

`LHScopeInit` accepts identifiers up to 128 bytes. If an identifier is missing,
empty, or too long, it creates a fresh 32-character alphanumeric fallback
identifier. That fallback is intentionally opaque and ephemeral. It should not
be a readable string such as `app`, `vendor`, or a project name.

Manual linked/custom seed scope is special. The current `LHScopeInitManualLinkedGroup`
does not use the bundle identifier as its scope identifier; it initializes a
fixed manual-linked scope. Sharing is controlled by the custom seed itself. The
package policy parser therefore requires a valid custom seed whenever scope mode
`3` is used.

## Runtime Derivation

Runtime derivation lives in `core/src/LHSeed.c`. It is HKDF-SHA256 over a 16-byte
seed with a structured info field.

At a high level:

```text
prk = HMAC-SHA256(zero_salt, seed_bytes)
info = version || label_bytes || scope_mode || scope_identifier || optional_context
output = HKDF-expand(prk, info, requested_length)
```

The info version byte is `1` when there is no extra context and `2` when extra
context is present. Extra context is length-prefixed and currently capped at 128
bytes by `LHSeedDeriveBytesWithContext`.

`LHSeedDeriveOpaqueName` derives 16 bytes and renders them as a 32-character
lowercase hex string. That is the common shape for state blob names, marker
directories, marker records, and package-owned runtime subpaths.

The practical effect is:

- same seed, label, scope, and context gives the same bytes
- changing any one of those inputs rotates the result
- readable purpose strings do not appear beside derived state at runtime

## Derivation Labels

Derivation labels separate one purpose from another. A resolver or state domain
declares labels at file scope:

```c
LH_DERIVATION_LABEL(identifier_for_vendor, state)
LH_DERIVATION_LABEL(identifier_for_vendor, value)
```

The generator scans selected mitigation sources, selected policy resolver
sources, and core sources for those declarations. The canonical label ID is
`domain.name`, such as `identifier_for_vendor.value`.

The generated label bytes are seed-bound at build time:

```text
sha256("lh.derivation-label.v1\0" || instanceSeedBytes || "\0" || labelID)[0..16]
```

The emitted symbols look like:

```c
LHGeneratedDerivationLabel_identifier_for_vendor_value
```

The readable label ID is source-level API. The compiled runtime uses the emitted
16-byte labels. Renaming a label intentionally rotates everything derived from
that label.

## App-Install Marker

The default scope is per app install. It is implemented with a random marker in
the target app's own Application Support area.

The marker path is not readable. `LHSeedProvider` derives an opaque directory
name and opaque record name from:

- the practical seed
- the current app scope
- `seed_provider.app_install_marker_directory`
- `seed_provider.app_install_marker_record`

If the marker record already exists, its 16 raw bytes are reused. If it does not
exist, `LHSeedProvider` generates 16 random bytes and writes them there when the
app container is writable.

The active per-app-install seed is then derived from:

- the practical seed
- the current app scope
- `seed_provider.app_install_seed_value`
- the marker bytes as extra context

Deleting the app container deletes the marker, so a later install gets a new
marker and therefore a new active seed. Normal relaunches keep the same marker
and active seed.

## Generated Package Names

Rootless package builds need names before runtime state is available. The
generator derives those names from the build instance seed and versioned
namespaces:

- package state parent directory
- package seed root directory
- package root seed filename
- package policy filename
- package loader basename

Most generated package names are 32 lowercase hex characters:

```text
sha256(namespace || instanceSeedBytes).hex[0..32]
```

The loader basename uses the same idea but starts with `x` followed by 31 hex
characters, so the installed loader pair is:

```text
/var/jb/Library/MobileSubstrate/DynamicLibraries/<generated>.dylib
/var/jb/Library/MobileSubstrate/DynamicLibraries/<generated>.plist
```

The actual generated names for a build are emitted into
`core/generated/LHGeneratedConfig.{h,c}`, `packages/tweak/generated/mitigation-files.mk`,
and the generated package layout.

## Path Generation and State Storage

State is keyed by `LHStateKey`, which contains a derivation label and a schema
version. The state provider derives an opaque blob name from:

- the active scoped seed
- the state key's label
- the current scope

Local state uses the app's Application Support directory:

```text
<app Application Support>/<opaque-state-blob>
```

Package state uses a package-owned rootless parent directory, then a per-scope
package state root, then the state blob:

```text
/var/jb/var/mobile/Library/Application Support/<generated-parent>/<opaque-package-root>/<opaque-state-blob>
```

The package parent is build-seed-derived. The package root and blob names are
active-seed-and-scope-derived.

State payloads are binary property lists with two short fields:

- `v`: schema version
- `d`: raw payload bytes

The provider only accepts state whose schema version and payload length match
the requested key. If reading or writing fails, the provider can still generate
an embedded value for the current call, but it will not report that value as
locally persisted.

## State Providers

The current runtime enum has three provider kinds:

- `LHStateProviderKindEmbedded`: generate values for the current request without
  writing state.
- `LHStateProviderKindLocal`: persist state in the target app's local
  Application Support directory.
- `LHStateProviderKindPackage`: persist state under the package-owned rootless
  support directory.

The package build compiles the same runtime with
`LH_DEFAULT_STATE_PROVIDER_KIND=LHStateProviderKindPackage`. The local dylib
build defaults to local state. Apps that need to share one value set use manual
linked/custom seed scope; the current tree does not define a separate shared
container provider.

## Policy Files and Policy Values

The word "policy" appears in two related places.

Runtime package policy is the user/configuration layer. The generated package
policy file contains one default row and optional bundle override rows:

```text
D|enabled|scope|moduleFilter|moduleIDs|customSeed
B|bundleID|enabled|scope|moduleFilter|moduleIDs|customSeed
```

`enabled` is `0` or `1`. `scope` is one of the numeric scope modes above.
`moduleFilter` is `0` when all compiled mitigations are available and `1` when
only the listed numeric module IDs should install. `moduleIDs` is a comma
separated list of generated module IDs. `customSeed` is empty except for custom
seed scope, where it must be a valid UUID.

The package starts default-off. When default policy is enabled, the Settings
store writes a broad UIKit app-class loader filter and relies on runtime checks
to reject system apps, extensions, and non-app processes. Per-bundle rows then
override the default at runtime.

Policy values are the typed values hooks request. They are cataloged in
`config/policy-values.json`. Current value kinds are:

- `utf8_string`
- `timeval`
- `time_interval`

The generator emits numeric policy value IDs and a descriptor table. A hook
adapter builds an `LHPolicyValueRequest` with a generated value ID, expected
kind, output buffer, and output length. `LHPolicyEngineCopyValue` validates that
request against the generated descriptor table and dispatches to the resolver
symbol from the catalog.

This lets multiple hook adapters share one resolver and one state domain. For
example, boot-time sysctl hooks and `NSProcessInfo.systemUptime` both request
the `boot_time` policy value.

## Temporal Coherence

Temporal values are generated together when apps can compare them.

`packages/tweak/sources/state_domains/temporal_lifetime/TemporalLifetimeState.c`
owns the first temporal state domain. It declares labels for:

- `temporal_lifetime.state`
- `temporal_lifetime.boot_anchor`
- `temporal_lifetime.volume_before_boot_offset`
- `temporal_lifetime.profile_before_volume_offset`

The generated state contains:

- synthetic boot time
- synthetic volume creation time
- synthetic profile epoch

The generator constructs the ordering directly:

```text
profileEpoch <= volumeCreationTime < bootTime < now
```

Boot time is derived as a plausible age before `now`. Volume creation time is
derived by subtracting another seed-derived offset from boot time. Profile epoch
is derived before volume creation time. The boot-time and volume-creation policy
values read from the same temporal state blob, so they stay coherent across
APIs.

The rule for future temporal surfaces is the same: when two values can be
compared, derive them from a shared state domain rather than independently
generating plausible-looking values.

## Mitigation Concepts

A mitigation is the compiled hook adapter or composite that changes one native
surface. A policy value is the typed value the mitigation asks for. A state
domain is the durable or deterministic state behind one or more policy values.

Those boundaries keep the project scalable:

- Mitigations know selectors, symbols, and fallback behavior.
- Policy values know payload types and resolver functions.
- State domains know how to derive and persist coherent values.
- The generated registry knows which compiled mitigations exist in this build.
- The package policy knows which compiled mitigation IDs should be active for a
  default profile or bundle override.

Mitigations are statically compiled. There is no dynamic module loading in the
target process. The generator validates the selected IDs, emits source lists,
assigns module IDs, and writes registry tables before Theos compiles the dylib.

Composite mitigations are allowed when one user-visible surface needs several
hook adapters. `system.boot_time.composite.synthetic` is the current example: it
installs sysctl-family hooks and an `NSProcessInfo` hook, both backed by the same
`boot_time` policy value.

Fallback behavior should be narrow. If a class or symbol is absent, a mitigation
registers no-op for its module or passes through the affected API path. It should
not shut down unrelated mitigations.

## Creating a Mitigation

Start by deciding whether the new work needs a new policy value, a new hook
adapter for an existing policy value, or both.

### 1. Pick the IDs

Mitigation IDs use:

```text
domain.surface.api_or_method.variant
```

Examples:

```text
identity.idfv.uidevice.scoped_uuid
system.boot_time.composite.synthetic
storage.volume_creation_time.foundation.synthetic
```

Every ID needs a variant segment, even if there is only one variant today.
Policy value IDs are independent and shorter, such as `boot_time` or
`identifier_for_vendor`.

### 2. Add or Reuse a Policy Value

If the mitigation needs a new typed value, add an entry to
`config/policy-values.json`:

```json
{
  "id": "example_value",
  "kind": "utf8_string",
  "resolver": "LHPolicyResolve_example_value",
  "sources": [
    "packages/tweak/sources/example/surface/ExamplePolicyValue.c"
  ]
}
```

Implement the resolver with this signature:

```c
bool LHPolicyResolve_example_value(
    const LHPolicyEngine *engine,
    const LHPolicyValueRequest *request,
    LHPolicyValueResponse *response
);
```

Validate the expected kind and output length before writing. If the value needs
stable state, define an `LHStateKey`, declare derivation labels with
`LH_DERIVATION_LABEL`, and use `LHPolicyEngineLoadOrCreateState`. If it can be
purely deterministic, derive bytes with the policy engine or seed helper.

### 3. Write the Hook Adapter

Place mitigation source under:

```text
packages/tweak/sources/<domain>/<surface>/
```

The install symbol is generated by convention:

```text
LHMitigation_ + id with "." replaced by "_" + _install
```

For `example.surface.api.variant`, define:

```c
bool LHMitigation_example_surface_api_variant_install(
    LHHookBackend *backend,
    LHPolicyEngine *policy
);
```

Inside replacements, request typed values through `LHPolicyEngineCopyValue`
using generated policy value IDs. If a policy lookup fails, pass through to the
original implementation when possible. If no hook path can be installed, return
`LHHookBackendRegisterNoOp` for the generated module ID or return false to a
composite that will decide whether enough components installed.

### 4. Register the Mitigation in the Catalog

Add an entry to `config/mitigations.json`:

```json
{
  "id": "example.surface.api.variant",
  "sources": [
    "packages/tweak/sources/example/surface/ExampleMitigation.m"
  ],
  "policyValues": [
    "example_value"
  ],
  "frameworks": [
    "Foundation"
  ],
  "language": "objc",
  "status": "experimental",
  "optionDoc": "docs/options/example-surface.md"
}
```

Only list fields that are actually needed. Defaults cover `minIos`, dependency
arrays, framework arrays, and max iOS.

### 5. Select and Generate

Add the mitigation ID to `config/build.default.json` or a custom build selection,
then run:

```sh
make generate
```

Inspect generated files when useful:

- `packages/tweak/generated/mitigation-files.mk`
- `core/generated/LHGeneratedMitigationRegistry.{h,c}`
- `core/generated/LHGeneratedPolicyValueRegistry.{h,c}`
- `core/generated/LHGeneratedDerivationLabels.{h,c}`
- `core/generated/LHGeneratedConfig.{h,c}`

Do not hand-maintain those files. Change the catalog, selection, or generator
instead.

### 6. Verify the Behavior

Use focused checks first:

```sh
make seed-check
make seed-provider-check
make state-check
make policy-check
```

Then use the umbrella audit when the change affects compiled runtime behavior:

```sh
make audit
```

For package behavior, build and verify the package:

```sh
make package
```

The best mitigation work leaves three things aligned: the hook adapter, the
policy resolver/state domain, and the generated catalogs. If those disagree,
the bug usually shows up as a missing generated symbol, a policy value lookup
failure, a state blob that rotates unexpectedly, or a package that cannot enable
the intended module.
