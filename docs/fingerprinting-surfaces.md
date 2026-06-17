# Fingerprinting Surfaces and Mitigations

This matrix starts with Loupe's current provider set and extends into adjacent iOS surfaces. Priority values:

- P0: MVP critical.
- P1: important after MVP.
- P2: useful/advanced.
- P3: research/backlog.

Every surface in this document should eventually expand into one or more option catalog entries following [spoofing-option-policy.md](spoofing-option-policy.md). A surface is not complete until every sensible mitigation method has documented original API behavior, fingerprinting mechanism, mitigation behavior, common defaults, drawbacks, coherence dependencies, uniqueness risks, and tests.

Default values should be common on real devices. For example, local-network spoofing should prefer common private networks such as `192.168.1.0/24`; if the value represents a router/gateway, `192.168.1.1/24` is common, while a device interface should usually use a non-gateway host like `192.168.1.23/24`.

## Native Passive Surfaces

| Surface | APIs and examples | Risk | Default mitigation | Strict mitigation | Priority |
| --- | --- | --- | --- | --- | --- |
| Vendor identity | `UIDevice.identifierForVendor` | Stable across apps from same vendor; can re-identify after partial uninstall patterns | Return per-app or per-vendor pseudonymous UUID derived from app seed | Rotate on demand per app | P0 |
| Device name | `UIDevice.name`, hostname-style values | Can expose user-chosen names on some entitlements/setups | Return generic cohort name like `iPhone` | Generic | P1 |
| Hardware model | `sysctlbyname("hw.machine")`, `hw.model`, `uname` | Exact model and SoC class | Return coherent cohort hardware identifiers | Same | P0 |
| CPU identifiers | `hw.cputype`, `hw.cpusubtype`, `ProcessInfo.processorCount` | Model classifier | Return cohort CPU fields | Same | P0 |
| OS version | `UIDevice.systemVersion`, `ProcessInfo.operatingSystemVersionString`, `kern.version` | Narrows device population | Report real major/minor or cohort-compatible patch bucket | Cohort OS string | P0 |
| Boot time | `kern.boottime` | Stable until reboot; strong session link | Round to broad bucket or synthetic per-app stable boot window coherent with volume initialization time | Synthetic cohort boot time | P0 |
| Lockdown mode | `UserDefaults` key patterns | Rare boolean, high entropy when enabled | Consider pass-through in compatibility; normalize to common off in standard with warning | Normalize | P2 |
| Physical memory | `ProcessInfo.physicalMemory` | Device model classifier | Cohort memory value | Same | P0 |
| Battery | `UIDevice.batteryLevel`, `batteryState`, low power, thermal | Time-domain correlation | Bucket level to 10 or 20 percent, slow update cadence, common state mapping | Fixed or coarse | P0 |
| Storage | `URLResourceValues` capacity/free/creation/UUID/name | User-specific free space and setup date | Bucket capacities, hide or normalize volume creation date, common UUID/name; volume initialization or creation time must predate last boot time | Common values | P0 |
| Display | `UIScreen`, `UITraitCollection`, safe area, brightness, FPS | Exact model, settings, usage | Cohort screen metrics; bucket brightness; stable common Dynamic Type | Same, more generic | P0 |
| Locale | `Locale.current`, `preferredLanguages`, `TimeZone`, `Calendar`, keyboard languages | High entropy combination | Shared locale profile; optional pass-through timezone region; limit language list | Cohort locale | P0 |
| Accessibility | `UIAccessibility` flags, style/contrast | Rare settings identify users | Return common defaults except features needed for app usability; avoid breaking accessibility by default | Generic unless user opts in | P1 |
| Pasteboard shape | `UIPasteboard.changeCount`, `hasStrings`, `hasURLs`, item count | Silent cross-app state leak | Return neutral shape unless app is foreground paste action; bucket change count | Empty/neutral | P0 |
| Network interfaces | `getifaddrs`, `gethostname`, `NWPathMonitor`, proxy settings | Local IPs, VPN/proxy flags, interface inventory | Hide local IPs or return loopback/cohort private IP; preserve connectivity status | Generic network | P0 |
| VPN/proxy indicators | `CFNetworkCopySystemProxySettings`, scoped interfaces | Reveals privacy tools | Normalize scoped interface names; avoid false VPN flag | Generic | P1 |
| Fonts | `CTFontManagerCopyAvailableFontFamilyNames`, UIKit font lists | Custom fonts identify user | Return system baseline list for cohort OS | Baseline only | P0 |
| Voices | `AVSpeechSynthesisVoice.speechVoices` | Downloaded voices are rare | Return cohort baseline voices; hide enhanced/premium downloads | Baseline only | P0 |
| App metadata | `Bundle.main.infoDictionary`, Documents creation date, SDK stamp | Install date and build metadata can track | Normalize app install date bucket; leave actual app version | Synthetic install date | P1 |
| Apple account | `FileManager.ubiquityIdentityToken`, `Storefront.current` | Account/storefront country and iCloud token state | Return absent or per-app pseudonymous token; storefront from locale cohort or pass-through region | Absent/cohort | P1 |
| Audio route | `AVAudioSession.currentRoute`, sample rate, latency, other audio, volume | Accessory names and user context | Hide accessory names; generic route type; bucket volume; preserve sample rate if app needs audio | Generic built-in route | P1 |
| Metal/GPU | `MTLCreateSystemDefaultDevice`, `MTLDevice.name`, families, working set, raytracing | Strong SoC classifier | Coherent cohort GPU values | Same | P0 |
| Telephony | `CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology`, SIM count | SIM count and radio tech | Bucket radio tech, generic service count unless app needs cellular behavior | Generic/no SIM | P1 |
| Passive motion | `CMMotionManager` accelerometer, gyro, magnetometer, device motion, heading | Sensor calibration, physical environment, movement | Add low-noise cohort-preserving quantization; rate limit; avoid impossible physics | Zero/low-detail stream | P1 |

## Advanced Loupe Surfaces

| Surface | APIs and examples | Risk | Default mitigation | Strict mitigation | Priority |
| --- | --- | --- | --- | --- | --- |
| Installed app probing | `UIApplication.canOpenURL`, URL schemes | App inventory is highly identifying | Return cohort-common installed set for background/probe calls; allow user-initiated opens | Return false except system schemes | P0 |
| Keychain reinstall log | `SecItemAdd`, `SecItemCopyMatching`, app service/account records | Tracks reinstall across app deletion | Namespace/partition suspicious app-created IDs; optionally clear per-app tracking items on first protected launch | Block selected persistent IDs | P0 |
| WebView fingerprint | `WKWebView`, JS `navigator`, `screen`, canvas, WebGL | Browser-style cross-site and in-app tracking | Inject cohort JS shims and native WebKit hooks | Strong JS normalization and entropy reduction | P0 |

## Permissioned Surfaces

| Surface | APIs and examples | Risk | Compatibility mitigation | Strict mitigation | Priority |
| --- | --- | --- | --- | --- | --- |
| Motion/Fitness | `CMMotionActivityManager`, `CMPedometer`, `CMAltimeter` | Activity, gait, steps, altitude | Pass-through after permission, or bucket steps/altitude | Empty or coarse | P1 |
| Location | `CLLocationManager`, `CLLocation`, heading, floor | Precise location and altitude | Use iOS reduced accuracy where possible; quantize coordinates and altitude | City/region only or denied | P1 |
| Camera inventory | `AVCaptureDevice.DiscoverySession`, `uniqueID`, formats/FOV | Exact model/camera stack | If capture needed, hide unique IDs and normalize enumeration metadata carefully | Common virtual camera set | P1 |
| Bluetooth | `CBCentralManager`, BLE scan names/RSSI | Nearby devices and owner names | Do not scan unless app purpose requires; hide names; bucket RSSI | Empty scan | P1 |
| Local network | `NWBrowser` Bonjour service discovery | Home/office device inventory | Return counts only or empty names; allow app-required service types | Empty/denied | P1 |
| Contacts | `CNContactStore`, counts, labels, containers | Social graph | Prefer native limited contacts; bucket counts; hide labels | Empty/limited | P2 |
| Photos | `PHAsset`, geotags, album counts | Places, routines, library size | Prefer limited library; bucket counts; strip geotag summaries | Empty/limited | P2 |
| Calendar | `EKEventStore`, sources, types, event count | Work/services/routine | Bucket counts; hide provider names | Empty | P2 |
| Reminders | `EKEventStore` reminder lists/titles/counts | Personal list names | Hide titles, bucket counts | Empty | P2 |
| Music | `MPMediaQuery`, `SKCloudServiceController` | Taste profile and subscription state | Bucket counts; hide artists/genres | Empty | P2 |

## WebKit and JavaScript Surfaces

| Surface | APIs | Mitigation | Priority |
| --- | --- | --- | --- |
| Navigator identity | `userAgent`, `platform`, `vendor`, `appVersion` | Cohort UA and platform matching native profile | P0 |
| Language/locale | `navigator.language(s)`, `Intl`, `Date` timezone | Same locale profile as native layer | P0 |
| Screen | `screen.width/height/colorDepth`, `devicePixelRatio`, CSS media queries | Cohort screen values matching native display | P0 |
| Hardware | `hardwareConcurrency`, `deviceMemory` | Cohort CPU/RAM buckets | P0 |
| Canvas 2D | `toDataURL`, `getImageData` | Deterministic cohort perturbation or canonical rendering hash | P0 |
| WebGL | Renderer/vendor extensions, parameters, precision | Cohort renderer and parameter set; optionally disable debug extension | P0 |
| Audio fingerprint | `AudioContext`, oscillator/analyser output | Deterministic cohort perturbation | P1 |
| Fonts | CSS font probing | Baseline font set, generic metrics | P1 |
| Storage quota | `navigator.storage.estimate`, IndexedDB/localStorage behavior | Bucket quota/usage | P1 |
| Timing | `performance.now`, animation frame cadence, event loop jitter | Reduce precision and avoid unique jitter patterns | P1 |
| Media devices | `enumerateDevices`, constraints | Empty labels until permission; generic devices | P1 |
| WebRTC/network | ICE candidates and local IP exposure | Disable local IP candidates where applicable | P2 |
| Touch/pointer | `maxTouchPoints`, pointer media queries | Cohort device values | P1 |

## Additional Native Surfaces Beyond Loupe

| Surface | APIs/examples | Risk | Mitigation | Priority |
| --- | --- | --- | --- | --- |
| Advertising ID | `ASIdentifierManager.advertisingIdentifier`, tracking status | Cross-app ad identifier when allowed | Return zeroed ID unless user has allowed tracking; preserve platform semantics | P0 |
| App-generated IDs | UserDefaults, files, SQLite, Keychain | Persistent tracking IDs | Detect common SDK keys, partition or rotate per app/profile, offer reset | P1 |
| Cookies/WebKit storage | `WKWebsiteDataStore`, cookies, localStorage | Cross-session web IDs | Per-app or ephemeral stores where possible; clear on profile reset | P1 |
| APNs token | App delegate device token | Stable app install signal | Do not spoof by default; user can block network transmission only outside this tweak | P3 |
| DeviceCheck/App Attest | DeviceCheck, App Attest | Security/fraud binding | Pass-through; do not spoof | P3 |
| Biometry availability | `LAContext.canEvaluatePolicy`, `biometryType` | Face ID/Touch ID/enrollment state | Generic availability matching cohort, but pass-through for auth flows | P2 |
| Apple Pay availability | `PKPaymentAuthorizationController.canMakePayments` | Region/card setup | Pass-through by default; generic in strict mode | P2 |
| Haptics | CoreHaptics capability | Device model classifier | Cohort capability | P3 |
| Orientation/proximity | `UIDevice.orientation`, proximity monitoring | Usage context | Pass-through for UI, rate-limit or neutralize background probes | P2 |
| Thermal/performance benchmarks | CPU/GPU timing, memory pressure | Device and state classifier | Hard to solve; reduce exposed static fields, consider timing precision in WebView | P3 |
| Filesystem paths | Container UUIDs, path names, file timestamps | Install/session identifiers | Normalize timestamps; avoid exposing container UUID where hookable | P1 |
| Receipt/store metadata | App receipt, storefront, purchase environment | Account/region/app install state | Pass-through; only normalize storefront in privacy profile | P2 |
| Notifications | Authorization status/settings | Rare preference state | Normalize statuses only in strict mode; pass-through for UX | P3 |
| HealthKit | Health samples and availability | Extremely sensitive | Do not spoof broadly; rely on iOS permissions and user-denied default | P3 |
| Nearby interaction/UWB | NearbyInteraction capabilities | Device class/environment | Deny or generic unless app requires it | P3 |
| ARKit/LiDAR | ARWorldTrackingConfiguration supports flags | Exact hardware | Cohort capability; pass-through for AR apps | P2 |

## Coherence Requirements

These values must be generated together:

- `hw.machine`, `uname.machine`, model marketing name.
- CPU count, RAM, GPU name, Metal families.
- Screen bounds, safe area, scale, refresh rate, WebKit screen values.
- Camera count/types/FOV and hardware model.
- Locale, timezone, languages, keyboard languages, WebKit Intl values.
- OS version, kernel version, WebKit version, user agent.
- Audio sample rate and route capabilities.
- Telephony and device class.
- Temporal values such as volume initialization or creation time, last boot time, app install time, and profile rotation time.

Contradictions are high-risk. A tracker can flag the protection if an app sees an iPhone SE screen with ProMotion 120 Hz, an A18 Pro GPU, iPad safe area values, and a WebKit iPad platform string.

Temporal contradictions are also high-risk. A tracker can flag the protection if a volume appears to have been initialized after the last boot, an app install predates the storage volume, or a resettable identifier appears older than the profile rotation that created it.

## Value Lifetime Rules

| Value class | Lifetime | Example |
| --- | --- | --- |
| Cohort static | Same for all users in a profile | Screen metrics, GPU family |
| Per-app stable | Stable until user resets that app | IDFV replacement, synthetic install date |
| Session stable | Stable until app restart | Some timing offsets |
| Slowly varying | Changes in broad buckets | Battery, free storage, thermal |
| Pass-through | Real value for compatibility | Active camera capture data |
| Denied/empty | No data | Strict Bluetooth scan |

## Default MVP Coverage

P0 MVP:

- IDFV replacement.
- Device boot time and volume initialization or creation time, with volume time earlier than boot time.
- Device/sysctl/uname.
- ProcessInfo CPU/RAM/OS.
- Storage capacity/date.
- Display/safe area.
- Battery/thermal.
- Locale/timezone/languages.
- Pasteboard shape.
- Network interfaces/hostname/VPN heuristic.
- Fonts and voices.
- Metal/GPU.
- URL scheme probing.
- Keychain reinstall tracking.
- WKWebView navigator/screen/canvas/WebGL basics.
- Advertising ID.

Each MVP item must include:

- Compatibility, standard, and strict behavior where sensible.
- A common default or explicit pass-through default.
- A no-hardcoded-identifying-constants audit.
- A harness test.

P1 next:

- Accessibility.
- Audio route.
- Telephony.
- Passive CoreMotion.
- Apple account/storefront.
- App install date.
- Permissioned location/camera/Bluetooth/local network.
- WebKit audio/timing/storage/media devices.
