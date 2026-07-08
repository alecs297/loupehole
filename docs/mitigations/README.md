# Mitigation Options

This directory documents user-visible mitigation options. Each page describes
one option surface, the concrete mitigation currently compiled for that surface,
and the behavior an app should observe when the option is enabled, disabled, or
unable to derive or load its documented state.

## Page Structure

Each implemented option page should use the same high-level shape:

1. **Metadata**: option ID, mitigation ID, user-facing name, status, surface,
   active/passive classification, affected APIs, default behavior, and
   permission requirement.
2. **References**: official Apple Developer links where available. Apple open
   source, Darwin headers, BSD manual pages, or upstream platform references are
   acceptable for low-level APIs that Apple documents outside the modern
   Developer Documentation site.
3. **Surface and Relevance**: what the real API exposes and why the value is
   relevant for fingerprinting or cross-session correlation.
4. **Mitigation Strategy**: exactly which APIs are hooked, which policy seeds
   and helpers are used, which calls pass through unchanged, and how the
   mitigation avoids embedding concrete fake values in hook code.
5. **Derivation and Lifetime**: seed/scope inputs, policy seeds, state blob
   ownership, value lifetime, temporal ordering, and dependencies on other
   mitigation values.
6. **Impact and Tradeoffs**: compatibility risks, detection risks, incomplete
   adjacent surfaces, and user-visible behavior.
7. **Validation**: manual Loupe evidence, repo-level checks, and the observable
   results expected from the option.
8. **Rollback and Pass-Through**: behavior when disabled, when hook installation
   fails, when derivation/state loading fails, or when the original API cannot
   be called.
