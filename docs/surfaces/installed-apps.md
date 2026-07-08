# Installed Apps Probe

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/InstalledAppsProvider.swift`

Helper reviewed: `.research/upstream/loupe/code/Loupe/Support/PlatformShim.swift`

Related metadata reviewed: `.research/upstream/loupe/code/Loupe/Info.plist`

Loupe category: Installed Apps Probe
Loupe tier: active local URL-scheme probing
Permission required: none, but iOS requires declared query schemes
Primary relevance: installed-app set, sensitive-interest inference, app
ecosystem correlation, and URL-scheme policy coherence.

This category probes a fixed list of third-party URL schemes. On iOS, Loupe
calls `UIApplication.canOpenURL(_:)` through its platform shim. On macOS, the
same shim uses `NSWorkspace.urlForApplication(toOpen:)` to ask Launch Services
whether an app can open the URL.

## Official and Equivalent Links

- [`UIApplication.canOpenURL(_:)`](https://developer.apple.com/documentation/uikit/uiapplication/canopenurl%28_%3A%29)
- [Launch Services `LSApplicationQueriesSchemes`](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html)
- [Information Property List](https://developer.apple.com/documentation/bundleresources/information-property-list)
- [Defining a custom URL scheme for your app](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- [`NSWorkspace.urlForApplication(toOpen:)`](https://developer.apple.com/documentation/appkit/nsworkspace/urlforapplication%28toopen%3A%29-7qkzf)
- [`NSWorkspace.urlsForApplications(toOpen:)`](https://developer.apple.com/documentation/appkit/nsworkspace/urlsforapplications%28toopen%3A%29-60rkm)

Apple documents `canOpenURL(_:)` and the declaration requirement for iOS. Apps
linked on or after iOS 15 are limited to a maximum of 50 entries in
`LSApplicationQueriesSchemes`; Loupe's probe list contains exactly 50 schemes in
its Info.plist.

## Loupe Signals

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `installed` | For each declared probe, `PlatformApplication.canOpenURL(URL(string: "\(scheme)://")) == true` | None; iOS requires the scheme in `LSApplicationQueriesSchemes` | Active local URL-scheme probing | Include | Very high. The positive installed-app set can reveal social, dating, finance, password-manager, VPN, browser, mobility, work, and media habits. |
| `missing` | Complement of the same probe list where `canOpenURL` returns false | None; iOS requires the scheme in `LSApplicationQueriesSchemes` | Active local URL-scheme probing | Include | Medium to high as part of the vector. Absence of expected apps can be as useful as presence when combined with region, language, account, and behavior. |

Loupe's iOS query schemes are declared in `Info.plist` and match the provider's
probe list:

| App | Scheme |
| --- | --- |
| WhatsApp | `whatsapp` |
| Telegram | `tg` |
| Signal | `sgnl` |
| Facebook | `fb` |
| Messenger | `fb-messenger` |
| Instagram | `instagram` |
| Threads | `barcelona` |
| X | `twitter` |
| TikTok | `tiktok` |
| Snapchat | `snapchat` |
| LinkedIn | `linkedin` |
| Reddit | `reddit` |
| Discord | `discord` |
| Slack | `slack` |
| Zoom | `zoomus` |
| Teams | `msteams` |
| Tesla | `tesla` |
| YouTube | `youtube` |
| Spotify | `spotify` |
| Netflix | `nflx` |
| Google Maps | `comgooglemaps` |
| Waze | `waze` |
| Uber | `uber` |
| Duolingo | `duolingo` |
| Tinder | `tinder` |
| Deliveroo | `deliveroo` |
| Chrome | `googlechrome` |
| Firefox | `firefox` |
| Edge | `microsoft-edge` |
| DuckDuckGo | `ddgQuickLink` |
| Gmail | `googlegmail` |
| Outlook | `ms-outlook` |
| ProtonMail | `protonmail` |
| PayPal | `paypal` |
| 1Password | `onepassword` |
| LastPass | `lastpass` |
| GitHub | `github` |
| Pinterest | `pinterest` |
| Amazon | `com.amazon.mobile.shopping` |
| Bumble | `bumble` |
| Hinge | `hinge` |
| Grindr | `grindr` |
| Venmo | `venmo` |
| Cash App | `squarecash` |
| Lyft | `lyft` |
| DoorDash | `doordash` |
| Twitch | `twitch` |
| Steam | `steammobile` |
| Coinbase | `coinbase` |
| ProtonVPN | `protonvpn` |

## Permission and Activity Classification

No Installed Apps signal requires Contacts, Location, Bluetooth, Local Network,
Motion, Photos, Calendar, Reminders, Music, or another user-granted runtime
permission. There is no TCC prompt.

This category is active local probing. Loupe iterates a curated URL-scheme list
and asks the OS whether each URL can be opened. It does not launch the target
apps, send data to them, query their containers, scan the network, or make an
internet request.

On iOS, the probe is constrained by `LSApplicationQueriesSchemes`: undeclared
third-party schemes are not valid `canOpenURL` probes for modern apps, and the
declared list is visible in the app's Info.plist. On macOS, the equivalent shim
asks Launch Services for an app that can open the URL.

## Fingerprinting Value

The installed-app vector is very high value because it encodes user behavior and
interests. A few positives can reveal work tools, social networks, dating apps,
finance apps, crypto apps, password managers, VPNs, browsers, mobility services,
media subscriptions, and local-market apps.

The value is not only the count. `3 of 50` is much less identifying than
`Signal, ProtonMail, ProtonVPN` or `Tesla, Coinbase, 1Password`. Loupe exposes
both the count and the app names, and its summary inference engine maps detected
apps into behavioral narratives.

The missing set also matters. If a profile has Venmo and Cash App absent but
Deliveroo present, that can say something about region and habits. If a device
has no mainstream social apps but has niche finance/security tools, the absence
pattern narrows the cohort.

Installed-app probes are especially sensitive when joined with account,
locale-region, storefront, telephony, and network signals. App availability and
popularity are regional, so a synthetic profile that claims a storefront or
locale inconsistent with the installed-app set can be detected.

## Mitigation Strategy Ideas

### `apps.url-scheme-probes`

Hook URL-scheme capability checks as a family:

- `UIApplication.canOpenURL(_:)`
- `UIApplication.open(_:options:completionHandler:)` when apps compare open
  behavior with probe results
- `NSWorkspace.urlForApplication(toOpen:)`
- `NSWorkspace.urlsForApplications(toOpen:)`
- app wrappers that cache `canOpenURL` results

Compatibility default should pass through for schemes the app needs for real
features such as authentication handoff, payments, sharing, navigation,
messaging, password-manager integration, or enterprise workflows.

Strict mode can deny third-party scheme probes by returning `false` for selected
schemes or categories. A more compatible strict profile can allow common,
low-sensitivity handlers and hide sensitive apps such as dating, finance,
crypto, password managers, VPN, and niche work tools.

Do not return a random per-read vector. The same app should see stable results
for the same profile until an app-install/profile event changes the state. If a
scheme is reported as present, related open/deep-link behavior should not
immediately contradict that result. If a scheme is reported as absent, the app
may disable a handoff button, so user-visible features can change.

### `apps.probe-list-awareness`

`LSApplicationQueriesSchemes` is part of the querying app's own Info.plist. A
protected process can read its own declared query list through bundle metadata,
so mitigation should not pretend the app cannot know which schemes it declared.
The privacy-sensitive value is the OS answer for each scheme, not the existence
of the declaration list.

Policy can still use the declared list as a warning signal. An app that declares
many social, dating, finance, or browser schemes is likely doing app-install
fingerprinting, and a stricter default may be appropriate.

## Derivation and Coherence Considerations

An installed-app profile should be generated as a stable vector:

```text
declared probe scheme -> visible installed/missing result
installed count == number of true entries
missing list == declared probe list minus installed list
open/deep-link behavior does not contradict visible true entries
region, storefront, language, and app popularity remain plausible
```

Prefer population-shaped app sets over hash-sorted random picks. A rare
combination of apps can be more identifying than the real set. Low-entropy
strict profiles can return no third-party apps or only a small set of common
apps, depending on compatibility needs.

Regional coherence matters. Venmo, Cash App, Deliveroo, Waze, ProtonVPN, Teams,
or local transport/payment apps can imply market, work, or lifestyle context.
The installed-app set should not be generated independently from storefront,
locale, time zone, SIM country, and account-region values.

Sensitive categories should be policy-addressable. A user may want to hide
dating apps, password managers, VPN, crypto, health-adjacent, work, or finance
apps while allowing maps or browsers for functionality.

Purpose labels and synthetic app-set identifiers should remain internal and
seed-bound. Do not expose readable policy names through URL schemes, bundle
metadata, log strings, or returned error objects.

## Impact and Tradeoffs

Hiding installed apps can break legitimate integrations. Apps may use
`canOpenURL` to show "open in app" buttons, start OAuth or SSO handoffs, launch
navigation, share to messaging apps, detect password managers, or route support
flows. Returning `false` can remove those features.

Returning `true` for apps that are not actually installed can also break flows.
The app may show a button or attempt a deep link that fails. If the user sees
the failure, the synthetic profile becomes visible.

Broadly denying all third-party schemes is privacy-preserving but less
compatible. Category-based hiding is more usable, but it can leave enough of
the vector visible to fingerprint. Per-app policy needs to balance app features
against sensitivity of the detected apps.

Because the querying app's Info.plist exposes its intended probe list, App
Review and users can sometimes inspect intent, but the target user still does
not get a runtime prompt. Mitigation is valuable precisely because the probe is
silent at runtime.

## Exclusion Note

No hardware/model constants appear in Loupe's Installed Apps provider.

Do not treat the installed count alone as the mitigation target. The count is a
coarse summary; the granular fingerprint is the full true/false vector for all
declared schemes. Conversely, do not expand this page into private installed-app
enumeration beyond Loupe's declared URL-scheme probes unless another provider
or target app uses such an API.

The provider intentionally probes only its curated 50 schemes. Undeclared iOS
schemes, arbitrary bundle identifiers, and target app containers are out of
scope for this page.

## Relevance

Installed Apps Probe is P0 research because it exposes sensitive personal
interests without a permission prompt. It is also a practical mitigation target:
the API surface is narrow, the probe list is visible, and per-scheme policy can
reduce the most sensitive leakage.

The main implementation challenge is coherence. A protected app should see a
stable, plausible app vector whose `installed`, `missing`, count, open behavior,
region assumptions, and user-visible integrations all agree.
