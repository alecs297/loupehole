# Core principles for mitigations

## Required properties

### 1. Narrow ownership

A mitigation owns a documented set of API paths and no more. It does not alter nearby methods “just in case,” and it names every adjacent surface left unchanged. This keeps compatibility work bounded and makes evidence meaningful.

### 2. Policy-engine ownership of values

Hook code requests a typed policy value. Value generation, persistence, profile lookup, and derivation live behind the policy engine. The hook must not contain an arbitrary UUID, timestamp, model name, seed, or fallback profile that can diverge from the system model.

### 3. Coherence across observable surfaces

Every replacement value has a stated relationship to the values an app can compare with it. Examples:

- boot time must agree with uptime;
- storage creation time must predate boot time;
- vendor-scoped identifiers must use an appropriate sharing scope;
- a future hardware profile must make model, display, GPU, camera, and WebKit claims agree.

When the project cannot establish coherence, it documents the gap and prefers pass-through over a broad false claim.

### 4. Stable where a stable value is expected

Apps often treat a value’s lifetime as part of its meaning. A per-call random answer is usually detectable and can break ordinary behavior. Stability comes from an explicit state or derivation model, not incidental static storage inside a hook.

### 5. Scoped where linkability matters

A value should be shared only as widely as its chosen scope requires. Per-app-install scope favors unlinkability after reinstall; per-app scope preserves a deterministic app-level identity; vendor-group scope supports legitimate shared behavior where the input is available; manual linked groups provide deliberate linking through a configured seed.

### 6. Safe failure behavior

When installation, policy lookup, state decoding, parsing, availability checks, or cross-value validation fails, the default is original API behavior. If no original exists, the last-resort response must follow the native API’s error semantics instead of inventing an unrelated synthetic answer.

### 7. Minimal observability

A mitigation must not leave a new signature through readable logs, fixed symbols, class names, package paths, settings keys, marker files, or error messages exposed to target apps. Generated or opaque names are used where runtime storage identities must exist.

### 8. Platform-aware coverage

Availability, TCC behavior, entitlement requirements, API deprecation, Swift call paths, Objective-C dispatch, imported symbols, and rootless file paths matter. A page distinguishes “not covered” from “not applicable” and “not observable on this platform.”

### 9. Compatibility as a first-class result

The project does not call a mitigation successful solely because a probe reports a different value. A successful mitigation also preserves expected app behavior, maintains error contracts, and has a documented rollback path.

### 10. Evidence-based claims

A mitigation page identifies the device/OS context, probe or target app, relevant settings, observations, and known exceptions. “Validated” means only the exact observed path has been exercised; it does not silently expand to untested APIs.

## Anti-patterns

The following patterns should be rejected during review:

- one random value per call;
- fixed fake values copied into source;
- unrelated fallback values after a policy failure;
- silent widening from one API to a whole framework;
- module-local persistence that bypasses state providers;
- assumptions that a public wrapper intercepts all C, Swift, or imported call paths;
- selection changes without regenerated build metadata;
- documentation that calls a surface implemented merely because it has a research page;
- changes that add a Loupehole-specific marker to target app processes.
