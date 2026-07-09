# `display.dynamic_type`

The Dynamic Type option buckets content-size categories to lower entropy while preserving a coarse accessibility signal.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `display.dynamic_type` |
| Implemented mitigation | `display.dynamic_type.uikit.bucketed` |
| Policy seeds | None; this mitigation maps platform categories to shared buckets. |
| User-facing name | Dynamic Type preference |
| Status | Experimental |
| Surface | Display |
| Classification | Passive user-preference surface; active Objective-C hook mitigation |
| Affected APIs | `UITraitCollection.preferredContentSizeCategory`, `UIApplication.preferredContentSizeCategory` |
| Default behavior | Active when selected and allowed by runtime policy |
| Permission requirement | None |

## Surface And Relevance

Dynamic Type can reveal reading and accessibility preferences. Rare large or accessibility categories add entropy and affect layout, so full normalization can harm usability.

## Mitigation Strategy

The mitigation hooks the trait and application-wide content-size category getters. Standard categories map to `UIContentSizeCategoryLarge`; accessibility categories map to `UIContentSizeCategoryAccessibilityLarge`. Unknown values pass through.

It does not hook content-size change notifications, accessibility settings, text metrics, bold text, contrast, WebKit media queries, or app-specific cached trait collections.

## Derivation And Lifetime

No policy seed or state blob is used. The output is a shared bucket for the current platform category. The value changes when the underlying category crosses bucket boundaries.

## Impact And Tradeoffs

This module reduces category entropy but can change app layout. It preserves a larger accessibility bucket for accessibility-sized text, yet users who rely on the largest categories may still see smaller text or tighter layouts in protected apps.

## Validation

Repository-level validation is pending until catalog integration. Expected observations:

- Standard content-size categories report the shared Large category.
- Accessibility content-size categories report Accessibility Large.
- Trait and application-wide reads agree.

## Rollback And Pass-Through

If neither UIKit selector is available, the module registers as a no-op. Unknown categories pass through. Disabling the module restores the user's exact Dynamic Type category.
