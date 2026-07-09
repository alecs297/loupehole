# `webview.script_fingerprint`

The WebView script-fingerprint option reduces exact `WKWebView.evaluateJavaScript` probe shapes used by the reviewed WebView Fingerprint surface. It is a narrow guard for native code that evaluates known browser-fingerprinting snippets inside an in-app WebView.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `webview.script_fingerprint` |
| Implemented mitigation | `webview.script_fingerprint.wkwebview.exact_probe_guard` |
| Policy seeds | None |
| User-facing name | WebView script fingerprint |
| Status | Experimental |
| Surface | WebView Fingerprint |
| Classification | Active local JavaScript evaluation and rendering readback; active hook mitigation |
| Affected APIs | `-[WKWebView evaluateJavaScript:completionHandler:]` for exact observed probe strings |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None |

## References

- Apple WebKit: `WKWebView`.
- Apple WebKit: `evaluateJavaScript(_:completionHandler:)`.
- MDN: `navigator.userAgent`, `navigator.platform`, `navigator.languages`, `Date.getTimezoneOffset`, canvas readback, and WebGL renderer APIs.

## Surface And Relevance

The reviewed provider creates a hidden `WKWebView` and evaluates JavaScript for browser identity, language, time-zone offset, canvas readback, and WebGL renderer strings. These values can contradict or confirm native device, locale, display, graphics, and OS claims.

## Mitigation Strategy

The mitigation hooks `evaluateJavaScript:completionHandler:` and returns reduced values only for exact/simple probe shapes:

- `JSON.stringify(navigator.languages)` returns `["en-US","en"]`.
- `String(new Date().getTimezoneOffset())` returns `0`.
- Canvas readback scripts matching the observed structure return a tiny stable data URL.

`navigator.userAgent`, `navigator.platform`, and WebGL renderer probes pass through to the original WebKit implementation. All other JavaScript evaluation calls also pass through. The module does not inject a user script into arbitrary pages, alter WebKit preferences, or change screen/CPU/RAM/GPU values that the surface page assigns to hardware/display/graphics profiles.

## Derivation And Lifetime

No policy seed is declared because this version uses common cohort constants rather than scoped unique values. That choice avoids turning WebView fingerprints into a new per-app identifier.

## Impact And Tradeoffs

This is intentionally narrow and can be contradicted by native locale, time zone, display, and WebKit feature behavior until those profiles exist. The fixed time-zone and language values are compatibility risks for localized content and scheduling flows.

Canvas reductions only affect scripts evaluated through the hooked native method and matching the observed structure. Page scripts running in normal web content, content worlds, user scripts, network request headers, JavaScriptCore outside WebKit, and lower-level WebGL behavior are not covered.

## Validation

Expected observations:

- Exact `evaluateJavaScript` probes receive reduced string results.
- Unrelated JavaScript evaluation passes through.
- Canvas fingerprint code receives a stable low-detail data URL rather than the real rendered canvas readback.
- User-agent, platform, and WebGL renderer probe code passes through.

Repo-level validation is pending until the catalog entry is merged and the generated registry includes this module.

## Rollback And Pass-Through

Disabling the module restores original WebKit JavaScript evaluation. If `WKWebView` or the selector is unavailable, the module registers as a no-op. If a script does not match the guarded shapes, the replacement calls the original implementation.
