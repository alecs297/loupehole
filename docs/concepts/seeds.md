# Seeds

## Definition

A seed is a 16-byte secret input used to deterministically derive values, opaque storage identities, and state keys within a chosen scope. It is not itself a spoofed value and should not be exposed to target apps.

The seed model exists to make stability and rotation explicit. The same active seed, policy seed, and scope produce the same derived bytes; changing one input produces a separate result. Persisted state can preserve values that need a lifecycle beyond direct derivation.

## Seed Layers

| Layer | Meaning | Typical origin | Purpose |
| --- | --- | --- | --- |
| Build seed | UUID supplied by the build selection. | `config/build.default.json` or another selection file. | Generator input for generated names and compile-time policy seed bytes; standalone dylib starting seed when embedded; package preference debug metadata. |
| Package root seed | Persisted random seed in package mode. | Created once by `LHSeedProvider` when absent. | Stable package-level root without embedding the selection build seed in the deb-mode dylib. |
| Practical seed | Effective parent seed before scoping. | Custom manual-group seed, embedded build seed, or package root seed. | Unifies package and standalone modes. |
| Active seed | Seed used by mitigations after scope resolution. | Deterministic scoped derivation or app-install derivation. | Produces mitigation values and opaque names for the current context. |
| Policy seed | Compile-time generated domain separator declared by a mitigation. | `LH_POLICY_SEED(identifier)`. | Separates semantic value streams. |
| State-derived value | Persisted or generated value associated with active seed and scope. | `LHStateProviderLoadOrCreate`. | Preserves a value that needs stateful lifetime. |

## Build Seed Behavior

The runtime field is named `buildSeed` in both modes:

- In standalone dylib mode, it starts as the configured build seed when embedded.
- In deb/package mode, the raw selection build seed is not embedded in the injected package dylib; after seed-provider resolution the same field holds the package-derived active seed.

This single name avoids a split build/instance vocabulary in the injected dylib. The important boundary is that package mode can carry the build seed in the deb's preference metadata, but not in the injected runtime dylib.

## Why Seeds Rather Than Literal Values

Literal replacement values are difficult to rotate, easy to share accidentally, and can reveal a custom build. Seeds allow the project to derive outputs without storing every output in the binary. They also let a reset or scope change rotate a family of dependent values together.

A seed does not automatically make an output privacy-preserving. A mitigation still needs a plausible value shape and cross-surface coherence. Seeded uniqueness used without a shared-surface policy can still be fingerprintable.

## Derivation Inputs

Mitigation derivation should use:

```text
active/practical seed + generated policy seed + scope mode + scope identifier [+ optional context]
```

The current implementation uses HMAC-SHA256/HKDF-style expansion in `LHSeed.c`. The generator emits policy seeds and internal labels into generated C data so policy-key strings are not scattered through runtime code.

```mermaid
flowchart LR
    Root["Build or package root seed"] --> Practical["Practical seed"]
    Practical --> Scope["Scope inputs"]
    Scope --> Active["Active seed"]
    Policy["Generated policy seed"] --> Value["Mitigation value"]
    Active --> Value
    Active --> Names["Opaque paths / names"]
    Policy --> State["State keys and state blobs"]
```

## Rotation Events

A derived value may rotate when:

- the configured build seed changes;
- package root state is reset;
- a per-app-install marker changes because an app is reinstalled or reset;
- scope mode or scope identifier changes;
- a manual linked-group custom seed changes;
- a policy seed identifier changes;
- a state schema change deliberately invalidates old state.

The expected rotation behavior belongs in each mitigation's documentation. Rotation that is invisible in source but surprising to a user or app is a defect in the model.

## Seed Handling Constraints

- Seeds are configuration/state material, not telemetry.
- A UUID in `build.default.json` is a development selection input, not a production secret distribution mechanism.
- Hook modules do not parse, persist, or generate root seed material directly.
- Policy seeds are domain separators and must be combined with active/practical seed material.
- Persisted seed material and derived state are privacy-sensitive and need package lifecycle review.
