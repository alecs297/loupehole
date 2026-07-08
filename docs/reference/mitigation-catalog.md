# Mitigation catalog contract

## Purpose

The catalog turns mitigation selection into declarative build input. It is the authoritative inventory of modules available to the generator; the selection file defines the subset compiled into an artifact.

## `config/mitigations.json`

At the top level, the current catalog contains:

```json
{
  "schemaVersion": 1,
  "defaults": {
    "minIos": "15.0",
    "maxIos": null,
    "requires": [],
    "conflicts": [],
    "frameworks": [],
    "weakFrameworks": [],
    "libraries": []
  },
  "mitigations": []
}
```

A mitigation entry records a stable string ID and build metadata. Common fields are:

| Field | Meaning |
| --- | --- |
| `id` | Stable dotted mitigation identifier. |
| `sources` | Source files compiled when selected. |
| `policyValues` | Typed policy values required by the module. |
| `language` | Source language metadata. |
| `status` | Documentation/status label; current entries are `experimental`. |
| `optionDoc` | Detailed mitigation page, expected under `docs/mitigations/` after rename. |
| `frameworks`, `weakFrameworks`, `libraries` | Link metadata for selected sources. |
| `minIos`, `maxIos`, `requires`, `conflicts` | Compatibility/dependency constraints when relevant. |

## `config/policy-values.json`

Policy values are separate from mitigations because multiple hook modules can share one coherent value or state domain. Each value has:

| Field | Meaning |
| --- | --- |
| `id` | Stable policy-value identifier. |
| `kind` | Typed response shape expected by hooks. |
| `resolver` | Resolver symbol emitted into generated registry metadata. |
| `sources` | Source files needed to compile the resolver. |

Current value kinds include UTF-8 UUID string, `timeval`, and time interval.

## Current catalog

| Mitigation ID | Policy value | Detailed page | Source entrypoint(s) | Status |
| --- | --- | --- | --- | --- |
| `identity.idfv.uidevice.scoped_uuid` | `identifier_for_vendor` | [IDFV](../mitigations/identity-idfv.md) | `packages/tweak/sources/identity/idfv/IDFVMitigation.m` | Experimental |
| `system.boot_time.composite.synthetic` | `boot_time` | [Boot time](../mitigations/system-boot-time.md) | `packages/tweak/sources/system/boot_time/BootTimeMitigation.m`, sysctl adapter, ProcessInfo adapter | Experimental |
| `storage.volume_creation_time.foundation.synthetic` | `volume_creation_time` | [Volume creation time](../mitigations/storage-volume-time.md) | `packages/tweak/sources/storage/volume_creation_time/VolumeCreationTimeMitigation.m` | Experimental |

The boot-time and volume-creation-time resolvers use `packages/tweak/sources/state_domains/temporal_lifetime/TemporalLifetimeState.c`.

## ID and source naming

Use semantic dotted IDs ordered from surface to mechanism, for example:

```text
<surface>.<subsurface>.<api-family>.<strategy>
```

Source folders should mirror the surface hierarchy without encoding a fixed build identity. A composite mitigation may have one installer plus narrow adapters for each supported API family. A shared state domain lives separately from the adapter folders.

## Validation rules

The generator is expected to reject malformed selections and catalog relationships before Theos runs. A catalog change must be reviewed with its selection, generated output, detailed mitigation page, source additions, link requirements, and test evidence.
