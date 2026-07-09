# Mitigation Options

This directory documents implemented, user-visible mitigation options. Each
page describes one option surface, the concrete mitigation currently compiled
for that surface, and the observable behavior when the option is enabled,
disabled, or unable to install or derive its documented value.

Surface inventory pages under `docs/surfaces/` are research coverage. A page in
this directory should only claim behavior that is implemented by source under
`src/mitigations/`, supported by reusable helpers in `src/mitigationkit/`, and
registered through the static build graph generated from `config/mitigations.json`.

## Page Template

Use this heading order for implemented option pages:

1. `# \`option.id\``
2. `## Metadata`
3. `## References`
4. `## Surface And Relevance`
5. `## Mitigation Strategy`
6. `## Derivation And Lifetime`
7. `## Impact And Tradeoffs`
8. `## Validation`
9. `## Rollback And Pass-Through`

Keep one blank line before and after headings, tables, lists, and fenced code
blocks. Prefer short paragraphs over dense bullets except in validation check
lists or lifetime tables.

## Required Content

The opening paragraph should state what the option does, the real surface it
covers, and whether the surface is passive, active, or both. Avoid broad claims:
a compiled mitigation is not universal coverage for every related API.

`Metadata` should use this table shape:

| Field | Value |
| --- | --- |
| Option ID | `category.option` |
| Implemented mitigation | `category.option.implementation` |
| Policy seeds | `seed_identifier` or `None` with a short reason |
| User-facing name | Name shown to users |
| Status | Experimental, planned, or another catalog status |
| Surface | Human-readable surface family |
| Classification | Surface type and mitigation style |
| Affected APIs | Covered APIs, selectors, functions, constants, or classes |
| Default behavior | How selection/runtime policy enables the module |
| Permission requirement | iOS permission prompt or `None` |

`References` should list official Apple Developer pages where available. Apple
open source, Darwin headers, BSD manual pages, upstream platform references, or
local source paths are acceptable when Apple documents the relevant behavior
outside modern Developer Documentation. If no useful public reference exists,
say that explicitly instead of leaving the section out.

`Surface And Relevance` should describe what the real API exposes and why the
value can support fingerprinting, cross-session linking, account inference, or
timeline coherence checks.

`Mitigation Strategy` should describe exactly which APIs are hooked, which calls
pass through unchanged, and what the replacement returns. Mention generated
installer behavior only when it matters for the page; generated files under
`src/core/generated/` are disposable and should not be hand-edited.

`Derivation And Lifetime` should name every `LH_POLICY_SEED(identifier)`, the
generated seed symbol when useful, helper/state ownership, value shape,
derivation input, lifetime, and dependencies on other mitigation values. Use
source paths under `src/mitigations/`, helper paths under `src/mitigationkit/`,
build scripts under `src/scripts/`, package paths under `src/packaging/theos/`,
and Preferences UI paths under `src/ui/`.

`Impact And Tradeoffs` should call out compatibility risk, detection risk,
adjacent uncovered surfaces, and any user-visible behavior change.

`Validation` should include concrete observations expected from Loupe or another
target app and relevant repo-level checks. For broad handoffs, prefer the normal
verification flow:

```sh
make generate
make seed-check
make seed-provider-check
make state-check
make mitigation-value-check
make build
```

Before release-style handoff, run `make audit` for the standalone dylib and
`make package` for the rootless deb layout.

`Rollback And Pass-Through` should document disabled behavior, failed hook
installation, derivation or state-loading failure, unavailable classes or
selectors, and original-call failure. Preserve pass-through behavior when a hook
cannot safely provide its documented value.
