# WebView Fingerprint

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/WebViewFingerprintProvider.swift`

Loupe category: WebView Fingerprint
Loupe tier: active local WebView fingerprinting
Permission required: none for the hidden `WKWebView` JavaScript, canvas, and
WebGL probes
Primary relevance: WebKit/browser identity, locale and time-zone leakage,
active canvas/WebGL rendering fingerprints, and coherence with native device,
display, graphics, locale, and OS surfaces.

Loupe creates a hidden `WKWebView`, keeps it alive through a shared host, and
evaluates JavaScript that a normal tracking script could run inside in-app web
content. The provider does not load a remote page or request a runtime
permission, but collection is active because Loupe executes scripts, renders a
canvas, and creates a WebGL context.

## Official Links

- Apple WebKit `WKWebView`: <https://developer.apple.com/documentation/webkit/wkwebview>
- Apple WebKit `WKWebView.evaluateJavaScript(_:completionHandler:)`: <https://developer.apple.com/documentation/webkit/wkwebview/evaluatejavascript%28_%3Acompletionhandler%3A%29>
- MDN `Navigator.userAgent`: <https://developer.mozilla.org/en-US/docs/Web/API/Navigator/userAgent>
- MDN `Navigator.platform`: <https://developer.mozilla.org/en-US/docs/Web/API/Navigator/platform>
- MDN `Navigator.languages`: <https://developer.mozilla.org/en-US/docs/Web/API/Navigator/languages>
- MDN `Navigator.hardwareConcurrency`: <https://developer.mozilla.org/en-US/docs/Web/API/Navigator/hardwareConcurrency>
- MDN `Navigator.deviceMemory`: <https://developer.mozilla.org/en-US/docs/Web/API/Navigator/deviceMemory>
- MDN `Date.prototype.getTimezoneOffset()`: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date/getTimezoneOffset>
- MDN `Screen`: <https://developer.mozilla.org/en-US/docs/Web/API/Screen>
- MDN `Screen.colorDepth`: <https://developer.mozilla.org/en-US/docs/Web/API/Screen/colorDepth>
- MDN `Window.devicePixelRatio`: <https://developer.mozilla.org/en-US/docs/Web/API/Window/devicePixelRatio>
- MDN `CanvasRenderingContext2D`: <https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D>
- MDN `HTMLCanvasElement.toDataURL()`: <https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/toDataURL>
- MDN `WebGLRenderingContext.getExtension()`: <https://developer.mozilla.org/en-US/docs/Web/API/WebGLRenderingContext/getExtension>
- MDN `WEBGL_debug_renderer_info`: <https://developer.mozilla.org/en-US/docs/Web/API/WEBGL_debug_renderer_info>
- Khronos WebGL `WEBGL_debug_renderer_info` extension registry: <https://registry.khronos.org/webgl/extensions/WEBGL_debug_renderer_info/>

Apple documents the native WebKit host and JavaScript evaluation surface. The
JavaScript properties and WebGL extension are documented by MDN, the WHATWG web
platform family, and Khronos where Apple does not provide per-property WebKit
documentation.

## Loupe Signals and Decisions

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `userAgent` | `navigator.userAgent` evaluated in `WKWebView` | None | Active local JS evaluation | Include | High. Exposes WebKit, OS, device class, and browser compatibility identity; must agree with native OS version and any HTTP/WebKit user-agent surfaces. |
| `platform` | `navigator.platform` | None | Active local JS evaluation | Include | Medium. Reveals browser platform/device class and is a coherence check for user agent, hardware profile, and keyboard shortcut/UI behavior. |
| `languages` | `JSON.stringify(navigator.languages)` | None | Active local JS evaluation | Include | High. Ordered preferred languages are a strong entropy source and must agree with native locale, keyboard, and Accept-Language behavior. |
| `hardwareConcurrency` | `String(navigator.hardwareConcurrency)` | None | Active local JS evaluation of a hardware/cohort value | Exclude as standalone WebView mitigation | Medium to high as a CPU/SoC cohort constant. Handle with the hardware profile, not independently in this WebView page. |
| `deviceMemory` | `String(navigator.deviceMemory || 'n/a')` | None | Active local JS evaluation of a hardware/RAM cohort value | Exclude as standalone WebView mitigation | Medium when available. It is already imprecise in browsers and belongs with RAM/device profile coherence. |
| `timezoneOffset` | `String(new Date().getTimezoneOffset())` | None | Active local JS evaluation of local time-zone state | Include | Medium to high. Offset links to time zone, travel, locale, and DST state, though it is less specific than an IANA time-zone identifier. |
| `screen` | JSON of `screen.width`, `screen.height`, `window.devicePixelRatio`, and `screen.colorDepth` | None | Active local JS evaluation of display metrics | Exclude | High as a screen/model classifier, but excluded by rule from first-class WebView mitigation. Keep it in the coherent display/hardware profile. |
| `canvasHash` | Render a 200x60 2D canvas, call `toDataURL()`, then SHA-256 hash the data URL and truncate to 32 hex chars | None | Active rendering probe | Include | High. Captures WebKit, font/text rasterization, GPU, color pipeline, and graphics-driver differences without a prompt. |
| `webgl` | Create WebGL or experimental WebGL context, query `WEBGL_debug_renderer_info` when available, otherwise `VENDOR` and `RENDERER` | None | Active WebGL/GPU probe | Include as a WebKit/graphics tuple | High. Renderer/vendor strings are hardware and driver identifiers. Mitigate only with graphics and Metal coherence. |

Loupe's `canvasHash` is not the raw canvas data. It is a stable digest of the
rendered data URL for the fixed drawing script. That makes the observed value
compact but still sensitive to text, GPU, WebKit, font, color, and OS changes.

## Permission and Activity Classification

No Loupe WebView Fingerprint signal requires Contacts, Location, Bluetooth,
Motion, Photos, Local Network, Camera, Microphone, or another user-granted
runtime permission. A normal app can create a `WKWebView` and evaluate scripts
in its own web view without a TCC prompt.

This category is active local collection. Loupe is not merely reading cached
native state: it executes JavaScript, asks WebKit for browser properties,
renders a canvas, serializes the canvas, and initializes a WebGL context. It is
still local collection because the provider does not navigate to a remote URL,
send network traffic, scan a LAN, or ask another app for data.

The practical risk is that in-app web content and native code can observe the
same browser-shaped tuple. A native mitigation that ignores WebKit will be easy
to detect once a target app opens a web view.

## Fingerprinting Value

`userAgent`, `platform`, and `languages` are the highest-value non-rendering
signals. The user agent binds WebKit and OS version claims to a device class.
The platform string is lower-cardinality, but it is a useful contradiction
detector. The ordered language list can be highly identifying for multilingual
users and must line up with native locale APIs and server-observed request
headers.

`timezoneOffset` is less specific than `TimeZone.current.identifier`, but it is
still useful because it is web-visible and time-dependent. It can reveal travel,
daylight-saving changes, or contradictions between native region, IP geolocation,
server timestamps, and WebKit JavaScript behavior.

`canvasHash` is high value because it compresses many subtle rendering choices
into one repeatable value. The fixed Loupe drawing touches text, fills, stroke
geometry, alpha blending, arc rendering, font fallback, antialiasing, and
serialization. Even if a single iOS cohort shares the same hash, it becomes a
strong consistency check against OS, WebKit, Metal, display color, and font
surfaces.

`webgl` is high value when a renderer string is exposed. It can reveal Apple GPU
generation, simulator versus device, driver masking behavior, and WebKit privacy
choices. It should be treated as the browser-visible sibling of Metal and GPU
profile data, not as an independent random string.

The excluded screen and hardware constants are still strong fingerprint values.
They are excluded here to avoid fragmented spoofing. Screen width, height, DPR,
color depth, CPU count, and memory cohort need to come from the same selected
hardware/display profile as native display, system info, Metal, model, and OS
surfaces.

## Mitigation Strategy Ideas

### `webview.user_agent_profile`

Cover the browser identity tuple together:

- `navigator.userAgent`
- `navigator.platform`
- WebKit custom user-agent properties if a target app sets or reads them
- HTTP User-Agent headers emitted by WebKit loads where practical
- native OS/device values that the user agent implies

Compatibility default should pass through until a complete OS and device-class
profile exists. Strict mode can return a common real Safari/WebKit user-agent
shape, but only if the rest of the process reports the same OS version, device
class, WebKit behavior, and feature availability. Do not synthesize a user agent
for an OS whose WebKit APIs or JavaScript features are not present.

### `webview.languages`

Normalize `navigator.languages` with the native locale profile. The first
language should match the primary locale choice, and the ordered list should
stay coherent with native preferred languages, keyboard languages, date/number
formatting, and any WebKit request headers.

Compatibility default should usually pass through. Strict mode can reduce the
list to a short common profile, but it should not seed-generate rare language
stacks. A synthetic list such as three uncommon languages in an unusual order
can be more identifying than the original value.

### `webview.time_zone_offset`

Hook JavaScript date/time-zone exposure together with native time-zone APIs and
WebKit `Intl` surfaces when coverage expands. Returning only a spoofed
`getTimezoneOffset()` while native time zone, formatted dates, server timestamps,
or JavaScript `Intl.DateTimeFormat().resolvedOptions().timeZone` expose another
location creates an obvious mismatch.

Strict mode should choose the offset from a selected IANA time-zone profile and
respect daylight-saving rules at the evaluated date. Do not use a fixed offset
without an associated time-zone profile.

### `webview.canvas`

For compatibility, pass through by default. Canvas output is used for legitimate
charts, games, signatures, maps, editors, QR/barcode generation, and image
processing. Breaking readback or adding heavy noise can cause visible defects.

Strict behavior can use one of three patterns:

- block or neuter readback for known fingerprint-only contexts
- return a cohort-stable rendered result for the exact fingerprint script shape
- add minimal deterministic perturbation derived from the active graphics
  profile, not from a unique per-app random value

Any perturbation must be stable within a profile epoch. Per-read canvas noise is
easy to detect by repeated sampling. Seed-derived high-precision noise can also
become a new identifier, so prefer cohort values or coarse reductions.

### `webview.webgl_renderer`

Treat WebGL renderer exposure as a graphics profile surface. Coverage should
include:

- `getExtension('WEBGL_debug_renderer_info')`
- `UNMASKED_VENDOR_WEBGL` and `UNMASKED_RENDERER_WEBGL`
- fallback `VENDOR` and `RENDERER`
- WebGL support/absence, context creation errors, and extension availability

Compatibility default should pass through for games, 3D apps, video tools,
creative apps, maps, and any site that depends on WebGL. Strict mode can hide
the debug extension, return masked generic strings, or return a renderer string
from a real coherent Apple GPU profile. It must agree with Metal device name,
GPU family support, raytracing capability, canvas hash behavior, display color,
and OS/WebKit version.

## Derivation and Coherence Considerations

WebView values should be derived from a small number of shared profiles, not
from independent per-signal hashes. The relevant profile domains are:

```text
OS/WebKit profile: user agent, WebKit feature behavior, JavaScript support
Locale profile: languages, time zone, date formatting, Accept-Language
Hardware/display profile: screen metrics, DPR, color depth, CPU/RAM cohorts
Graphics profile: canvas hash, WebGL renderer, Metal/GPU capabilities
```

The user agent should be cohort static. Many protected users can share the same
real OS/WebKit string. It should not include seed-derived unique suffixes,
readable Loupehole labels, or impossible version combinations.

Languages and time zone should come from the locale profile and should remain
stable through a profile epoch. Travel or locale changes should be modeled as
coherent profile events, not as independent changes to JavaScript values.

Canvas and WebGL values need temporal stability and cross-surface agreement. If
the Metal profile says one GPU generation but WebGL and canvas behave like
another, the synthetic profile is detectable. If canvas changes every call while
Metal and WebGL stay fixed, the noise is detectable. Prefer a cohort-stable
graphics profile or pass-through.

Excluded hardware constants remain dependencies. If another profile selects a
device class, then `hardwareConcurrency`, `deviceMemory`, WebKit screen metrics,
native screen metrics, Metal families, model identifiers, and OS version must
all describe a real plausible device.

## Impact and Tradeoffs

User-agent spoofing can break feature detection, compatibility workarounds,
server-side routing, analytics, login risk scoring, and support diagnostics.
Partial spoofing is worse than pass-through because WebKit features can reveal
the real engine and OS.

Language and time-zone spoofing can change localization, content negotiation,
date math, scheduling, fraud checks, and user-visible formatting. These values
should follow the broader locale profile and stay compatibility-first by
default.

Canvas mitigation has real app risk. Canvas readback is used for legitimate
rendering workflows, not only fingerprinting. Blocking, noisy rendering, or
script-specific special cases can break apps or become detectable if applied
too broadly.

WebGL mitigation can break games, maps, 3D previews, GPU-accelerated UI, video
effects, and web compatibility checks. Hiding the debug extension is safer than
inventing an impossible renderer, but even extension absence must match the
selected WebKit/privacy profile.

Leaving WebView screen size and CPU/RAM constants out of this page narrows the
scope and prevents one-off spoofing. It does not make those values harmless;
they remain high-priority coherence constraints for a complete hardware profile.

## Exclusion Note

Per user rule and the fingerprint inventory inclusion rule, this page excludes
the following from first-class WebView mitigation ownership:

- `screen.width`
- `screen.height`
- `window.devicePixelRatio`
- `screen.colorDepth`
- `navigator.hardwareConcurrency`
- `navigator.deviceMemory`

Reason: these values are screen-size, display, CPU, RAM, or other mostly
hardware-constant cohort signals. They should be handled by a coherent
hardware/display/device profile that also aligns native display metrics,
`ProcessInfo` CPU/RAM values, Metal/GPU data, model identifiers, camera lineup,
and WebKit-exposed hardware claims.

`webgl` is hardware-derived too, but Loupe collects it through an active WebGL
renderer path and it is a core web fingerprinting surface. This page keeps it
visible as an included WebKit/graphics tuple while requiring Metal and hardware
coherence for any mitigation.

## Relevance

WebView Fingerprint is highly relevant for v1 planning because many native apps
embed WebKit and can compare native values with browser-visible values in the
same process. A native-only mitigation set can look coherent until a hidden or
visible web view asks for `navigator`, canvas, WebGL, screen, and JavaScript
date state.

The most actionable included surfaces are `userAgent`, `languages`,
`timezoneOffset`, `canvasHash`, and `webgl`. The excluded WebKit hardware and
screen values should feed the future hardware/display profile rather than
becoming standalone spoofing tasks.
