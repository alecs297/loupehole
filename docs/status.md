# Current Status And Limits

Loupehole is in early development. The runtime, generator, package scaffold, Settings bundle, seed/scope/state machinery, and static verification scripts exist, and the default build selection currently compiles 32 experimental mitigation modules.

This status page is a handoff summary. For exact user-facing positioning, read the root [`README.md`](../README.md). For implemented behavior, read [`docs/mitigations/`](mitigations/). For research coverage and future planning, read [`docs/surfaces/`](surfaces/).

## What Exists

- Standalone arm64 iOS dylib build through the Theos build adapter under `src/packaging/theos/`.
- Rootless Debian package build with generated loader basename, generated filter, maintainer scripts, package policy storage, root seed storage, and PreferenceLoader UI.
- Static build graph driven by `config/mitigations.json` and `config/build.default.json`.
- Runtime support for install, app, vendor, and manual linked group scopes.
- Seed derivation, policy seed generation, opaque package names, state-provider modes, and mitigationkit value helpers.
- Verification targets for seed derivation, seed provider behavior, state provider behavior, mitigation values, package layout, Mach-O summary, string scan, exported symbols, Swift runtime absence, and debug-log absence.

## What Is Experimental

- All default mitigations are experimental and should be evaluated by their linked mitigation pages, not by broad surface names.
- Real-device validation remains required for every iOS version, jailbreak, loader, and target-app combination.
- Package policy and Settings behavior are implemented but still young; lifecycle changes need install, upgrade, disable, and uninstall review.
- The current surface inventory is intentionally larger than the implemented mitigation set.

## What Is Not Claimed

- Loupehole does not claim universal coverage for a surface just because one mitigation in that family exists.
- Loupehole does not bypass DRM, fraud systems, app security controls, or hardware attestation.
- Loupehole does not collect telemetry.
- Permissioned personal-data inventories, location, local network discovery, Photos, contacts, and similar areas remain constrained by compatibility, consent, and detectability concerns.

## Handoff Checks

Before a broad handoff, run:

```sh
make audit
make package
```

When changing catalog entries, policy seed declarations, source paths, generator behavior, or package layout, run `make generate` first and treat generated files as disposable output.
