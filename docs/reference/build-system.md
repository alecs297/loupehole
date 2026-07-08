# Build system reference

## Root Makefile contract

The root Makefile centralizes generation, Theos invocation, signing, artifact copying, package verification, and static checks.

| Variable | Default | Meaning |
| --- | --- | --- |
| `THEOS` | `$THEOS_HOME` or `~/theos` | Theos installation root. |
| `CONFIG` | `release` | Theos configuration; `debug` switches debug-oriented settings. |
| `PYTHON` | `python3` | Generator interpreter. |
| `MITIGATION_CATALOG` | `config/mitigations.json` | Mitigation catalog input. |
| `POLICY_VALUE_CATALOG` | `config/policy-values.json` | Typed policy-value catalog input. |
| `BUILD_SELECTION` | `config/build.default.json` | Build profile input. |
| `ARTIFACT_DIR` | `dist` | Final copied artifact directory. |
| `LH_ENABLE_VARIABILITY` | `1` | Build variability feature flag. |
| `LH_ENABLE_DIAGNOSTICS` | `0` | Diagnostics feature flag. |

## Targets

| Target | Result |
| --- | --- |
| `make` / `make all` | Generates inputs, builds the tweak, signs the dylib, copies `dist/runtime.dylib`. |
| `make build` | Generates inputs and invokes Theos for the dylib. |
| `make sign` | Builds then signs the Theos dylib. |
| `make copy-artifact` | Copies signed runtime to `dist/runtime.dylib`. |
| `make audit` | Builds/copies the dylib and runs all static verification gates. |
| `make package` | Runs package verification, builds rootless package, copies final `.deb`. |
| `make package-build` | Generates inputs and invokes Theos package build with package state provider. |
| `make package-verify` | Validates copied `.deb` package layout. |
| `make generate` | Runs `scripts/build/generate-mitigation-build.py`. |
| `make clean` | Removes build/package artifacts and `dist`. |

## Generation inputs and outputs

| Input | Generated output | Purpose |
| --- | --- | --- |
| `config/mitigations.json` | `packages/tweak/generated/mitigation-files.mk` | Selected source and link metadata for Theos. |
| catalogs + selection | `core/generated/LHGeneratedMitigationRegistry.[hc]` | Numeric module IDs and installers. |
| policy-value catalog + selection | `core/generated/LHGeneratedPolicyValueRegistry.[hc]` | Typed resolver descriptors. |
| selection / variability inputs | `core/generated/LHGeneratedConfig.c` | Compiled build configuration, seed availability, and generated names. |
| derivation declarations | `core/generated/LHGeneratedDerivationLabels.c` | Stable generated labels for internal derivation domains. |
| catalog / selection | package generated metadata | Preference and package build support. |

Exact generated file set may grow. The invariant is unchanged: catalog and selection remain source of truth; generated files remain disposable outputs.

## Package build differences

The standalone dylib build uses the local state provider by default. `make package-build` sets `LH_STATE_PROVIDER_KIND=LHStateProviderKindPackage`, which enables package path/policy behavior and makes package runtime default policy conservative. The shared source set remains the same selected runtime graph.

## Release artifact checks

The root `verify` target combines seed, seed-provider, state-provider, and policy-query checks with binary inspection. `package-verify` runs a layout check against the final copied package. A clean build should always regenerate inputs before testing artifact contents.
