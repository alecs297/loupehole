# Project values

These values apply to the dylib, the Debian package, generated artifacts, configuration, documentation, tests, and proposed mitigations. They are product constraints, not optional style preferences.

## Privacy without a new fingerprint

The project reduces tracking only when it avoids creating an equally distinctive replacement. A mathematically random value that is rare, inconsistent, or unstable can become a more useful tracking signal than the original value. Cohort-like, plausible, and mutually coherent outcomes are preferable to maximal spoofing.

## Coherence before breadth

A small group of values that agree with each other is more valuable than a large collection of unrelated hooks. New work must identify related surfaces and state relationships before changing an API. Temporal, hardware, locale, storage, account, and network claims often need shared policy or explicit pass-through boundaries.

## Least invasive behavior

A mitigation changes only the documented API paths it owns. It leaves unrelated calls alone, preserves original error and size-query behavior where possible, and falls back to the original implementation when policy state is unavailable or invalid. Failing closed by manufacturing an unrelated value is not a safe default.

## User control without configuration entropy

Users need clear enablement, scope, reset, and per-app controls. They do not need an unbounded collection of arbitrary knobs that creates unique configurations. Build profiles and runtime policy should expose meaningful privacy/compatibility decisions while keeping resulting profiles shared and auditable.

## No telemetry and no hidden network dependency

The runtime and build tooling do not collect use data, send fingerprints, retrieve profile state, or depend on a service to function. Builds should be reproducible from local configuration and source. A new network operation requires an explicit project-level design change and documentation update.

## No project markers in target processes

Injected code must not advertise Loupehole, a build identity, or a user-specific configuration through obvious exports, class names, file paths, log strings, preference keys, bundle IDs, or fallback errors. Naming and storage identities belong to the derivation system where appropriate, not to fixed literals visible to target apps.

## Honest claims and reversible behavior

Documentation names the exact API coverage, limitations, compatibility risks, and unimplemented adjacent surfaces. A mitigation must have a disabled/pass-through story and package uninstall/upgrade behavior that does not damage unrelated app data.

## Open-source reviewability

The project favors small modules, generated registries from declarative catalogs, explicit derivation labels, and testable behavior. Reviewers should be able to answer: what runs, when it runs, what it observes, what it changes, what state it owns, and what happens when it fails.
