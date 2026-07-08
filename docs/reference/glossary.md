# Glossary

| Term | Meaning |
| --- | --- |
| Active seed | The seed resolved for the current app context after scope and package/local rules are applied. |
| Build profile | Declarative mitigation selection compiled into an artifact. |
| Cohort profile | A shared plausible value family; distinct from build selection. |
| Derivation label | Generated domain-separation identifier used with seed and scope. |
| Hook adapter | Small API-specific code that requests a policy value and returns it in native form. |
| Mitigation | A bounded change to one documented app-visible surface or API family. |
| Module | Generated-registry unit corresponding to a selected mitigation installer. |
| Opaque name | Derived non-semantic storage identifier, commonly hex-encoded. |
| Package policy | Default/per-bundle runtime configuration read in package mode. |
| Pass-through | Calling or returning the original API behavior when mitigation cannot safely act. |
| Policy engine | Central component that owns runtime config, scope, seed access, state access, module enablement, and typed values. |
| Policy value | Typed resolver output requested by a hook adapter. |
| Resolver | Function that constructs a policy value using profile, seed, scope, and/or state. |
| Scope | Sharing boundary for derived/persisted values. |
| State domain | Versioned persisted data that owns a coherent set of values and invariants. |
| Surface | An app-visible API family capable of exposing fingerprinting-relevant information. |
| Targetable third-party application | Runtime context eligible for package policy and hook setup after system/non-app/extension guards. |
| Variability | Controlled build-time variation that must not change documented semantics or create a user-specific signal. |
