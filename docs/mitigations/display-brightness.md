# `display.brightness`

The brightness option reduces exact `UIScreen` brightness precision while preserving the user's broad brightness state.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `display.brightness` |
| Implemented mitigation | `display.brightness.uiscreen.bucketed` |
| Policy seeds | None; this mitigation rounds the real value. |
| User-facing name | Display brightness |
| Status | Experimental |
| Surface | Display |
| Classification | Passive live user-setting surface; active Objective-C hook mitigation |
| Affected APIs | `UIScreen.brightness` |
| Default behavior | Active when selected and allowed by runtime policy |
| Permission requirement | None |

## Surface And Relevance

Exact brightness can link short app sessions and reveal context such as night use, outdoor use, media playback, or auto-brightness behavior. It is a live setting rather than a hardware constant.

## Mitigation Strategy

The mitigation hooks `-[UIScreen brightness]` and rounds valid values in `[0.0, 1.0]` to tenths. It does not hook brightness setters, screen bounds, scale, native scale, safe area, gamut, frame-rate, WebKit screen values, or display notifications.

## Derivation And Lifetime

No policy seed or state blob is used. The returned value is the current real brightness passed through a deterministic bucket function, so user changes are still reflected at coarse precision.

## Impact And Tradeoffs

Rounding is less invasive than a fixed synthetic brightness, but apps that display precise brightness, react to small brightness changes, or set brightness for scanning, media, reading, or accessibility tasks may notice the bucketed readback.

## Validation

Repository-level validation is pending until catalog integration. Expected observations:

- `UIScreen.brightness` returns values such as `0.0`, `0.1`, ..., `1.0`.
- Invalid or out-of-range original values pass through unchanged.
- Brightness setters and notifications remain untouched.

## Rollback And Pass-Through

If `UIScreen` or the selector is unavailable, the module registers as a no-op. Disabling the module restores the original brightness value.
