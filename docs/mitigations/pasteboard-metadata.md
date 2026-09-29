# `pasteboard.metadata`

The pasteboard metadata option presents a scoped synthetic general-pasteboard change counter through UIKit metadata properties. It reduces silent global-counter correlation while preserving pasteboard shape and content access so normal copy and paste workflows continue to work.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `pasteboard.metadata` |
| Implemented mitigation | `pasteboard.metadata.uikit.change_count` |
| Policy seeds | `pasteboard_change_count_base` |
| User-facing name | Pasteboard metadata |
| Status | Experimental |
| Surface | Pasteboard |
| Classification | Passive pasteboard metadata read; active hook mitigation |
| Affected APIs | `UIPasteboard.changeCount` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None for these metadata reads |

## References

- Apple UIKit: `UIPasteboard`.
- Apple UIKit: `UIPasteboard.changeCount`, `hasStrings`, `hasURLs`, `hasImages`, `hasColors`, and `numberOfItems`.

## Surface and Relevance

Pasteboard metadata leaks cross-app workflow state without reading content. The global change counter can correlate nearby app launches and reveal recent copy activity. Shape booleans and item count can also reveal whether the clipboard looks like text, URLs, images, colors, or multiple items, but those values are also used by apps to decide whether paste actions should work.

## Mitigation Strategy

The mitigation hooks only `UIPasteboard.changeCount` and also attempts to hook the concrete runtime class returned by `UIPasteboard.generalPasteboard`. It returns:

- a scoped synthetic `changeCount` base in `[0, 1024)` plus the observed real pasteboard delta since first read.

The module does not hook `hasStrings`, `hasURLs`, `hasImages`, `hasColors`, `numberOfItems`, content getters, pattern detection, writes, or named pasteboards. Pasteboard content access remains governed by the OS privacy model; Loupehole should not block paste operations as a side effect of fingerprinting mitigation because modern iOS already protects apps from silently snooping into pasteboard contents.

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

Earlier strict empty-shape behavior returned no items and no content types. That could hide or break legitimate paste affordances because apps often check pasteboard shape before enabling or performing paste. The current behavior preserves those shape APIs to keep paste buttons, edit-menu entries, onboarding shortcuts, share flows, password-manager paste flows, and rich imports aligned with the real pasteboard.

The module observes the original `changeCount` and adds only the nonnegative same-session delta to a scoped base, so the value advances when the platform pasteboard counter advances but does not expose the absolute global counter. `changeCount` virtualization can still affect apps that watch pasteboard changes to refresh previews or clipboard-aware controls, so per-bundle pass-through remains the compatibility fallback for apps that need exact pasteboard state.

## Validation

Expected observations:

- `UIPasteboard.general.changeCount` returns a scoped synthetic integer that advances after observed pasteboard changes, including when the general pasteboard is a private concrete subclass.
- `hasStrings`, `hasURLs`, `hasImages`, `hasColors`, and `numberOfItems` preserve original behavior.
- Content getters, pattern detection, named pasteboards, and pasteboard writes are untouched by this mitigation.

Repo-level validation should include `make audit` and `make package` after generation.

Manual follow-up validation confirmed that paste operations work again after the empty-shape hooks were removed. Device, OS, loader, and target-app details were not recorded in this handoff note, so this confirms the reported regression path only and does not expand the runtime compatibility matrix.

## Rollback and Pass-Through

Disabling the module restores original `changeCount` behavior. If `UIPasteboard` or the `changeCount` selector is unavailable, the module registers as a no-op. Shape metadata and pasteboard content operations pass through because they are not hooked by this module.
