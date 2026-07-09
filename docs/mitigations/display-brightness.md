# `display.brightness`

The brightness option maps `UIScreen` brightness through a scoped smooth curve while preserving the user's broad brightness state.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `display.brightness` |
| Implemented mitigation | `display.brightness.uiscreen.curved` |
| Policy seeds | `display_brightness_curve` |
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

The mitigation hooks `-[UIScreen brightness]` and maps valid values in `[0.0, 1.0]` through a scoped nonlinear curve selected from a small finite family by `LH_POLICY_SEED(display_brightness_curve)`. Nearby original values produce nearby reported values, but the reported value is not a hard bucket or exact 1:1 mirror. It does not hook brightness setters, screen bounds, scale, native scale, safe area, gamut, frame-rate, WebKit screen values, or display notifications.

## Derivation And Lifetime

No state blob is used. The returned value is the current real brightness passed through a deterministic scoped curve, so user changes are still reflected continuously.

## Impact And Tradeoffs

The curve is less invasive than a fixed synthetic brightness and avoids obvious bucket edges. Apps that display precise brightness, react to small brightness changes, or set brightness for scanning, media, reading, or accessibility tasks may still notice that readback differs from the exact platform value.

## Validation

Repository-level validation is pending until catalog integration. Expected observations:

- `UIScreen.brightness` follows real brightness changes through the scoped nonlinear curve.
- Invalid or out-of-range original values pass through unchanged.
- Brightness setters and notifications remain untouched.

## Rollback And Pass-Through

If `UIScreen` or the selector is unavailable, the module registers as a no-op. Disabling the module restores the original brightness value.
