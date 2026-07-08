# Glossary

| Term | Meaning |
| --- | --- |
| Active seed | The seed resolved for the current app context after scope and package/local rules are applied. |
| Build profile | Declarative mitigation selection compiled into an artifact. |
| Derivation label | Generated domain-separation identifier used with seed and scope. |
| Hook adapter | Small API-specific code that derives or loads a documented value and returns it in native form. |
| Mitigation | A bounded change to one documented app-visible surface or API family. |
| Module | Generated-registry unit corresponding to a selected mitigation installer. |
| Opaque name | Derived non-semantic storage identifier, commonly hex-encoded. |
| Package policy | Default/per-bundle runtime configuration read in package mode. |
| Pass-through | Calling or returning the original API behavior when mitigation cannot safely act. |
| Policy engine | Central component that owns runtime config, scope, seed access, state access, and module enablement. |
| Policy seed | Compile-time generated mitigation-owned domain separator declared with `LH_POLICY_SEED`. |
| Scope | Sharing boundary for derived/persisted values. |
| State domain | Versioned persisted data that owns a coherent set of values and invariants. |
| Surface | An app-visible API family capable of exposing fingerprinting-relevant information. |
| Targetable third-party application | Runtime context eligible for package policy and hook setup after system/non-app/extension guards. |
| Variability | Controlled build-time variation that must not change documented semantics or create a user-specific signal. |
