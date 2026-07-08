# Core Principles For Mitigations

## Required Properties

### 1. Narrow Ownership

A mitigation owns a documented set of API paths and no more. It does not alter nearby methods "just in case," and it names every adjacent surface left unchanged. This keeps compatibility work bounded and makes evidence meaningful.

### 2. Mitigation-Owned Value Logic

Hook code may derive or load values, but the value logic must be documented, scoped, and reusable where needed. Use generated policy seeds and mitigationkit helpers instead of fixed literals, module-local random UUIDs, or hidden fallback profiles.

### 3. Coherence Across Observable Surfaces

Every replacement value has a stated relationship to values an app can compare with it. Examples:

- boot time must agree with uptime;
- storage creation time must predate boot time;
- vendor-scoped identifiers must use an appropriate sharing scope;
- future hardware/model values must agree across model, display, GPU, camera, and WebKit claims.

Coherence is implemented by the relevant mitigations through documented policy seed identifiers and matching computations. It is not a central profile system. When the project cannot establish coherence, it documents the gap and prefers pass-through over a broad false claim.

### 4. Stable Where A Stable Value Is Expected

Apps often treat a value's lifetime as part of its meaning. A per-call random answer is usually detectable and can break ordinary behavior. Stability comes from explicit state or seed derivation, not incidental static storage inside a hook.

### 5. Scoped Where Linkability Matters

A value should be shared only as widely as its chosen scope requires. Install scope favors unlinkability after reinstall; app scope preserves deterministic app-level identity; vendor scope supports legitimate shared behavior where the input is available; manual linked groups provide deliberate linking through a configured seed.

### 6. Safe Failure Behavior

When installation, derivation, state decoding, parsing, availability checks, or cross-value validation fails, the default is original API behavior. If no original exists, the last-resort response must follow the native API's error semantics instead of inventing an unrelated synthetic answer.

### 7. Minimal Observability

A mitigation must not leave a new signature through readable logs, fixed symbols, class names, package paths, settings keys, marker files, or error messages exposed to target apps. Generated or opaque names are used where runtime storage identities must exist.

### 8. Platform-Aware Coverage

Availability, TCC behavior, entitlement requirements, API deprecation, Swift call paths, Objective-C dispatch, imported symbols, and rootless file paths matter. A page distinguishes "not covered" from "not applicable" and "not observable on this platform."

### 9. Compatibility As A First-Class Result

The project does not call a mitigation successful solely because a probe reports a different value. A successful mitigation also preserves expected app behavior, maintains error contracts, and has a documented rollback path.

### 10. Evidence-Based Claims

A mitigation page identifies the device/OS context, probe or target app, relevant settings, observations, and known exceptions. "Validated" means only the exact observed path has been exercised; it does not silently expand to untested APIs.

## Anti-Patterns

Reject these during review:

- one random value per call;
- fixed fake values copied into source;
- policy seeds used without the practical/active seed;
- unrelated fallback values after a derivation or state failure;
- silent widening from one API to a whole framework;
- module-local persistence that bypasses state providers;
- assumptions that a public wrapper intercepts all C, Swift, or imported call paths;
- selection changes without regenerated build metadata;
- documentation that calls a surface implemented merely because it has a research page;
- changes that add a Loupehole-specific marker to target app processes.
