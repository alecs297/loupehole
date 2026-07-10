# Build System Reference

## Root Makefile Contract

The root Makefile centralizes generation, Theos invocation, signing, artifact copying, package verification, and static checks.

| Variable | Default | Meaning |
| --- | --- | --- |
| `THEOS` | `$THEOS_HOME` or `~/theos` | Theos installation root. |
| `CONFIG` | `release` | Theos configuration; `debug` switches debug-oriented settings. |
| `PYTHON` | `python3` | Generator interpreter. |
| `MITIGATION_CATALOG` | `config/mitigations.json` | Mitigation catalog input. |
| `BUILD_SELECTION` | `config/build.default.json` | Build profile input. |
| `ARTIFACT_DIR` | `dist` | Final copied artifact directory. |
| `LH_ENABLE_VARIABILITY` | `1` | Build variability feature flag. |
| `LH_ENABLE_DIAGNOSTICS` | `0` | Diagnostics feature flag. |
| `LH_DEFAULT_SCOPE_MODE` | `LHScopeModePerAppInstall` | Compile-time default scope used before package policy is applied. Standalone dylib builds should use `LHScopeModePerAppInstall`, `LHScopeModePerApp`, or `LHScopeModePerVendorGroup`; manual linked-group scope needs package policy/custom-seed support. |
| `LH_EMBED_BUILD_SEED` | `1` | Package-runtime seed embedding flag. Standalone dylib builds ignore `0` and always embed the selection build seed; package builds force `0` for the injected runtime dylib. |
| `LH_PREFERENCES_EMBED_BUILD_SEED` | `1` | Embeds the selection build seed in the preferences bundle metadata for the debug pane. |

## Targets

| Target | Result |
| --- | --- |
| `make` / `make all` | Generates inputs, builds the injected runtime, signs the dylib, copies `dist/runtime.dylib`. |
| `make build` | Generates inputs and invokes Theos for the dylib. |
| `make sign` | Builds then signs the Theos dylib. |
| `make copy-artifact` | Copies signed runtime to `dist/runtime.dylib`. |
| `make audit` | Builds/copies the dylib and runs all static verification gates. |
| `make package` | Runs package verification, builds rootless package, copies final `.deb`. |
| `make package-build` | Generates inputs and invokes Theos package build with package state provider, no runtime-dylib build seed, and preference metadata enabled. |
| `make package-verify` | Validates copied `.deb` package layout. |
| `make generate` | Runs `src/scripts/build/generate-mitigation-build.py`. |
| `make clean` | Removes build/package artifacts and `dist`. |

## Generation Inputs And Outputs

| Input | Generated output | Purpose |
| --- | --- | --- |
| `config/mitigations.json` | `src/packaging/theos/generated/mitigation-files.mk` | Selected source and link metadata for Theos. |
| catalog + selection | `src/core/generated/LHGeneratedMitigationRegistry.[hc]` | Numeric module IDs and installers. |
| selected `LH_POLICY_SEED` declarations | `src/core/generated/LHGeneratedPolicySeeds.[hc]` | Compile-time policy seed bytes for selected mitigations. |
| selection / variability inputs | `src/core/generated/LHGeneratedConfig.[hc]` | Compiled seed availability and generated package names. |
| `LH_DERIVATION_LABEL` declarations | `src/core/generated/LHGeneratedDerivationLabels.[hc]` | Stable generated labels for internal derivation domains. |
| catalog / selection | `src/packaging/theos/generated/LHGeneratedPreferenceMetadata.[hc]` | Settings UI module metadata. |
| selection / generated names | `src/packaging/theos/generated/package-layout/` | Package maintainer scripts and rootless state scaffolding. |

Generated files are disposable outputs. Do not hand-edit them.

## Mitigation Catalog Contract

`config/mitigations.json` is declarative build metadata. It lists the mitigation modules that the generator may compile; `config/build.default.json` or another build profile chooses the subset that exists in a dylib or deb.

The catalog keeps only build and linking facts:

| Field | Meaning |
| --- | --- |
| `id` | Stable dotted mitigation identifier. |
| `sources` | Source files compiled when selected. |
| `optionDoc` | Detailed mitigation page under `docs/mitigations/`. |
| `frameworks`, `weakFrameworks`, `libraries` | Link metadata for selected sources. |
| `minIos`, `maxIos`, `requires`, `conflicts` | Compatibility and dependency constraints. |

Do not add centralized value fields, source-language metadata, coherence profiles, cohort profiles, or resolver registry fields to this file. Coherence belongs in mitigation code and the documented policy seed identifiers used by that code.

Use semantic dotted IDs ordered from surface to mechanism:

```text
<surface>.<subsurface>.<api-family>.<strategy>
```

The generator expects the installer symbol to be:

```text
LHMitigation_<id-with-dots-replaced-by-underscores>_install
```

The installer signature is:

```c
bool LHMitigation_example_surface_api_strategy_install(LHHookBackend *backend,
                                                       LHPolicyEngine *policy);
```

The centralized, user-facing list of currently selected mitigations lives in the root `README.md`. Keep detailed per-mitigation behavior in `docs/mitigations/` and avoid duplicating the full current catalog in reference pages.

## Policy Seed Generation

A mitigation declares a compile-time policy seed with:

```c
LH_POLICY_SEED(identifier_for_vendor)
```

The generator scans selected sources, hashes the build seed plus the identifier, and emits generated bytes in `src/core/generated/LHGeneratedPolicySeeds.[hc]`. The identifier is source/generator input; runtime code should use the generated bytes rather than a policy-key string.

Mitigation code then passes both seed classes to mitigationkit helpers:

```c
LHMitigationDeriveUUIDString(&policy->config.buildSeed,
                             &LHGeneratedPolicySeed_identifier_for_vendor,
                             &policy->appContext.scope,
                             output,
                             sizeof(output));
```

Policy seeds must always be combined with the active/practical seed and scope. A policy seed alone is only a domain separator; without the practical seed, values would not rotate when scope or runtime seed material changes.

## Package Build Differences

The standalone dylib build uses the local state provider by default and always embeds the configured build seed. The Theos adapter intentionally ignores `LH_EMBED_BUILD_SEED=0` unless the runtime is being compiled with `LH_STATE_PROVIDER_KIND=LHStateProviderKindPackage`; this prevents a standalone dylib from falling back to a fresh random runtime seed on every process launch.

Standalone dylib scope can be selected at compile time:

```sh
make audit LH_DEFAULT_SCOPE_MODE=LHScopeModePerApp
```

The default remains `LHScopeModePerAppInstall`.

`make package-build` sets the injected runtime dylib to package mode:

```sh
LH_STATE_PROVIDER_KIND=LHStateProviderKindPackage
LH_EMBED_BUILD_SEED=0
```

It also keeps `LH_PREFERENCES_EMBED_BUILD_SEED=1`, so the deb can include the raw selection build seed in the PreferenceLoader bundle debug metadata. That seed must not be compiled into the injected package dylib. Package scope is normally managed by runtime policy from the Settings bundle; `LH_DEFAULT_SCOPE_MODE` is only the pre-policy fallback.

At runtime the package creates or reads its package root seed and then resolves the active scoped seed. The runtime field remains named `buildSeed` because it is the seed value that the injected dylib uses after config and seed-provider resolution.

## Release Artifact Checks

The root `verify` target combines seed, seed-provider, state-provider, mitigation-value, and binary-inspection checks. `package-verify` runs a layout check against the final copied package. A clean build should always regenerate inputs before testing artifact contents.
