# Local Network Fingerprint Category

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/LocalNetworkProvider.swift`

Loupe category: Local Network
Loupe tier: active permissioned Bonjour/local service probing
Permission required: Local Network authorization on platforms that enforce
local network privacy, plus `NSLocalNetworkUsageDescription` and declared
`NSBonjourServices` for the service types the app browses
Primary relevance: nearby device/service inventory, household or workplace
context, accessory names, smart-home/media/printer/server presence, and
coherence with network, Bluetooth, location, and account surfaces.

Loupe starts short `NWBrowser` Bonjour browses across a fixed list of common
service types. Each browse runs for 1.2 seconds with `includePeerToPeer = true`.
When services are discovered, Loupe emits one signal per service type with the
sorted discovered service instance names joined into the value.

The provider comment says it reports counts without revealing names, but the
reviewed code currently emits service names. That makes this category more
sensitive than a count-only inventory.

## Official and Equivalent Links

- Apple Network `NWBrowser`: <https://developer.apple.com/documentation/network/nwbrowser>
- Apple Network `NWBrowser.Descriptor.bonjour(type:domain:)`: <https://developer.apple.com/documentation/network/nwbrowser/descriptor-swift.enum/bonjour%28type%3Adomain%3A%29>
- Apple Network `NWBrowser.Result`: <https://developer.apple.com/documentation/network/nwbrowser/result>
- Apple Network `NWParameters.includePeerToPeer`: <https://developer.apple.com/documentation/Network/NWParameters/includePeerToPeer>
- Apple Info.plist `NSLocalNetworkUsageDescription`: <https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription>
- Apple Info.plist `NSBonjourServices`: <https://developer.apple.com/documentation/bundleresources/information-property-list/nsbonjourservices>
- Apple technote TN3179, local network privacy: <https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy>
- Apple Bonjour overview: <https://developer.apple.com/bonjour/>
- Apple archived Bonjour concepts: <https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/NetServices/Articles/about.html>
- IETF RFC 6763, DNS-Based Service Discovery: <https://datatracker.ietf.org/doc/html/rfc6763>
- DNS-SD service type registry notes: <https://www.dns-sd.org/servicetypes.html>
- IANA service name and port number registry: <https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml>

Apple documents the Network.framework browse API, Bonjour privacy declaration
keys, and local network privacy model. DNS-SD, IETF, and IANA references cover
the service type naming conventions underneath Bonjour.

## Loupe Signals and Decisions

Loupe emits signal IDs in the form `svc.<service-type>` for each service type
that returns at least one service instance name. Empty result sets do not emit a
signal.

| Loupe signal family | Service types | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| Apple ecosystem services | `_airplay._tcp`, `_raop._tcp`, `_companion-link._tcp`, `_homekit._tcp`, `_airdrop._tcp`, `_apple-mobdev2._tcp`, `_remotepairing._tcp` | Local Network | Active Bonjour browse | Include | High. Reveals Apple TVs, AirPlay speakers, HomeKit homes, nearby Apple devices, pairing/debug surfaces, and potentially personalized room/device names. |
| Streaming and media services | `_googlecast._tcp`, `_spotify-connect._tcp`, `_sonos._tcp`, `_roku-rcp._tcp`, `_daap._tcp`, `_dpap._tcp` | Local Network | Active Bonjour browse | Include | High. Reveals household media devices, speakers, receivers, music libraries, and living-space context. |
| Printer and scanner services | `_printer._tcp`, `_ipp._tcp`, `_ipps._tcp`, `_pdl-datastream._tcp`, `_scanner._tcp`, `_uscan._tcp` | Local Network | Active Bonjour browse | Include | Medium to high. Printers and scanners often include model, owner, office, department, or room names. |
| Web and file-sharing services | `_http._tcp`, `_https._tcp`, `_smb._tcp`, `_afpovertcp._tcp`, `_nfs._tcp`, `_ftp._tcp`, `_sftp-ssh._tcp`, `_webdav._tcp`, `_webdavs._tcp` | Local Network | Active Bonjour browse | Include | High. Reveals NAS devices, Macs, dev servers, routers, cameras, home labs, and file-sharing infrastructure. |
| Remote access and management services | `_ssh._tcp`, `_rfb._tcp`, `_rdp._tcp`, `_net-assistant._udp` | Local Network | Active Bonjour browse | Include | High. Reveals administration, remote desktop, VNC, SSH, and support surfaces that can identify a workplace or technical user. |
| Smart home and IoT services | `_hap._tcp`, `_matter._tcp`, `_hue._tcp`, `_mqtt._tcp`, `_coap._udp`, `_wemo._tcp` | Local Network | Active Bonjour browse | Include | High. Reveals smart-home brands, hubs, lighting, automation, brokers, and household device topology. |
| Communication services | `_presence._tcp`, `_sip._tcp`, `_h323._tcp` | Local Network | Active Bonjour browse | Include | Medium to high. Reveals chat/presence, VoIP, and conferencing infrastructure. |
| Development and diagnostics services | `_device-info._tcp`, `_sleep-proxy._udp`, `_dns-sd._udp` | Local Network | Active Bonjour browse | Include | Medium to high. Reveals diagnostic, infrastructure, and Bonjour/DNS-SD environment shape. |

The emitted value is the joined list of discovered service instance names for
that type. Service names can include human-readable room names, owner names,
printer names, hostnames, model names, office labels, media-room labels, or
debug identifiers.

## Permission and Activity Classification

This category is active local network collection. Loupe starts `NWBrowser`
instances that browse Bonjour service types. That is a local discovery probe,
not a passive read of cached state.

On platforms that enforce Local Network privacy, Bonjour operations require
Local Network access. Apps should include a user-facing
`NSLocalNetworkUsageDescription` string and list browsed Bonjour service types
in `NSBonjourServices`. Without authorization or the right declarations, browses
can fail, return no usable results, or trigger the system privacy flow depending
on platform and OS behavior.

Loupe does not currently use the injected `PermissionCenter` inside this
provider before scanning. It simply attempts the browses and reports any
results. That means denial, missing plist declarations, timeout, or an empty LAN
can all collapse into no emitted service signals unless the browser state is
observed elsewhere.

`includePeerToPeer = true` broadens the browse parameters to include peer-to-peer
link technologies where the platform supports them. That can expose nearby
Apple ecosystem paths beyond ordinary infrastructure Wi-Fi.

## Fingerprinting Value

Local-network service discovery is high-value because it describes the user's
physical environment. A service inventory can distinguish a home, office,
school, hotel, lab, car, studio, smart home, or enterprise network before the
app receives Location permission.

Service instance names are especially sensitive. They often contain names like
rooms, owners, organizations, device models, hostnames, printer locations,
speaker names, NAS names, development machines, and smart-home bridge labels.
Even when names are generic, the tuple of service types and counts can be rare.

Apple ecosystem and media services can reveal household devices and account
ecosystems. Printer, scanner, file-sharing, and remote-access services can
reveal workplace or technical context. Smart-home services can reveal brands and
home topology. Development and diagnostic services can identify a developer,
admin, or lab environment.

The 1.2 second duration means results are a snapshot, not a complete network
inventory. Still, repeated app launches can accumulate a durable picture of
which devices are usually nearby and when they appear or disappear.

Local-network results are also coherence checks. A profile that claims one
region, time zone, network interface, VPN posture, Bluetooth neighborhood, or
location context while Bonjour reveals a contradictory LAN can be detected.

## Mitigation Strategy Ideas

### `local_network.permission_boundary`

Do not bypass or fake the system permission model. If the app lacks Local
Network authorization, the safest mitigation is to preserve denied or empty
behavior. A hook should not expose synthetic nearby devices before the system
permission state says local network access is available.

If a target app only probes for fingerprinting, strict policy can force empty
results or browser failure behavior that resembles denied/unavailable access.
Keep errors, timing, and absence of results consistent across all service types
so the denial shape does not become a new fingerprint.

### `local_network.service_inventory`

When Local Network access is granted and mitigation is enabled, treat all
service types as one environment profile. Coverage should include:

- `NWBrowser` Bonjour descriptors
- browse result endpoint names and metadata
- browser state transitions and failure timing where observable
- legacy NetService/DNSServiceBrowse paths if future target apps use them
- peer-to-peer browse behavior when `includePeerToPeer` is true

Compatibility default should pass through for apps that legitimately discover
printers, speakers, TVs, smart-home devices, file servers, local dev services,
or enterprise resources. Returning empty results can break setup flows,
printing, casting, smart-home control, diagnostics, file browsing, and pairing.

Strict mode can reduce precision by returning counts only, dropping names,
filtering rare service types, or returning an empty common baseline. Prefer
removing sensitive detail over inventing a large fake household.

### `local_network.service_names`

If names must be returned, replace personalized names with generic,
platform-shaped names from the selected LAN profile. Examples include generic
printer, speaker, TV, bridge, or file-server labels that do not encode the real
owner or location.

Do not derive unique service names directly from the user seed. A stable fake
`Alex-TV-7F3A` style value can become a stronger cross-app identifier than the
real network. Use a tiny common set or a per-network epoch if synthetic names
are necessary.

Name replacement must be stable within one browse session and across related
APIs. If the same service appears through Bonjour, local hostname resolution,
network interface state, Bluetooth, or app-specific pairing APIs, the names and
counts should not contradict each other.

### `local_network.service_type_filter`

Filtering can reduce entropy by suppressing high-sensitivity categories such as
remote management, file sharing, smart-home, or personal media services. The
filter should operate at the browse result layer and maintain plausible browser
state.

Be careful with setup apps. A printer app that cannot see `_ipp._tcp`, a TV app
that cannot see `_airplay._tcp` or `_googlecast._tcp`, or a smart-home app that
cannot see `_hap._tcp` or `_matter._tcp` may become unusable. Target policy
should pass through for apps whose core function is local discovery.

## Derivation and Coherence Considerations

Local-network values should be modeled as an environment profile, not as
independent per-service random results. A coherent profile includes:

```text
permission state and plist declaration behavior
network path and interface state
local IP/subnet/VPN/proxy posture
Bonjour service types present
service instance names and counts
peer-to-peer availability
Bluetooth neighborhood and smart-home/media context
location/region/time-zone plausibility where permissioned values exist
```

Synthetic service inventories should be low entropy. Empty results, count-only
results, or a few common generic services are safer than a detailed fake home
lab. If a profile exposes a smart-home bridge, speaker, printer, or file server,
related app behavior should remain plausible.

Rotation should follow network context, not every read. If the device joins a
new Wi-Fi network or the network epoch changes, a new local-network profile may
be selected. During one app session and network epoch, results should remain
stable enough that repeated browses do not reveal artificial churn.

Do not expose Loupehole internals in service names, TXT-like metadata, salts, or
timing patterns. Returned names must look like normal Bonjour instance names,
not mitigation IDs or seed labels.

If strict mode hides local services while the app can still connect to them
through other channels, server-side or device-side behavior may contradict the
local browse results. Prefer pass-through for apps that actually use the
services they discover.

## Impact and Tradeoffs

Local-network mitigation can directly break user workflows. Printers, scanners,
TV casting, AirPlay, Sonos, Roku, HomeKit, Matter, Hue, Wemo, file sharing, NAS
browsing, SSH/VNC/RDP tools, local web setup pages, and development tools all
depend on discovery.

Returning empty results protects privacy but can make setup and control apps
look broken. Returning generic synthetic results may be worse if the app tries
to connect to devices that do not exist.

Name redaction has lower functional risk than full suppression, but it can still
break user selection flows where people choose a room, speaker, printer, or
server by its visible name.

Permission coherence is important. If the system prompt was denied but hooks
return services anyway, the app sees an impossible state. If permission was
granted but all service types fail instantly with identical synthetic timing,
that can also be detectable.

Local Network is a physical-context signal. Hiding it may conflict with Location
permission results, IP geolocation, Wi-Fi/cellular path state, Bluetooth
devices, account ecosystems, and user-visible nearby device behavior.

## Exclusion Note

This page does not exclude any of the reviewed Loupe Local Network service
families from inventory ownership. All emitted `svc.<service-type>` signals are
active, permissioned environment probes rather than hardware constants.

It also does not treat individual service types as separate mitigation domains.
They should be handled as one coherent local-network environment profile so
Apple ecosystem, media, printer, file-sharing, remote-management, smart-home,
communication, and diagnostic service claims agree with each other.

## Relevance

Local Network is a high-priority permissioned fingerprint category. It can
reveal a user's home, office, smart-home setup, media devices, local servers,
printers, and technical environment without needing GPS. Because Loupe currently
emits service names, not just counts, the sensitivity is high whenever Local
Network access is granted.

Near-term Loupehole planning should document this as an active permissioned
surface and preserve the permission boundary. Future mitigation should start
with safe suppression or name/count reduction for fingerprint-only targets, and
pass through for apps whose primary function depends on local discovery.
