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
| `LH_EMBED_BUILD_SEED` | `1` | Embeds the selection build seed in the injected runtime dylib; package builds force `0` for that dylib. |
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
| `make generate` | Runs `scripts/build/generate-mitigation-build.py`. |
| `make clean` | Removes build/package artifacts and `dist`. |

## Generation Inputs And Outputs

| Input | Generated output | Purpose |
| --- | --- | --- |
| `config/mitigations.json` | `packaging/theos/generated/mitigation-files.mk` | Selected source and link metadata for Theos. |
| catalog + selection | `core/generated/LHGeneratedMitigationRegistry.[hc]` | Numeric module IDs and installers. |
| selected `LH_POLICY_SEED` declarations | `core/generated/LHGeneratedPolicySeeds.[hc]` | Compile-time policy seed bytes for selected mitigations. |
| selection / variability inputs | `core/generated/LHGeneratedConfig.[hc]` | Compiled seed availability and generated package names. |
| `LH_DERIVATION_LABEL` declarations | `core/generated/LHGeneratedDerivationLabels.[hc]` | Stable generated labels for internal derivation domains. |
| catalog / selection | `packaging/theos/generated/LHGeneratedPreferenceMetadata.[hc]` | Settings UI module metadata. |
| selection / generated names | `packaging/theos/generated/package-layout/` | Package maintainer scripts and rootless state scaffolding. |

Generated files are disposable outputs. Do not hand-edit them.

## Package Build Differences

The standalone dylib build uses the local state provider by default and embeds the configured build seed when `LH_EMBED_BUILD_SEED=1`.

`make package-build` sets the injected runtime dylib to package mode:

```sh
LH_STATE_PROVIDER_KIND=LHStateProviderKindPackage
LH_EMBED_BUILD_SEED=0
```

It also keeps `LH_PREFERENCES_EMBED_BUILD_SEED=1`, so the deb can include the raw selection build seed in the PreferenceLoader bundle debug metadata. That seed must not be compiled into the injected package dylib.

At runtime the package creates or reads its package root seed and then resolves the active scoped seed. The runtime field remains named `buildSeed` because it is the seed value that the injected dylib uses after config and seed-provider resolution.

## Release Artifact Checks

The root `verify` target combines seed, seed-provider, state-provider, mitigation-value, and binary-inspection checks. `package-verify` runs a layout check against the final copied package. A clean build should always regenerate inputs before testing artifact contents.
