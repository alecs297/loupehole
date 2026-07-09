# Documentation map

Loupehole documentation is organized by the question being answered rather than by the order in which files were created.

## Start here

- [Project README](../README.md) — purpose, early-stage status, runtime modes, build commands, and currently available mitigations.
- [Current status and limits](status.md) — a precise statement of present coverage and what remains unimplemented.
- [Project values](development/project-values.md) — the enduring constraints that apply to the runtime, package, documentation, and contributor work.

## For development and review

- [Runtime architecture](development/runtime-architecture.md) — initialization path, policy engine, hook backend, generated registry, state, and source-file responsibilities.
- [Package architecture](development/package-architecture.md) — rootless package layout, filter behavior, preference bundle, and package-only policy.
- [Build environment](development/build-environment.md) — dependencies, commands, artifacts, and local verification.
- [Adding a mitigation](development/adding-a-mitigation.md) — the end-to-end implementation and documentation path.
- [Mitigation principles](development/mitigation-principles.md) — acceptance rules for safety, coherence, fallback behavior, and evidence.

## Core concepts

- [Seeds](concepts/seeds.md) — build, package root, practical, active, policy, and state-derived inputs.
- [Build profiles](concepts/build-profiles.md) — static mitigation selection and build variability.
- [Scopes](concepts/scopes.md) — per-install, per-app, vendor-group, and manually linked behavior.
- [Randomization](concepts/randomization.md) — where randomness belongs and where it does not.
- [Derivation](concepts/derivation.md) — derivation labels, policy seeds, state keys, opaque names, and coherence relationships.

## Reference

- [Build system](reference/build-system.md) — inputs, generated outputs, targets, and artifact flow.
- [Validation](reference/validation.md) — static gates, device evidence, regression checks, and release criteria.
- [Glossary](reference/glossary.md) — shared vocabulary.
- [Known limitations](reference/known-limitations.md) — boundaries of the current implementation and threat model.

## Detailed Libraries

Two detailed reference libraries are maintained separately from the system overview:

- `docs/surfaces/` — fingerprinting-surface research inventory.
- `docs/mitigations/` — implemented mitigation behavior library.

They contain the API-specific research and behavior pages. This documentation layer provides the navigation, system model, and contributor standards that keep those pages consistent.
