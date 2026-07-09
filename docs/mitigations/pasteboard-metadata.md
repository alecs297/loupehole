# `pasteboard.metadata`

The pasteboard metadata option presents an empty general-pasteboard shape and a scoped synthetic change counter through UIKit metadata properties. It covers the silent metadata reads used by the reviewed Pasteboard surface.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `pasteboard.metadata` |
| Implemented mitigation | `pasteboard.metadata.uikit.empty_shape` |
| Policy seeds | `pasteboard_change_count_base` |
| User-facing name | Pasteboard metadata |
| Status | Experimental |
| Surface | Pasteboard |
| Classification | Passive pasteboard metadata read; active hook mitigation |
| Affected APIs | `UIPasteboard.changeCount`, `hasStrings`, `hasURLs`, `hasImages`, `hasColors`, `numberOfItems` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None for these metadata reads |

## References

- Apple UIKit: `UIPasteboard`.
- Apple UIKit: `UIPasteboard.changeCount`, `hasStrings`, `hasURLs`, `hasImages`, `hasColors`, and `numberOfItems`.

## Surface and Relevance

Pasteboard metadata leaks cross-app workflow state without reading content. The global change counter can correlate nearby app launches, while shape booleans and item count reveal whether the clipboard looks like text, URLs, images, colors, or multiple items.

## Mitigation Strategy

The mitigation hooks the UIKit metadata properties on `UIPasteboard` and also attempts to hook the concrete runtime class returned by `UIPasteboard.generalPasteboard`. It returns:

- a scoped synthetic `changeCount` base in `[0, 1024)` plus the observed real pasteboard delta since first read;
- `NO` for `hasStrings`, `hasURLs`, `hasImages`, and `hasColors`;
- `0` for `numberOfItems`.

This creates one coherent strict tuple: no items implies no exposed type booleans. The module does not read or modify pasteboard payloads.

## Derivation and Lifetime

The mitigation declares:

```c
LH_POLICY_SEED(pasteboard_change_count_base)
```

| Item | Value |
| --- | --- |
| Policy seed identifier | `pasteboard_change_count_base` |
| Helper | `LHMitigationDeriveBoundedU64` |
| Value shape | Nonnegative integer starting below `1024`, then advancing with observed pasteboard changes |
| Derivation input | active/practical seed + generated policy seed + active `LHScope` |
| Storage behavior | No mitigation-owned state blob |
| Lifetime | Base is stable until the active seed, policy seed, or scope changes; delta follows same-session real pasteboard counter changes |

## Impact and Tradeoffs

This strict empty shape can hide legitimate paste affordances. Apps may disable paste buttons, edit-menu entries, onboarding shortcuts, share flows, password-manager paste flows, or rich imports even when the real pasteboard contains usable content.

The module does not hook content reads, pattern detection, named pasteboards, AppKit `NSPasteboard`, or pasteboard writes. It observes the original `changeCount` and adds only the nonnegative same-session delta to a scoped base, so the value advances when the platform pasteboard counter advances but does not expose the absolute global counter.

## Validation

Expected observations:

- `UIPasteboard.general.changeCount` returns a scoped synthetic integer that advances after observed pasteboard changes, including when the general pasteboard is a private concrete subclass.
- Shape booleans are false and `numberOfItems` is `0`.
- Content getters are untouched by this mitigation.

Repo-level validation is pending until the catalog entry is merged and the generated registry includes this module.

## Rollback and Pass-Through

Disabling the module restores original metadata. If `UIPasteboard` or all selectors are unavailable, the module registers as a no-op. The replacement never fabricates positive content-shape claims.
