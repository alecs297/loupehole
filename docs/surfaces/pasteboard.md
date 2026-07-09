# Pasteboard

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/PasteboardProvider.swift`

Loupe category: Pasteboard
Loupe tier: passive local pasteboard metadata
Permission required: none for Loupe's collected shape and counter values.
Reading pasteboard contents is outside this page and can be user-visible or
permission-gated on current iOS.
Primary relevance: cross-app activity timing, clipboard content-type shape, and
pasteboard-state coherence without reading actual copied content.

This category covers metadata from the general pasteboard. Loupe does not read
the string, URL, image, color, or binary payload. It reads the global change
counter, coarse content-type booleans, and item count. Those values are lower
entropy than full clipboard contents, but they are silent, cross-app state and
can link nearby app sessions.

## Official Links

- Apple UIKit [`UIPasteboard`](https://developer.apple.com/documentation/uikit/uipasteboard)
- Apple UIKit [`UIPasteboard.general`](https://developer.apple.com/documentation/uikit/uipasteboard/general)
- Apple UIKit [`UIPasteboard.changeCount`](https://developer.apple.com/documentation/uikit/uipasteboard/changecount)
- Apple UIKit [`UIPasteboard.hasStrings`](https://developer.apple.com/documentation/uikit/uipasteboard/hasstrings)
- Apple UIKit [`UIPasteboard.hasURLs`](https://developer.apple.com/documentation/uikit/uipasteboard/hasurls)
- Apple UIKit [`UIPasteboard.hasImages`](https://developer.apple.com/documentation/uikit/uipasteboard/hasimages)
- Apple UIKit [`UIPasteboard.hasColors`](https://developer.apple.com/documentation/uikit/uipasteboard/hascolors)
- Apple UIKit [`UIPasteboard.numberOfItems`](https://developer.apple.com/documentation/uikit/uipasteboard/numberofitems)
- Apple UIKit [`UIPasteboard.detectPatterns(for:inItemSet:completionHandler:)`](https://developer.apple.com/documentation/uikit/uipasteboard/detectpatterns%28for%3Ainitemset%3Acompletionhandler%3A%29-29iwn)
- Apple AppKit [`NSPasteboard`](https://developer.apple.com/documentation/appkit/nspasteboard)
- Apple AppKit [`NSPasteboard.changeCount`](https://developer.apple.com/documentation/appkit/nspasteboard/changecount)
- Apple AppKit [`NSPasteboard.canReadItem(withDataConformingToTypes:)`](https://developer.apple.com/documentation/appkit/nspasteboard/canreaditem%28withdataconformingtotypes%3A%29)
- Apple AppKit [`NSPasteboard.pasteboardItems`](https://developer.apple.com/documentation/appkit/nspasteboard/pasteboarditems)

Loupe's platform shim maps these to `UIPasteboard.general` on iOS and
`NSPasteboard.general` on macOS. Apple also exposes pasteboard pattern-detection
APIs; those are relevant adjacent surfaces, but Loupe's current provider only
uses the simple shape booleans and counter.

## Loupe Signals and Decisions

| Loupe signal | Provider source | Platforms | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- | --- |
| `changeCount` | iOS: `UIPasteboard.general.changeCount`; macOS: `NSPasteboard.general.changeCount` | iOS, macOS | None | Passive global pasteboard counter read | Include | Medium. The exact counter is global pasteboard state and can link nearby app launches, reveal recent copy activity, and detect cross-app pasteboard changes without reading content. |
| `hasStrings` | iOS: `UIPasteboard.general.hasStrings`; macOS: `canReadItem(withDataConformingToTypes: [.string])` | iOS, macOS | None | Passive content-shape read | Include | Low alone, medium in a tuple. Text on the clipboard is common, but the boolean reveals user workflow state without a paste action. |
| `hasURLs` | iOS: `UIPasteboard.general.hasURLs`; macOS: `canReadItem(withDataConformingToTypes: [.URL])` | iOS, macOS | None | Passive content-shape read | Include | Low to medium. URL presence can reveal browsing, sharing, password-manager, or deep-link workflows, especially when joined with timing. |
| `hasImages` | iOS: `UIPasteboard.general.hasImages`; macOS: `canReadItem(withDataConformingToTypes: [.tiff, .png])` | iOS, macOS | None | Passive content-shape read | Include | Low to medium. Image presence can reveal screenshot, photo, design, or sharing activity. |
| `hasColors` | iOS: `UIPasteboard.general.hasColors`; macOS: `canReadItem(withDataConformingToTypes: [.color])` | iOS, macOS | None | Passive content-shape read | Include | Medium when true because color pasteboard entries are less common and may indicate design, drawing, or development workflows. |
| `numberOfItems` | iOS: `UIPasteboard.general.numberOfItems`; macOS: `NSPasteboard.general.pasteboardItems?.count ?? 0` | iOS, macOS | None | Passive item-count read | Include | Low to medium. Counts are coarse, but multi-item pasteboards are less common and constrain the shape booleans. |

Loupe emits only metadata. It does not call content getters such as
`UIPasteboard.string`, `UIPasteboard.url`, `UIPasteboard.image`, or AppKit
payload reads in this provider.

## Permission and Activity Classification

No included Pasteboard signal requires Contacts, Location, Bluetooth, Local
Network, Motion, Photos, Microphone, or another user-granted runtime permission.
Loupe reads local pasteboard metadata from public UIKit/AppKit APIs.

The category is passive in Loupe's one-shot collection path. The app asks the
system for the pasteboard counter and type shape; it does not paste, copy,
clear, mutate, or inspect payload data.

The privacy distinction is important. Pasteboard content reads are a separate
surface and can be user-visible or permission-gated on modern iOS. Loupe's
provider intentionally stays on silent shape properties and counters, which is
why this category remains useful for fingerprinting despite not exposing the
actual clipboard text.

## Fingerprinting Value

`changeCount` is the strongest value in this category. It is not a permanent
identifier, but it is global process-external state. If two apps see the same
counter at close times, or one app observes it move between launches, the value
can help correlate user activity across apps and sessions. A sudden increment
can also indicate a copy event even when the clipboard content is never read.

The shape booleans are coarse, but their tuple is meaningful. A pasteboard that
has both strings and URLs, or images plus multiple items, says more than any
single boolean. `hasColors` is especially notable when true because color
pasteboard items are uncommon in ordinary consumer flows.

`numberOfItems` acts as a consistency check. A multi-item pasteboard with no
shape booleans set may be plausible for custom UTIs, but a synthetic profile
that returns impossible combinations will stand out. The count also affects UI
choices in apps that decide whether to enable paste commands.

The category is most useful as a short-lived behavioral signal. Pasteboard state
can change rapidly as the user copies text, links, screenshots, passwords, or
files. It should not be treated like stable hardware identity, but it can bind
events within a session timeline.

## Mitigation Strategy Ideas

### `pasteboard.metadata`

Hook the metadata surfaces as one tuple:

- `UIPasteboard.changeCount`
- `UIPasteboard.hasStrings`
- `UIPasteboard.hasURLs`
- `UIPasteboard.hasImages`
- `UIPasteboard.hasColors`
- `UIPasteboard.numberOfItems`
- AppKit equivalents on `NSPasteboard.general`

Compatibility default should pass through. Pasteboard metadata affects paste
button enablement, edit menus, drag and drop, shortcut handling, share flows,
and productivity apps. Returning `false` for everything can make an app hide a
valid paste action.

Privacy mode can reduce precision without breaking obvious behavior. For
example, pass through booleans but bucket or virtualize `changeCount`, or freeze
the counter within a short app session while allowing it to advance on modeled
pasteboard events.

Strict mode can present an empty pasteboard shape for apps that only probe the
clipboard, but it should be opt-in because it changes visible paste affordances.
If strict mode reports no items, all type booleans should be false and item
count should be `0`.

UIKit may expose metadata through a private concrete pasteboard subclass, so an
iOS mitigation should cover both `UIPasteboard` and the runtime class returned
by the general pasteboard.

### `pasteboard.change_count`

If handled separately, `changeCount` should be timeline-shaped. A constant `0`
is easy to distinguish from a normal device after the user has used copy/paste,
while an exact real counter leaks global history. Good options are:

- per-session offset: return `realChangeCount - firstSeen + syntheticBase`
- coarse epoch: expose whether the pasteboard changed during the app session
  without exposing the absolute global counter
- strict frozen: stable value for apps that do not need live pasteboard state

If the app writes to the pasteboard, the returned count should move in the
expected direction. A write followed by an unchanged synthetic count can break
app logic and reveal the hook.

### `pasteboard.content_reads`

This is an adjacent future mitigation, not covered by Loupe's current signal
set. Content getters, detected values, and pattern-detection APIs reveal more
than the metadata table. A complete pasteboard policy should decide separately
whether to allow, prompt, redact, or synthesize payload reads.

Do not spoof content metadata independently from content reads. If
`hasURLs == true`, a later allowed URL read should not return no URL unless the
policy intentionally models a race where the pasteboard changed.

## Derivation Considerations

Pasteboard metadata is live state, not a seed-only identity. It should be
derived from current real state, a per-scope timeline model, or explicit policy
rather than from a static random tuple.

The metadata tuple has simple invariants:

```text
numberOfItems == 0 => hasStrings/hasURLs/hasImages/hasColors are usually false
any has* boolean true => numberOfItems should usually be greater than 0
changeCount should be nonnegative and should not rotate randomly per read
changeCount should advance after modeled pasteboard writes
```

The booleans may overlap because one pasteboard item can conform to multiple
types. Avoid deriving them as independent random bits. A small set of common
states is safer: empty, one text item, one URL item, one image item, multiple
items, and uncommon color state.

Purpose labels and salts should remain internal. Returned counters, type
strings, and content-shape decisions must not expose readable Loupehole names,
policy IDs, or derivation labels.

## Impact and Tradeoffs

Pasteboard mitigation is easy to make user-visible. Apps commonly enable paste
buttons, edit menus, onboarding shortcuts, share flows, password-manager flows,
and rich-text imports based on pasteboard shape. Overly strict metadata
redaction can make those features disappear.

Returning fake positive booleans can be just as disruptive. An app may show a
paste action and then fail when content reads are blocked or empty. Positive
metadata should either match allowed content behavior or be used only in a
controlled compatibility profile.

`changeCount` virtualization has lower UI risk than type-shape spoofing, but it
still affects apps that watch pasteboard changes to refresh paste previews or
clipboard-aware controls. If a target app uses pasteboard monitoring for core
workflow, pass-through is the safest default.

The best privacy default is narrow reduction: avoid exposing the absolute
global counter when possible, keep metadata coherent with real or policy-shaped
content access, and avoid one-off random booleans.

## Exclusion Note

Loupe's Pasteboard provider intentionally excludes full content reads and
pattern/value extraction:

- string, URL, image, color, attributed-string, file, and custom UTI payloads
- AppKit `string(forType:)`, `data(forType:)`, property-list reads, and object
  reads
- UIKit detected values and pattern-detection results
- named pasteboards other than the general pasteboard

The collected `has*` booleans and `numberOfItems` are coarse, non-granular
surfaces, but they are included because they are silent and useful as behavioral
state. Full content surfaces should be documented separately if Loupe starts
collecting them.

## Relevance

Pasteboard is a relevant v1 passive-native category because it leaks cross-app
state without a prompt and without reading actual clipboard contents. It is not
a long-term stable identifier, but `changeCount`, item count, and content-shape
booleans are useful for timing correlation and workflow inference.

The priority is medium. Mitigation should focus on coherent metadata reduction
and counter virtualization, while preserving paste workflows unless a strict
policy explicitly accepts the visible tradeoff.
